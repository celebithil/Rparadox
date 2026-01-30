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