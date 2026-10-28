# Audio preparation --------------------------------------------------------

split_audio_ffmpeg <- function(input_file,
                               output_dir,
                               chunk_minutes = 15,
                               ffmpeg_path = "ffmpeg",
                               bitrate = "64k",
                               sample_rate = 16000,
                               channels = 1,
                               overwrite = FALSE) {
  check_dependencies()

  if (!file.exists(input_file)) {
    stop("Input file not found: ", input_file, call. = FALSE)
  }

  if (!is.numeric(chunk_minutes) || length(chunk_minutes) != 1L || chunk_minutes <= 0) {
    stop("chunk_minutes must be a positive number.", call. = FALSE)
  }

  ffmpeg <- find_ffmpeg(ffmpeg_path)
  fs::dir_create(output_dir)

  existing <- sort(Sys.glob(fs::path(output_dir, "part_*.mp3")))
  if (length(existing) && !overwrite) {
    message("Reusing ", length(existing), " existing audio chunk(s).")
    return(existing)
  }

  if (length(existing)) file.remove(existing)

  out_pattern <- fs::path(output_dir, "part_%03d.mp3")

  args <- c(
    "-hide_banner",
    "-loglevel", "error",
    "-y",
    "-i", input_file,
    "-vn",
    "-ac", as.character(channels),
    "-ar", as.character(sample_rate),
    "-b:a", bitrate,
    "-f", "segment",
    "-segment_time", as.character(chunk_minutes * 60),
    "-reset_timestamps", "1",
    out_pattern
  )

  message("Splitting audio into ~", chunk_minutes, "-minute chunks...")
  output <- system2(ffmpeg, args = args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L

  parts <- sort(Sys.glob(fs::path(output_dir, "part_*.mp3")))

  if (status != 0L || length(parts) == 0L) {
    stop(
      "ffmpeg did not create audio chunks.\n",
      paste(output, collapse = "\n"),
      call. = FALSE
    )
  }

  message("Created ", length(parts), " chunk(s).")
  parts
}
