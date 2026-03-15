library(testthat)
library(Rparadox)

test_that("read_paradox handles corrupted files", {
  # Create a corrupted file (truncated)
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  corrupted_path <- tempfile(fileext = ".db")

  # Read first 100 bytes only
  raw_data <- readBin(db_path, what = "raw", n = 100)
  writeBin(raw_data, corrupted_path)
  on.exit(unlink(corrupted_path))

  # PX_open_file might fail or return NULL
  # If it opens but get_data fails:
  expect_error(
    read_paradox(corrupted_path),
    "Failed to read data|possibly corrupted|pxlib failed to open file",
    ignore.case = TRUE
  )
})

test_that("pxlib_open_file handles corrupted/non-paradox files", {
  random_file <- tempfile(fileext = ".db")
  writeBin(as.raw(runif(100, 0, 255)), random_file)
  on.exit(unlink(random_file))

  # pxlib should fail to open it as a Paradox file
  expect_warning(
    expect_null(pxlib_open_file(random_file)),
    "pxlib failed to open file"
  )
})
