source("R/utils.R")
source("R/config.R")
source("R/audio.R")
source("R/api.R")
source("R/pipeline.R")

result <- transcribe_audio(
  input_file = "meeting.mp3",
  output_dir = "transcripts",
  chunk_minutes = 15,
  model = "gpt-transcribe",
  language = "en",
  prompt = "Research meeting. Preserve technical terms and acronyms."
)

cat(result$output_file, "\n")
