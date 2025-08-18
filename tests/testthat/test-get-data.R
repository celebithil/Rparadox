# test-get-data.R

library(testthat)
library(Rparadox)

# Test case 1: A complex German file with various data types
test_that("pxlib_get_data reads german character data correctly", {
  # Path to the test database
  db_path <- system.file("extdata", "TypSammlung.DB", package = "Rparadox")
  
  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path)
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)
  
  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")
  
  # 2. Compare the result with a pre-saved, trusted reference file ("golden file")
  # test_path() creates a reliable path to files within tests/testthat/
  ref_path <- test_path("ref_TypSammlung.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from TypSammlung.DB",
    expected.label = "Reference data from ref_TypSammlung.rds"
  )
})

# Test case 2: An English file with BLOB/Memo fields
test_that("pxlib_get_data reads english data with BLOBs correctly", {
  # Path to the test database
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")

  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path)
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)

  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")

  # 2. Compare the result with its corresponding reference file
  ref_path <- test_path("ref_biolife.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from biolife.db",
    expected.label = "Reference data from ref_biolife.rds"
  )
})

# A good practice is to keep placeholders for future tests.
test_that("pxlib_get_data handles an empty table gracefully", {
  # This test requires creating a valid but empty Paradox file, which is hard.
  # We can skip it for now but it's a good reminder for future development.
  skip("Test for empty table not yet implemented.")
})