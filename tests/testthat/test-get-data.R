# test-get-data.R

library(testthat)
library(Rparadox)

# Test case 1: A simple .db table
test_that("pxlib_get_data reads country.db correctly", {
  # Path to the test database
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  
  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path)
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)
  
  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")
  
  # 2. Compare the result with a pre-saved, trusted reference file ("golden file")
  # test_path() creates a reliable path to files within tests/testthat/
  ref_path <- test_path("ref_country.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from country.db",
    expected.label = "Reference data from ref_country.rds"
  )
})

# Test case 2: A complex German file with various data types
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

# Test case 3: An English file with BLOB/Memo fields
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

# Test case 4: An Russian file with empty doscodepage
test_that("pxlib_get_data reads Russian file with empty doscodepage correctly", {
  # Path to the test database
  db_path <- system.file("extdata", "of.db", package = "Rparadox")

  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path, encoding = "CP866")
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)

  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")

  # 2. Compare the result with its corresponding reference file
  ref_path <- test_path("ref_of.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from of.db",
    expected.label = "Reference data from ref_of.rds"
  )
})

# Test case 5: An Russian file with doscodepage CP866
test_that("pxlib_get_data reads Russian file with doscodepage CP866 correctly", {
  # Path to the test database
  db_path <- system.file("extdata", "of_cp866.db", package = "Rparadox")

  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path)
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)

  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")

  # 2. Compare the result with its corresponding reference file
  ref_path <- test_path("ref_of.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from of.db",
    expected.label = "Reference data from ref_of.rds"
  )
})

# Test case 6: An empty file
test_that("pxlib_get_data handles an empty table gracefully", {
  # Path to the test database
  db_path <- system.file("extdata", "empty.db", package = "Rparadox")
  
  # --- Action: Open the file and get data ---
  px_doc <- pxlib_open_file(db_path)
  data_tbl <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)
  
  # --- Assertions ---
  # 1. Check that the result is a tibble
  expect_s3_class(data_tbl, "tbl_df")
  
  
  # 2. Compare the result with its corresponding reference file
  ref_path <- test_path("ref_empty.rds")
  expect_identical(
    object = data_tbl,
    expected = readRDS(ref_path),
    label = "Data loaded from empty.db",
    expected.label = "Reference data from ref_empty.rds"
  )
})

# Test case 7: incorrect argument
test_that("pxlib_get_data validates input correctly", {
  expect_error(pxlib_get_data("invalid"), "class 'pxdoc_t'")
  expect_error(pxlib_get_data(123), "class 'pxdoc_t'")
  expect_error(pxlib_get_data(NULL), "class 'pxdoc_t'")
})
