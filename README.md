# r-audio-transcriber

A lightweight R toolkit for transcribing long recordings with the OpenAI Audio Transcriptions API.

It is designed for interviews, research recordings, lectures, and meetings where recordings may be long, API requests may occasionally fail, and completed work should be resumable rather than repeated from scratch.

## Features

- validates `OPENAI_API_KEY`
- checks for `ffmpeg`
- normalises and splits long recordings into manageable chunks
- transcribes each chunk via the OpenAI transcription endpoint
- retries transient HTTP failures with exponential backoff
- saves each chunk transcript immediately
- resumes interrupted jobs automatically
- stitches chunk transcripts into a final Markdown transcript
- writes a CSV manifest for auditability
- supports batch transcription
- separates reusable functions from project-specific execution

## Repository structure

```text
r-audio-transcriber/
├── R/
│   ├── api.R
│   ├── audio.R
│   ├── config.R
│   ├── pipeline.R
│   └── utils.R
├── scripts/
│   └── transcribe.R
├── examples/
│   ├── basic_usage.R
│   └── batch_usage.R
├── tests/
│   ├── testthat.R
│   └── testthat/
├── legacy/
│   └── whisper_2_original.R
├── .github/workflows/
│   └── R-CMD-check.yaml
├── .Renviron.example
├── .gitignore
├── DESCRIPTION
├── LICENSE
├── NAMESPACE
└── README.md
```

## Requirements

- R >= 4.2
- `ffmpeg`
- OpenAI API key

Install the required R packages:

```r
install.packages(c("httr", "jsonlite", "fs", "testthat"))
```

Check that `ffmpeg` is available:

```bash
ffmpeg -version
```

On Windows, you may instead pass the full executable path, for example:

```text
C:/ffmpeg/bin/ffmpeg.exe
```

## API key

Do not place your API key directly inside a shared script.

Copy the example environment entry into your user `.Renviron`:

```text
OPENAI_API_KEY=your-key-here
```

Restart R afterwards.

## Quick start

From the repository root:

```r
source("R/utils.R")
source("R/config.R")
source("R/audio.R")
source("R/api.R")
source("R/pipeline.R")

result <- transcribe_audio(
  input_file = "meeting.mp3",
  language = "en"
)

result$output_file
```

## Command-line usage

```bash
Rscript scripts/transcribe.R "meeting.mp3"
```

With options:

```bash
Rscript scripts/transcribe.R "meeting.mp3" \
  --language=en \
  --chunk-minutes=15 \
  --output-dir=transcripts
```

Windows example:

```powershell
Rscript scripts/transcribe.R "meeting.mp3" --ffmpeg="C:/ffmpeg/bin/ffmpeg.exe"
```

## Batch transcription

```r
files <- c(
  "interview_01.mp3",
  "interview_02.mp3",
  "interview_03.mp3"
)

results <- transcribe_batch(
  files,
  language = "en",
  output_dir = "transcripts"
)
```

## Resume behaviour

Each recording gets its own working directory. Chunk audio and per-chunk transcripts are saved as the job progresses.

If transcription stops midway, rerun the same command. Existing chunk transcripts are reused unless `overwrite = TRUE`.

Example output:

```text
transcripts/
└── meeting/
    ├── chunks/
    │   ├── part_000.mp3
    │   └── part_001.mp3
    ├── chunk_transcripts/
    │   ├── chunk_001.txt
    │   └── chunk_002.txt
    ├── manifest.csv
    └── meeting_transcript.md
```

## Prompting for technical vocabulary

For meetings containing names, acronyms, organisations, or technical terms, pass a prompt:

```r
result <- transcribe_audio(
  "meeting.mp3",
  language = "en",
  prompt = paste(
    "Healthcare research meeting in Singapore.",
    "Terms may include EM-RADAR, HSRC, SingHealth, CGH and SKH."
  )
)
```

## Audio preparation

The original exploratory script used stream copying when splitting audio. This repository instead re-encodes chunks to mono 16 kHz MP3 at a controlled bitrate. That makes chunk sizes much more predictable for speech transcription.

## Model selection

The default is:

```r
model = "gpt-transcribe"
```

A legacy model can still be supplied explicitly:

```r
model = "whisper-1"
```

## Security and data handling

- never commit `.Renviron`
- never commit API keys
- treat transcripts as potentially sensitive data
- generated transcript folders are ignored by Git by default

## Running tests

```r
install.packages("testthat")
testthat::test_dir("tests/testthat")
```

## Origin

This project was refactored from an exploratory single-file R transcription workflow into a reusable, resumable repository. The original script is retained in `legacy/` for reference.

## License

MIT.
