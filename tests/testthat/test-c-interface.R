library(testthat)
library(Rparadox)

db_path <- system.file("extdata", "country.db", package = "Rparadox")

test_that("C interface (pxlib_open_file_c) validates inputs", {
  # Filename must be character
  expect_error(.Call("R_pxlib_open_file", 123, NULL), "Filename must be a single")
  expect_error(.Call("R_pxlib_open_file", c("a", "b"), NULL), "Filename must be a single")
  expect_error(.Call("R_pxlib_open_file", NA_character_, NULL), "Filename must be a single")

  # Password must be NULL or character
  expect_error(.Call("R_pxlib_open_file", db_path, 123), "Password must be NULL or a single")
  expect_error(.Call("R_pxlib_open_file", db_path, c("a", "b")), "Password must be NULL or a single")
  expect_error(.Call("R_pxlib_open_file", db_path, NA_character_), "Password must be NULL or a single")
})

test_that("C interface (pxlib_set_blob_file_c) validates inputs", {
  pxdoc <- pxlib_open_file(db_path)
  on.exit(pxlib_close_file(pxdoc))

  expect_error(.Call("R_pxlib_set_blob_file", pxdoc, 123), "BLOB filename must be a single")
  expect_error(.Call("R_pxlib_set_blob_file", pxdoc, NA_character_), "BLOB filename must be a single")
})

test_that("C interface (check_pxdoc_ptr) works", {
  # Should fail with non-externalptr
  expect_error(.Call("R_pxlib_get_data", 123), "Paradox file connection is closed or invalid")

  # Should fail with NULL externalptr
  pxdoc <- pxlib_open_file(db_path)
  pxlib_close_file(pxdoc)
  expect_error(.Call("R_pxlib_get_data", pxdoc), "Paradox file connection is closed or invalid")
})
