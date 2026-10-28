source("R/api.R")

test_that("legacy model detection is explicit", {
  expect_true(is_legacy_transcription_model("whisper-1"))
  expect_false(is_legacy_transcription_model("gpt-transcribe"))
})
