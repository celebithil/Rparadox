library(testthat)
library(Rparadox)

test_that("pxlib_close_file handles errors", {
  # Invalid type. The error message must match EXACTLY.
  # Updating the expected message
  expect_error(
    pxlib_close_file("not a pointer"), 
    "Invalid argument: 'pxdoc' must be an external pointer of class 'pxdoc_t'."
  )
})

test_that("pxlib_close_file handles double close gracefully", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  px_doc <- pxlib_open_file(db_path)

  # First close should succeed
  expect_invisible(pxlib_close_file(px_doc))

  # Second close on the same pointer should error
  expect_error(
    pxlib_close_file(px_doc),
    "closed or invalid"
  )
})

test_that("pxlib_close_file rejects NULL input", {
  expect_error(
    pxlib_close_file(NULL),
    "Invalid argument"
  )
})

test_that("pxlib_close_file is invisible on success", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  px_doc <- pxlib_open_file(db_path)
  expect_invisible(pxlib_close_file(px_doc))
})