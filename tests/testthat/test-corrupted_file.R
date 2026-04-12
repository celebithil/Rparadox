library(testthat)
library(Rparadox)

test_that("read_paradox warns and returns empty tibble on non-Paradox file (plain text)", {
  tmp <- tempfile(fileext = ".db")
  writeLines("this is not a paradox file", tmp)
  on.exit(unlink(tmp))
  expect_warning(
    result <- read_paradox(tmp),
    "pxlib failed to open file"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("read_paradox warns and returns empty tibble on empty file", {
  tmp <- tempfile(fileext = ".db")
  file.create(tmp)
  on.exit(unlink(tmp))
  expect_warning(
    result <- read_paradox(tmp),
    "pxlib failed to open file"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("read_paradox warns and returns empty tibble on binary junk file", {
  tmp <- tempfile(fileext = ".db")
  writeBin(as.raw(c(0xff, 0xfe, 0x00, 0x01, 0x02)), tmp)
  on.exit(unlink(tmp))
  expect_warning(
    result <- read_paradox(tmp),
    "pxlib failed to open file"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("pxlib_open_file returns NULL with warning on non-Paradox file", {
  tmp <- tempfile(fileext = ".db")
  writeLines("garbage", tmp)
  on.exit(unlink(tmp))
  expect_warning(
    result <- pxlib_open_file(tmp),
    "pxlib failed to open file"
  )
  expect_null(result)
})

test_that("read_paradox handles non-existent file in invalid directory", {
  expect_warning(
    result <- read_paradox("/nonexistent/path/file.db"),
    "File not found"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})
