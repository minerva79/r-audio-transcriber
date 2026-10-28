# Utility helpers ----------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

sanitize_stem <- function(path) {
  stem <- fs::path_ext_remove(fs::path_file(path))
  stem <- gsub("[^A-Za-z0-9._-]+", "_", stem)
  stem <- gsub("^_+|_+$", "", stem)
  if (!nzchar(stem)) stem <- "audio"
  stem
}

write_utf8 <- function(text, path) {
  fs::dir_create(fs::path_dir(path))
  writeLines(enc2utf8(text), path, useBytes = TRUE)
  invisible(path)
}
