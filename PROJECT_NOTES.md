# Refactor notes

The original script had a sensible core design: environment-based API-key loading, ffmpeg splitting, a single-file transcription helper, and a high-level split/transcribe/stitch workflow.

The main repository refactor makes those ideas reusable and operationally safer.

## Improvements

- reusable code moved to `R/`
- hard-coded source recordings removed from library code
- chunk transcripts saved immediately
- interrupted jobs resume automatically
- transient API failures retried
- generated outputs grouped per recording
- batch mode added
- command-line entry point added
- GitHub Actions included
- original source retained under `legacy/`

## Suggested future extensions

- speaker diarization
- timestamps and SRT/VTT output
- richer JSON output
- progress bars
- parallel transcription with conservative concurrency
- optional meeting-summary and action-item post-processing
