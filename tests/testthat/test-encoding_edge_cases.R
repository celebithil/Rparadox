library(testthat)
library(Rparadox)

test_that("invalid encoding name errors gracefully", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  skip_if_not(file.exists(db_path))

  expect_error(
    read_paradox(db_path, encoding = "nonexistent_encoding"),
    "Possibly corrupted file"
  )
})

test_that("empty encoding string is treated as NULL", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  skip_if_not(file.exists(db_path))

  result <- read_paradox(db_path, encoding = "")
  expect_s3_class(result, "tbl_df")
  expect_identical(result, readRDS(ref_path))
})

test_that("encoding = NA_character_ is rejected", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  skip_if_not(file.exists(db_path))

  expect_error(
    read_paradox(db_path, encoding = NA_character_),
    "encoding.*NULL.*single character"
  )
})

test_that("pxlib_open_file with invalid encoding stores it as attribute", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  skip_if_not(file.exists(db_path))

  pxdoc <- pxlib_open_file(db_path, encoding = "nonexistent_encoding")
  expect_false(is.null(pxdoc))
  expect_equal(attr(pxdoc, "px_encoding"), "nonexistent_encoding")
  pxlib_close_file(pxdoc)
})

test_that("pxlib_open_file with invalid codepage in header reading", {
  db_path <- system.file("extdata", "of.db", package = "Rparadox")
  ref_path <- test_path("ref_of.rds")
  skip_if_not(file.exists(db_path))

  result <- read_paradox(db_path, encoding = "cp866")
  expect_s3_class(result, "tbl_df")
  expect_identical(result, readRDS(ref_path))

  result_auto <- suppressWarnings(read_paradox(db_path))
  expect_s3_class(result_auto, "tbl_df")
})
