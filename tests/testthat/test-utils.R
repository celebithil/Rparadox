library(testthat)
library(Rparadox)

test_that("recode_if_needed works correctly", {
  # Access internal function
  recode_if_needed <- Rparadox:::recode_if_needed

  # 1. NULL or empty encoding returns unchanged
  expect_identical(recode_if_needed("test", NULL), "test")
  expect_identical(recode_if_needed("test", ""), "test")

  # 2. Non-character vector returns unchanged
  expect_identical(recode_if_needed(123, "cp866"), 123)
  expect_identical(recode_if_needed(TRUE, "cp866"), TRUE)

  # 3. All NA returns unchanged
  expect_identical(recode_if_needed(NA_character_, "cp866"), NA_character_)
  expect_identical(recode_if_needed(c(NA_character_, NA_character_), "cp866"), c(NA_character_, NA_character_))

  # 4. Mixed NA values
  # Using a basic ASCII-compatible test if iconv fails or behaves unexpectedly
  # 'é' (U+00E9) is 0xE9 in CP1252.
  input_enc <- iconv("é", from = "UTF-8", to = "CP1252")

  if (!is.na(input_enc)) {
    result <- recode_if_needed(c(input_enc, NA_character_), "CP1252")
    # Use as.character and check equality to handle potential encoding attribute differences
    expect_equal(as.character(result[1]), "é")
    expect_true(is.na(result[2]))
  } else {
    # Fallback for environments with limited iconv
    result <- recode_if_needed(c("test", NA_character_), "CP1252")
    expect_equal(as.character(result[1]), "test")
    expect_true(is.na(result[2]))
  }
})

test_that("find_blob_file works correctly", {
  find_blob_file <- Rparadox:::find_blob_file

  # Create a temporary directory for testing
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Helper to normalize slashes for comparison
  norm_slash <- function(x) {
    if (is.null(x)) return(NULL)
    gsub("\\\\", "/", normalizePath(x, mustWork = FALSE))
  }

  tmp_dir_norm <- norm_slash(tmp_dir)
  db_path <- file.path(tmp_dir_norm, "test.db")
  file.create(db_path)

  # 1. No blob file exists
  expect_null(find_blob_file(db_path))

  # 2. Matching blob file exists (.mb)
  mb_path <- norm_slash(file.path(tmp_dir_norm, "test.mb"))
  file.create(mb_path)
  expect_equal(norm_slash(find_blob_file(db_path)), mb_path)

  # 3. Case-insensitive match (.MB)
  unlink(mb_path)
  MB_path <- norm_slash(file.path(tmp_dir_norm, "test.MB"))
  file.create(MB_path)
  expect_equal(norm_slash(find_blob_file(db_path)), MB_path)

  # 4. Multiple matches (returns one of them)
  file.create(mb_path)
  res <- norm_slash(find_blob_file(db_path))
  expect_true(res %in% c(mb_path, MB_path))
})
