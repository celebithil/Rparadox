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
  input <- c("тест", NA) # "тест" in UTF-8
  # If we say it's cp866 but it's actually UTF-8, stringi might mangle it or handle it.
  # Let's use a real cp866 example: 'т' is 0xF2 in CP866
  cp866_val <- rawToChar(as.raw(0xf2)) # 'т' in CP866

  # We can't easily test the actual conversion without knowing stringi is working,
  # but we can test the logic of preserving NA.
  result <- recode_if_needed(c(cp866_val, NA_character_), "cp866")
  expect_true(is.na(result[2]))
  expect_false(is.na(result[1]))
  expect_equal(result[1], "т") # UTF-8 'т'
})

test_that("find_blob_file works correctly", {
  find_blob_file <- Rparadox:::find_blob_file

  # Create a temporary directory for testing
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  db_path <- file.path(tmp_dir, "test.db")
  file.create(db_path)

  # 1. No blob file exists
  expect_null(find_blob_file(db_path))

  # 2. Matching blob file exists (.mb)
  mb_path <- file.path(tmp_dir, "test.mb")
  file.create(mb_path)
  expect_equal(find_blob_file(db_path), mb_path)

  # 3. Case-insensitive match (.MB)
  unlink(mb_path)
  MB_path <- file.path(tmp_dir, "test.MB")
  file.create(MB_path)
  expect_equal(find_blob_file(db_path), MB_path)

  # 4. Multiple matches (returns one of them)
  file.create(mb_path)
  res <- find_blob_file(db_path)
  expect_true(res %in% c(mb_path, MB_path))
})
