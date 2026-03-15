library(testthat)
library(Rparadox)

test_that("recode_if_needed works correctly", {
  # Access internal function
  recode_if_needed <- Rparadox:::recode_if_needed

  # 1. NULL or empty encoding returns unchanged
  expect_identical(recode_if_needed("test", NULL), "test")
  expect_identical(recode_if_needed("test", ""), "test")

  # 2. Non-character vector returns unchanged
  expect_identical(recode_if_needed(123, "cp1252"), 123)
  expect_identical(recode_if_needed(TRUE, "cp1252"), TRUE)

  # 3. All NA returns unchanged
  expect_identical(recode_if_needed(NA_character_, "cp1252"), NA_character_)
  expect_identical(recode_if_needed(c(NA_character_, NA_character_), "cp1252"), c(NA_character_, NA_character_))

  # 4. Mixed NA values
  # Use a common Western European character to avoid locale issues with Cyrillic
  # 'é' (U+00E9) is 0xE9 in CP1252.
  input_enc <- iconv("\u00E9", from = "UTF-8", to = "CP1252")

  if (!is.na(input_enc)) {
    result <- recode_if_needed(c(input_enc, NA_character_), "CP1252")
    expect_equal(as.character(result[1]), "\u00E9")
    expect_true(is.na(result[2]))
  } else {
    # Fallback if the environment doesn't support CP1252
    result <- recode_if_needed(c("test", NA_character_), "CP1252")
    expect_equal(as.character(result[1]), "test")
    expect_true(is.na(result[2]))
  }
})

test_that("find_blob_file works correctly", {
  find_blob_file <- Rparadox:::find_blob_file

  # Helper to normalize slashes for robust path comparison across OS (especially Windows)
  norm_path <- function(p) {
    if (is.null(p)) return(NULL)
    # Convert to absolute path, then force forward slashes
    p <- normalizePath(p, mustWork = FALSE)
    gsub("\\\\", "/", p)
  }

  # Create a temporary directory for testing
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  tmp_dir_norm <- norm_path(tmp_dir)
  db_path <- file.path(tmp_dir_norm, "test.db")
  file.create(db_path)

  # 1. No blob file exists
  expect_null(find_blob_file(db_path))

  # 2. Matching blob file exists (.mb)
  mb_path <- file.path(tmp_dir_norm, "test.mb")
  file.create(mb_path)
  expect_equal(norm_path(find_blob_file(db_path)), norm_path(mb_path))

  # 3. Case-insensitive match (.MB)
  unlink(mb_path)
  MB_path <- file.path(tmp_dir_norm, "test.MB")
  file.create(MB_path)
  expect_equal(norm_path(find_blob_file(db_path)), norm_path(MB_path))

  # 4. Multiple matches (returns one of them)
  file.create(mb_path)
  res <- norm_path(find_blob_file(db_path))
  expect_true(res %in% c(norm_path(mb_path), norm_path(MB_path)))
})
