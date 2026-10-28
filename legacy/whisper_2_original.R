# ============================
# 0. Setup ----
# ============================
# Install packages once if needed:
# install.packages(c("httr", "jsonlite", "fs"))

library(httr)
library(jsonlite)
library(fs)

# --- Set your API key (do this once per session, or put it in .Renviron) ----
# Option A: set directly in R (not recommended in shared scripts)
# Sys.setenv(OPENAI_API_KEY = "sk-...")

# Option B (better): add this line to ~/.Renviron and restart R:
# OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx
# Then just rely on Sys.getenv("OPENAI_API_KEY")

api_key <- Sys.getenv("OPENAI_API_KEY")
if (api_key == "") {
  stop("OPENAI_API_KEY not set. Use Sys.setenv(OPENAI_API_KEY='...') or .Renviron.")
}

# OpenAI audio transcription endpoint
OPENAI_AUDIO_URL <- "https://api.openai.com/v1/audio/transcriptions"

# ============================
# 1. Helper: split audio with ffmpeg ----
# ============================
split_audio_ffmpeg <- function(input_file,
                               output_dir = "audio_chunks",
                               chunk_minutes = 15,
                               ffmpeg_path = "ffmpeg") {
  if (!file.exists(input_file)) {
    stop("Input file not found: ", input_file)
  }
  
  dir_create(output_dir)
  
  # pattern like audio_chunks/part_001.mp3, part_002.mp3, ...
  out_pattern <- file.path(output_dir, "part_%03d.mp3")
  
  # Build ffmpeg command:
  # - segment the audio into equal-length chunks
  # - -segment_time is in seconds
  args <- c(
    "-i", shQuote(input_file),
    "-f", "segment",
    "-segment_time", as.character(chunk_minutes * 60),
    "-c", "copy",
    shQuote(out_pattern)
  )
  
  cat("Splitting audio with ffmpeg...\n")
  res <- system2(ffmpeg_path, args, stdout = TRUE, stderr = TRUE)
  # Comment this next line if the ffmpeg stdout is too noisy:
  # cat(paste(res, collapse = "\n"), "\n")
  
  # Collect generated parts
  parts <- sort(Sys.glob(file.path(output_dir, "part_*.mp3")))
  if (length(parts) == 0L) {
    stop("No chunks were created. Check ffmpeg installation and arguments.")
  }
  
  cat("Created", length(parts), "chunk(s):\n")
  print(parts)
  
  return(parts)
}

# ============================
# 2. Helper: call Whisper API for a single file ----
# ============================
whisper_transcribe_file <- function(audio_file,
                                    model = "whisper-1",
                                    language = NULL,   # e.g. "en", "zh", etc. (optional)
                                    temperature = 0) {
  if (!file.exists(audio_file)) {
    stop("Audio file not found: ", audio_file)
  }
  
  cat("Transcribing:", audio_file, "...\n")
  
  body <- list(
    file        = upload_file(audio_file),
    model       = model,
    response_format = "text",
    temperature = temperature
  )
  
  # Add language only if provided
  if (!is.null(language)) {
    body$language <- language
  }
  
  res <- POST(
    url = OPENAI_AUDIO_URL,
    add_headers(Authorization = paste("Bearer", api_key)),
    body = body,
    encode = "multipart"
  )
  
  if (http_error(res)) {
    msg <- content(res, "text", encoding = "UTF-8")
    stop("Whisper API error for file ", audio_file, ":\n", msg)
  }
  
  txt <- content(res, "text", encoding = "UTF-8")
  return(txt)
}

# ============================
# 3. High-level: split + transcribe + stitch ----
# ============================
transcribe_long_audio <- function(input_file,
                                  chunk_minutes = 15,
                                  ffmpeg_path = "ffmpeg",
                                  model = "whisper-1",
                                  language = NULL,
                                  out_markdown = NULL) {
  # 1) Split into chunks
  parts <- split_audio_ffmpeg(
    input_file   = input_file,
    output_dir   = paste0(path_ext_remove(input_file), "_chunks"),
    chunk_minutes = chunk_minutes,
    ffmpeg_path  = ffmpeg_path
  )
  
  # 2) Transcribe each chunk
  transcripts <- vector("character", length(parts))
  for (i in seq_along(parts)) {
    transcripts[i] <- whisper_transcribe_file(
      audio_file = parts[i],
      model      = model,
      language   = language
    )
  }
  
  # 3) Stitch into one markdown string with simple segment headers
  segment_blocks <- vapply(
    seq_along(transcripts),
    function(i) {
      paste0("### Segment ", i, "\n\n", transcripts[i], "\n")
    },
    FUN.VALUE = character(1)
  )
  
  full_md <- paste(segment_blocks, collapse = "\n\n")
  
  # 4) Optionally write to file
  if (is.null(out_markdown)) {
    out_markdown <- paste0(path_ext_remove(input_file), "_transcript.md")
  }
  
  writeLines(full_md, out_markdown, useBytes = TRUE)
  cat("Transcript written to:", out_markdown, "\n")
  
  invisible(list(
    chunks = parts,
    transcript = full_md,
    output_file = out_markdown
  ))
}

