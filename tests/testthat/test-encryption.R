# tests/testthat/test-encryption.R
# All password validation happens in pxlib_open_file()

library(testthat)
library(Rparadox)

# =============================================================================
# Tests using read_paradox() - high-level API
# =============================================================================

test_that("Reading encrypted file works only with password (read_paradox)", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  
  # 1. Without password (expect error from pxlib_open_file)
  expect_error(
    read_paradox(enc_path), 
    "password protected"
  ) 
  
  # 2. With wrong password (expect error from pxlib_open_file)
  expect_error(
    read_paradox(enc_path, password = "wrong_password"),
    "Incorrect password"
  )
  
  # 3. With correct password
  ref_path <- test_path("ref_country.rds")
  data_tbl  <- read_paradox(enc_path, password = "rparadox")
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

test_that("read_paradox reads a complex encrypted file correctly", {
  db_path  <- system.file("extdata", "TypSammlung_encrypted.DB", package = "Rparadox")
  ref_path <- test_path("ref_TypSammlung.rds")
  
  data_tbl <- read_paradox(db_path, password = "rparadox")
  
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

# =============================================================================
# Tests using pxlib_open_file() and pxlib_get_data() - low-level API
# All password logic is in pxlib_open_file()!
# =============================================================================

test_that("pxlib_open_file rejects encrypted file without password", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  
  # Should fail when trying to open encrypted file without password
  expect_error(
    pxlib_open_file(enc_path),
    regexp = "password protected",
    info = "Opening encrypted file without password should fail"
  )
})

test_that("pxlib_open_file rejects encrypted file with wrong password", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  
  # Should fail with wrong password
  expect_error(
    pxlib_open_file(enc_path, password = "wrong_password"),
    regexp = "Incorrect password",
    info = "Opening encrypted file with wrong password should fail"
  )
})

test_that("pxlib_open_file + pxlib_get_data work with correct password", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  
  # Open file with correct password (validation happens here!)
  px_doc <- pxlib_open_file(enc_path, password = "rparadox")
  
  # Verify that file was opened
  expect_s3_class(px_doc, "pxdoc_t")
  expect_s3_class(px_doc, "externalptr")
  
  # Get data (decryption is automatic)
  data_tbl <- pxlib_get_data(px_doc)
  
  # Close file
  pxlib_close_file(px_doc)
  
  # Verify results
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

test_that("pxlib_get_data reads complex encrypted file correctly", {
  db_path <- system.file("extdata", "TypSammlung_encrypted.DB", package = "Rparadox")
  ref_path <- test_path("ref_TypSammlung.rds")
  
  # Open file with password
  px_doc <- pxlib_open_file(db_path, password = "rparadox")
  on.exit(pxlib_close_file(px_doc), add = TRUE)
  
  # Get data
  data_tbl <- pxlib_get_data(px_doc)
  
  # Verify results
  expect_s3_class(data_tbl, "tbl_df")
  expect_identical(data_tbl, readRDS(ref_path))
})

test_that("pxlib_open_file works normally for non-encrypted files", {
  normal_path <- system.file("extdata", "country.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  
  # Test 1: With password (should be ignored)
  px_doc2 <- pxlib_open_file(normal_path, password = "dummy")
  data_tbl2 <- pxlib_get_data(px_doc2)
  pxlib_close_file(px_doc2)
  expect_identical(data_tbl2, readRDS(ref_path))
  
  # Test 2: With NULL password explicitly
  px_doc3 <- pxlib_open_file(normal_path, password = NULL)
  data_tbl3 <- pxlib_get_data(px_doc3)
  pxlib_close_file(px_doc3)
  expect_identical(data_tbl3, readRDS(ref_path))
})

# =============================================================================
# Integration and workflow tests
# =============================================================================

test_that("Complete workflow with encrypted file", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  password <- "rparadox"
  
  # Step 1: Open file (password validation happens here)
  px_doc <- pxlib_open_file(enc_path, password = password)
  on.exit(pxlib_close_file(px_doc), add = TRUE)
  
  # Step 2: Get metadata
  metadata <- pxlib_metadata(px_doc)
  expect_type(metadata, "list")
  expect_gt(metadata$num_records, 0)
  
  # Step 3: Read data (decryption is automatic)
  data <- pxlib_get_data(px_doc)
  expect_s3_class(data, "tbl_df")
  expect_equal(nrow(data), metadata$num_records)
  expect_equal(ncol(data), metadata$num_fields)
  
  # Step 5: Verify result
  expect_identical(data, readRDS(ref_path))
})

test_that("Multiple reads from same encrypted file handle", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  password <- "rparadox"
  
  px_doc <- pxlib_open_file(enc_path, password = password)
  on.exit(pxlib_close_file(px_doc), add = TRUE)
  
  # Multiple reads should work and give identical results
  data1 <- pxlib_get_data(px_doc)
  data2 <- pxlib_get_data(px_doc)
  
  expect_identical(data1, data2,
                   info = "Multiple reads should give identical results")
})

test_that("Comparison: read_paradox vs low-level API give identical results", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  password <- "rparadox"
  
  # High-level API
  data_high_level <- read_paradox(enc_path, password = password)
  
  # Low-level API
  px_doc <- pxlib_open_file(enc_path, password = password)
  data_low_level <- pxlib_get_data(px_doc)
  pxlib_close_file(px_doc)
  
  # Compare
  expect_identical(data_high_level, data_low_level,
                   info = "Both APIs should produce identical results")
})

