# OpenAI transcription API -------------------------------------------------

is_legacy_transcription_model <- function(model) {
  model %in% c(
    "whisper-1",
    "gpt-4o-transcribe",
    "gpt-4o-mini-transcribe",
    "gpt-4o-transcribe-diarize"
  )
}

build_transcription_body <- function(audio_file,
                                     model = "gpt-transcribe",
                                     language = NULL,
                                     prompt = NULL) {
  body <- list(
    file = httr::upload_file(audio_file),
    model = model,
    response_format = "json"
  )

  if (!is.null(prompt) && nzchar(prompt)) {
    body$prompt <- prompt
  }

  if (!is.null(language) && nzchar(language)) {
    if (identical(model, "gpt-transcribe")) {
      body[["languages[]"]] <- language
    } else {
      body$language <- language
    }
  }

  body
}

parse_transcription_response <- function(response, audio_file) {
  text <- httr::content(response, "text", encoding = "UTF-8")

  parsed <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = TRUE),
    error = function(e) NULL
  )

  if (is.list(parsed) && !is.null(parsed$text)) {
    return(as.character(parsed$text))
  }

  if (nzchar(text) && !grepl("^\\s*\\{", text)) {
    return(text)
  }

  stop(
    "The API returned an unexpected response for ",
    basename(audio_file),
    ". Raw response:\n",
    text,
    call. = FALSE
  )
}

transcribe_file <- function(audio_file,
                            model = "gpt-transcribe",
                            language = NULL,
                            prompt = NULL,
                            api_key = NULL,
                            max_retries = 5,
                            retry_base_seconds = 2,
                            timeout_seconds = 600) {
  check_dependencies()

  if (!file.exists(audio_file)) {
    stop("Audio file not found: ", audio_file, call. = FALSE)
  }

  api_key <- get_openai_api_key(api_key)
  retryable_codes <- c(408L, 409L, 429L, 500L, 502L, 503L, 504L)

  for (attempt in seq_len(max_retries + 1L)) {
    response <- tryCatch(
      httr::POST(
        url = OPENAI_AUDIO_URL,
        httr::add_headers(Authorization = paste("Bearer", api_key)),
        body = build_transcription_body(
          audio_file = audio_file,
          model = model,
          language = language,
          prompt = prompt
        ),
        encode = "multipart",
        httr::timeout(timeout_seconds)
      ),
      error = identity
    )

    if (inherits(response, "error")) {
      if (attempt > max_retries) {
        stop("Network error after retries: ", conditionMessage(response), call. = FALSE)
      }
      wait <- retry_base_seconds * 2^(attempt - 1L)
      message("Network error. Retrying in ", wait, " second(s)...")
      Sys.sleep(wait)
      next
    }

    status <- httr::status_code(response)

    if (status >= 200L && status < 300L) {
      return(parse_transcription_response(response, audio_file))
    }

    err <- httr::content(response, "text", encoding = "UTF-8")

    if (!(status %in% retryable_codes) || attempt > max_retries) {
      stop(
        "Transcription API error (HTTP ", status, ") for ",
        basename(audio_file), ":\n", err,
        call. = FALSE
      )
    }

    wait <- retry_base_seconds * 2^(attempt - 1L)
    message("API returned HTTP ", status, ". Retrying in ", wait, " second(s)...")
    Sys.sleep(wait)
  }

  stop("Unexpected retry-loop termination.", call. = FALSE)
}
