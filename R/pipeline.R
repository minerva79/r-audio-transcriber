# End-to-end transcription pipeline ---------------------------------------

transcribe_audio <- function(input_file,
                             output_dir = "transcripts",
                             chunk_minutes = 15,
                             ffmpeg_path = "ffmpeg",
                             model = "gpt-transcribe",
                             language = NULL,
                             prompt = NULL,
                             api_key = NULL,
                             overwrite = FALSE,
                             max_retries = 5) {
  check_dependencies()

  if (!file.exists(input_file)) {
    stop("Input file not found: ", input_file, call. = FALSE)
  }

  stem <- sanitize_stem(input_file)
  job_dir <- fs::path(output_dir, stem)
  chunk_dir <- fs::path(job_dir, "chunks")
  text_dir <- fs::path(job_dir, "chunk_transcripts")
  final_md <- fs::path(job_dir, paste0(stem, "_transcript.md"))
  manifest_file <- fs::path(job_dir, "manifest.csv")

  fs::dir_create(c(job_dir, chunk_dir, text_dir))

  chunks <- split_audio_ffmpeg(
    input_file = input_file,
    output_dir = chunk_dir,
    chunk_minutes = chunk_minutes,
    ffmpeg_path = ffmpeg_path,
    overwrite = overwrite
  )

  rows <- vector("list", length(chunks))
  transcripts <- vector("character", length(chunks))

  for (i in seq_along(chunks)) {
    chunk <- chunks[[i]]
    txt_file <- fs::path(text_dir, sprintf("chunk_%03d.txt", i))

    if (file.exists(txt_file) && !overwrite) {
      message("[", i, "/", length(chunks), "] Reusing ", basename(txt_file))
      txt <- paste(
        readLines(txt_file, warn = FALSE, encoding = "UTF-8"),
        collapse = "\n"
      )
      status <- "reused"
    } else {
      message("[", i, "/", length(chunks), "] Transcribing ", basename(chunk))

      txt <- transcribe_file(
        audio_file = chunk,
        model = model,
        language = language,
        prompt = prompt,
        api_key = api_key,
        max_retries = max_retries
      )

      write_utf8(txt, txt_file)
      status <- "transcribed"
      message("Saved ", basename(txt_file))
    }

    transcripts[[i]] <- txt

    info <- file.info(chunk)
    rows[[i]] <- data.frame(
      chunk_index = i,
      audio_chunk = normalizePath(chunk, winslash = "/", mustWork = FALSE),
      transcript_file = normalizePath(txt_file, winslash = "/", mustWork = FALSE),
      bytes = info$size,
      status = status,
      stringsAsFactors = FALSE
    )

    manifest <- do.call(rbind, rows[seq_len(i)])
    utils::write.csv(
      manifest,
      manifest_file,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }

  blocks <- vapply(
    seq_along(transcripts),
    function(i) {
      paste0(
        "### Segment ", i, "\n\n",
        trimws(transcripts[[i]]),
        "\n"
      )
    },
    FUN.VALUE = character(1)
  )

  header <- paste0(
    "# Transcript: ", fs::path_file(input_file), "\n\n",
    "- Model: `", model, "`\n",
    "- Chunks: ", length(chunks), "\n",
    "- Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"), "\n\n"
  )

  full_md <- paste0(header, paste(blocks, collapse = "\n"))
  write_utf8(full_md, final_md)

  message("Transcript written to: ", final_md)

  invisible(list(
    input_file = input_file,
    chunks = chunks,
    manifest = manifest_file,
    transcript = full_md,
    output_file = final_md
  ))
}

transcribe_batch <- function(input_files, ..., continue_on_error = TRUE) {
  results <- vector("list", length(input_files))
  names(results) <- basename(input_files)

  for (i in seq_along(input_files)) {
    file <- input_files[[i]]
    message("\n=== ", i, "/", length(input_files), ": ", basename(file), " ===")

    results[[i]] <- tryCatch(
      transcribe_audio(file, ...),
      error = function(e) {
        if (!continue_on_error) stop(e)
        structure(
          list(input_file = file, error = conditionMessage(e)),
          class = "transcription_error"
        )
      }
    )
  }

  results
}
