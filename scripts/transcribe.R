#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (!length(args) || args[[1]] %in% c("-h", "--help")) {
  cat(
"Usage:
  Rscript scripts/transcribe.R <audio-file> [options]

Options:
  --language=<code>         Language hint, e.g. en or zh
  --model=<model>           Default: gpt-transcribe
  --chunk-minutes=<number>  Default: 15
  --output-dir=<path>       Default: transcripts
  --ffmpeg=<path>           Default: ffmpeg
  --prompt=<text>           Context/vocabulary hint
  --overwrite               Recreate chunks and transcripts
  --help                    Show this message

Example:
  Rscript scripts/transcribe.R meeting.mp3 --language=en
",
    sep = ""
  )
  quit(status = 0)
}

cmd <- commandArgs()
script_arg <- cmd[grep("^--file=", cmd)]
repo_root <- if (length(script_arg)) {
  normalizePath(
    file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
    winslash = "/",
    mustWork = FALSE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "utils.R"))
source(file.path(repo_root, "R", "config.R"))
source(file.path(repo_root, "R", "audio.R"))
source(file.path(repo_root, "R", "api.R"))
source(file.path(repo_root, "R", "pipeline.R"))

input_file <- args[[1]]
options <- args[-1]

get_opt <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- options[startsWith(options, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

overwrite <- "--overwrite" %in% options
chunk_minutes <- as.numeric(get_opt("chunk-minutes", "15"))

if (is.na(chunk_minutes) || chunk_minutes <= 0) {
  stop("--chunk-minutes must be a positive number.", call. = FALSE)
}

result <- transcribe_audio(
  input_file = input_file,
  language = get_opt("language"),
  model = get_opt("model", "gpt-transcribe"),
  chunk_minutes = chunk_minutes,
  output_dir = get_opt("output-dir", "transcripts"),
  ffmpeg_path = get_opt("ffmpeg", "ffmpeg"),
  prompt = get_opt("prompt"),
  overwrite = overwrite
)

cat("\nDone:\n", result$output_file, "\n", sep = "")
