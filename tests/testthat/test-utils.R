source("R/utils.R")

test_that("sanitize_stem makes safe file stems", {
  expect_equal(sanitize_stem("My Recording 01.mp3"), "My_Recording_01")
  expect_equal(sanitize_stem("a/b/test.wav"), "test")
})
