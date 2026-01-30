library(testthat)
library(Rparadox)

# Path to the test database. Skip tests if it doesn't exist.
db_path <- system.file("extdata", "country.db", package = "Rparadox")

test_that("pxlib_open_file and pxlib_close_file work correctly", {
  # 1. Opening a correct file
  px_doc <- pxlib_open_file(db_path)
  
  # 2. Check that we received a valid object
  expect_s3_class(px_doc, "pxdoc_t")
  expect_true(inherits(px_doc, "externalptr"))
  
  # 3. Closing the file
  expect_invisible(pxlib_close_file(px_doc))
  
  # 4. Check that the pointer is cleared after closing
  # Calling the C-function again on a cleared pointer should cause an error
  expect_error(.Call("R_pxlib_num_fields", px_doc))
})

test_that("pxlib_open_file handles errors", {
  # A non-existent file should return NULL and issue a warning
  expect_warning(
    expect_null(pxlib_open_file("non_existent_123.db")),
    "File not found"
  )
  
  # Invalid argument type. The error message must match EXACTLY.
  expect_error(
    pxlib_open_file(123), 
    "Argument 'path' must be a single character string."
  )
  
  # Invalid encoding type. The error message must match EXACTLY.
  expect_error(
    pxlib_open_file(db_path, encoding = 866), 
    "Argument 'encoding' must be NULL or a single character string."
  )
})