# tests/testthat/test-read_paradox.R

library(testthat)
library(Rparadox)

# --- Tests based on files from test-get-data.R ---

# Test 1: Simple DB file (country.db)
test_that("read_paradox reads a standard .db file correctly", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  
  data_tbl <- read_paradox(db_path)
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# Test 2: Complex file with various data types (TypSammlung.DB)
test_that("read_paradox reads a complex file with various types correctly", {
  db_path <- system.file("extdata", "TypSammlung.DB", package = "Rparadox")
  ref_path <- test_path("ref_TypSammlung.rds")
  
  data_tbl <- read_paradox(db_path)
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# Test 3: File with BLOB/Memo fields (biolife.db)
test_that("read_paradox reads a file with BLOBs correctly", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
  ref_path <- test_path("ref_biolife.rds")
  
  data_tbl <- read_paradox(db_path)
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# Test 4: File with Russian encoding (requires explicit specification)
test_that("read_paradox handles encoding override correctly for 'of.db'", {
  db_path <- system.file("extdata", "of.db", package = "Rparadox")
  ref_path <- test_path("ref_of.rds")
  
  data_tbl <- read_paradox(db_path, encoding = 'cp866')
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# Test 5: File with Russian encoding (detected from header)
test_that("read_paradox reads correct encoding from header for 'of_cp866.db'", {
  db_path <- system.file("extdata", "of_cp866.db", package = "Rparadox")
  ref_path <- test_path("ref_of.rds")
  
  data_tbl <- read_paradox(db_path)
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# --- Edge case tests ---

# Test 6: Empty file (0 records, but has headers)
test_that("read_paradox handles empty .db files correctly", {
  db_path <- system.file("extdata", "empty.db", package = "Rparadox")
  ref_path <- test_path("ref_empty.rds")
  
  data_tbl <- read_paradox(db_path)
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_equal(nrow(data_tbl), 0)
  expect_identical(data_tbl, readRDS(ref_path))
})

# Test 7: Non-existent file
test_that("read_paradox handles non-existent files gracefully", {
  expect_warning(
    result_tbl <- read_paradox("non_existent_file_123.db"),
    regexp = "File not found"
  )
  expect_s3_class(result_tbl, "tbl_df")
  expect_equal(nrow(result_tbl), 0)
})

# Test 8: Invalid arguments
test_that("read_paradox validates its arguments", {
  # Invalid path
  expect_error(
    read_paradox(123),
    "Argument 'path' must be a single character string."
  )
  
  # Invalid encoding
  db_path <- system.file("extdata", "country.db", package = "Rparadox")
  expect_error(
    read_paradox(db_path, encoding = 123),
    "Argument 'encoding' must be NULL or a single character string."
  )
})