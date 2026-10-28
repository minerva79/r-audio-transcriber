# Configuration ------------------------------------------------------------

OPENAI_AUDIO_URL <- "https://api.openai.com/v1/audio/transcriptions"

get_openai_api_key <- function(api_key = Sys.getenv("OPENAI_API_KEY")) {
  if (!nzchar(api_key)) {
    stop(
      "OPENAI_API_KEY is not set. Add it to ~/.Renviron or pass api_key explicitly.",
      call. = FALSE
    )
  }
  api_key
}

find_ffmpeg <- function(ffmpeg_path = "ffmpeg") {
  if (grepl("[/\\\\]", ffmpeg_path)) {
    if (!file.exists(ffmpeg_path)) {
      stop("ffmpeg not found at: ", ffmpeg_path, call. = FALSE)
    }
    return(normalizePath(ffmpeg_path, winslash = "/", mustWork = TRUE))
  }

  located <- Sys.which(ffmpeg_path)
  if (!nzchar(located)) {
    stop(
      "ffmpeg is not available on PATH. Install ffmpeg or pass ffmpeg_path explicitly.",
      call. = FALSE
    )
  }

  unname(located)
}

check_dependencies <- function() {
  required <- c("httr", "jsonlite", "fs")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing)) {
    stop(
      "Missing R package(s): ",
      paste(missing, collapse = ", "),
      ". Install with install.packages().",
      call. = FALSE
    )
  }

  invisible(TRUE)
}
