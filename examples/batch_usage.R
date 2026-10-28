source("R/utils.R")
source("R/config.R")
source("R/audio.R")
source("R/api.R")
source("R/pipeline.R")

recordings <- c(
  "interview_01.mp3",
  "interview_02.mp3",
  "interview_03.mp3"
)

results <- transcribe_batch(
  recordings,
  language = "en",
  output_dir = "transcripts",
  continue_on_error = TRUE
)

results