# ============================
# 4. Run for your specific file ----
# ============================

# Your file:
input_mp3 <- "XY Tr1_241025.mp3"

# Call the high-level function.
# - chunk_minutes = 15 --> your 40:39 recording will be split into 3 parts
# - language = NULL lets Whisper auto-detect; set e.g. "en" or "zh" if you know it
result <- transcribe_long_audio(
  input_file   = input_mp3,
  chunk_minutes = 15,
  ffmpeg_path  = "ffmpeg",   # adjust if ffmpeg is elsewhere, e.g. "C:/ffmpeg/bin/ffmpeg.exe"
  model        = "whisper-1",
  language     = NULL,
  out_markdown = "XY_Tr1_241025_transcript.md"
)

# After this, check the file:
# "XY_Tr1_241025_transcript.md" in your working directory.

# Your file:
input_mp3 <- "XY Tr2_241025.mp3"

# Call the high-level function.
# - chunk_minutes = 15 --> your 40:39 recording will be split into 3 parts
# - language = NULL lets Whisper auto-detect; set e.g. "en" or "zh" if you know it
result <- transcribe_long_audio(
  input_file   = input_mp3,
  chunk_minutes = 15,
  ffmpeg_path  = "ffmpeg",   # adjust if ffmpeg is elsewhere, e.g. "C:/ffmpeg/bin/ffmpeg.exe"
  model        = "whisper-1",
  language     = NULL,
  out_markdown = "XY_Tr2_241025_transcript.md"
)

# Your file:
input_mp3 <- "XY Tr3_241025.mp3"

# Call the high-level function.
# - chunk_minutes = 15 --> your 40:39 recording will be split into 3 parts
# - language = NULL lets Whisper auto-detect; set e.g. "en" or "zh" if you know it
result <- transcribe_long_audio(
  input_file   = input_mp3,
  chunk_minutes = 15,
  ffmpeg_path  = "ffmpeg",   # adjust if ffmpeg is elsewhere, e.g. "C:/ffmpeg/bin/ffmpeg.exe"
  model        = "whisper-1",
  language     = NULL,
  out_markdown = "XY_Tr3_241025_transcript.md"
)

#### transcribe chunks separately into txt and stitch back to md ####

# Vector of your chunk files (already created by ffmpeg)
chunks <- sort(Sys.glob("XY Tr3_241025_chunks/part_*.mp3"))
chunks
# [1] "XY Tr3_241025_chunks/part_000.mp3" ...
#     "XY Tr3_241025_chunks/part_003.mp3"

# Folder to save the per-chunk transcripts
dir.create("XY_Tr3_241025_chunk_txt", showWarnings = FALSE)

for (i in seq_along(chunks)) {
  chunk_file <- chunks[i]
  cat("\n=== Transcribing chunk", i, "of", length(chunks), "===\n")
  cat("File:", chunk_file, "\n")
  
  # If a chunk keeps failing with 502/504, you can re-run this loop for that index only
  txt <- whisper_transcribe_file(
    audio_file = chunk_file,
    model      = "whisper-1",
    language   = NULL  # or "en" / "zh" if you want to lock language
  )
  
  out_txt <- sprintf("XY_Tr3_241025_chunk_txt/chunk_%02d.txt", i)
  writeLines(txt, out_txt, useBytes = TRUE)
  cat("Saved:", out_txt, "\n")
}

# Read chunk transcripts back
txt_files <- sort(Sys.glob("XY_Tr3_241025_chunk_txt/chunk_*.txt"))

segment_texts <- lapply(txt_files, function(f) {
  paste(readLines(f, warn = FALSE), collapse = "\n")
})

# Wrap each in a small markdown header
segment_blocks <- vapply(
  seq_along(segment_texts),
  function(i) {
    paste0(
      "### Segment ", i, " (", basename(txt_files[i]), ")\n\n",
      segment_texts[[i]], "\n"
    )
  },
  FUN.VALUE = character(1)
)

full_md <- paste(segment_blocks, collapse = "\n\n")

# Write the full transcript
out_md <- "XY_Tr3_241025_transcript_manual.md"
writeLines(full_md, out_md, useBytes = TRUE)

cat("Full transcript written to:", out_md, "\n")
