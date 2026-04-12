library(testthat)
library(Rparadox)

test_that("empty string path is rejected", {
  expect_warning(
    result <- read_paradox(""),
    "File not found"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("NA path is rejected", {
  expect_error(
    read_paradox(NA_character_),
    "Argument 'path' must be a single character string."
  )
})

test_that("NULL path is rejected", {
  expect_error(
    read_paradox(NULL),
    "Argument 'path' must be a single character string."
  )
})

test_that("vector path is rejected", {
  expect_error(
    read_paradox(c("a.db", "b.db")),
    "Argument 'path' must be a single character string."
  )
})

test_that("path to a directory is handled gracefully", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  expect_warning(
    result <- read_paradox(tmp_dir),
    "pxlib failed to open file"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("pxlib_open_file warns on empty string path", {
  expect_warning(
    result <- pxlib_open_file(""),
    "File not found"
  )
  expect_null(result)
})

test_that("pxlib_open_file rejects NA path", {
  expect_error(
    pxlib_open_file(NA_character_),
    "path.*single character"
  )
})

test_that("pxlib_open_file rejects numeric path", {
  expect_error(
    pxlib_open_file(123),
    "path.*single character"
  )
})

test_that("pxlib_open_file returns NULL with warning for non-existent file", {
  expect_warning(
    result <- pxlib_open_file("/tmp/nonexistent_12345.db"),
    "File not found"
  )
  expect_null(result)
})