test_that("pxlib_open_file properly validates after multiple open/close cycles", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  ref_path <- test_path("ref_country.rds")
  password <- "rparadox"
  
  # First cycle
  px_doc1 <- pxlib_open_file(enc_path, password = password)
  data1 <- pxlib_get_data(px_doc1)
  pxlib_close_file(px_doc1)
  
  # Second cycle
  px_doc2 <- pxlib_open_file(enc_path, password = password)
  data2 <- pxlib_get_data(px_doc2)
  pxlib_close_file(px_doc2)
  
  # Third cycle
  px_doc3 <- pxlib_open_file(enc_path, password = password)
  data3 <- pxlib_get_data(px_doc3)
  pxlib_close_file(px_doc3)
  
  # All should be identical
  expect_identical(data1, data2)
  expect_identical(data2, data3)
  expect_identical(data1, readRDS(ref_path))
})

# =============================================================================
# Edge cases and error handling
# =============================================================================

test_that("pxlib_open_file handles invalid password types correctly", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  
  # Numeric password should fail
  expect_error(
    pxlib_open_file(enc_path, password = 123),
    regexp = "password.*character",
    ignore.case = TRUE
  )
  
  # Vector of passwords should fail
  expect_error(
    pxlib_open_file(enc_path, password = c("pass1", "pass2")),
    regexp = "single.*character",
    ignore.case = TRUE
  )
  
  # NA password should fail
  expect_error(
    pxlib_open_file(enc_path, password = NA_character_),
    regexp = "Argument 'password' must be a single character string.",
    ignore.case = TRUE
  )
})

test_that("pxlib_close_file properly cleans up encrypted file handles", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  
  px_doc <- pxlib_open_file(enc_path, password = "rparadox")
  expect_s3_class(px_doc, "pxdoc_t")
  
  # Close the file
  pxlib_close_file(px_doc)
  
  # Trying to use the closed handle should fail
  expect_error(
    pxlib_get_data(px_doc),
    regexp = "closed|invalid",
    ignore.case = TRUE
  )
  
  expect_error(
    pxlib_metadata(px_doc),
    regexp = "closed|invalid",
    ignore.case = TRUE
  )
})

test_that("Empty encrypted file is handled correctly", {
  # Skip if empty encrypted test file doesn't exist
  empty_enc_path <- system.file("extdata", "empty_encrypted.db", package = "Rparadox")
  
  px_doc <- pxlib_open_file(empty_enc_path, password = "rparadox")
  on.exit(pxlib_close_file(px_doc), add = TRUE)
  
  # Read should return empty tibble
  data <- pxlib_get_data(px_doc)
  expect_s3_class(data, "tbl_df")
  expect_equal(nrow(data), 0)
})