# tests/testthat/test-find_blob_file.R
# Unit tests for the internal helper find_blob_file()

library(testthat)

find_blob_file <- Rparadox:::find_blob_file

test_that("find_blob_file finds .mb file (lowercase)", {
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(tmp_dir, "data.db")
  mb_path <- file.path(tmp_dir, "data.mb")
  file.create(db_path)
  file.create(mb_path)

  expect_equal(find_blob_file(db_path), normalizePath(mb_path, winslash = "/", mustWork = FALSE))
})

test_that("find_blob_file finds .MB file (uppercase)", {
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(tmp_dir, "data.db")
  mb_path <- file.path(tmp_dir, "data.MB")
  file.create(db_path)
  file.create(mb_path)

  expect_equal(find_blob_file(db_path), normalizePath(mb_path, winslash = "/", mustWork = FALSE))
})

test_that("find_blob_file returns NULL when no blob file exists", {
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(tmp_dir, "data.db")
  file.create(db_path)

  expect_null(find_blob_file(db_path))
})

test_that("find_blob_file returns NULL when other files exist but no .mb", {
  tmp_dir <- tempfile("blobtest")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  db_path <- file.path(tmp_dir, "data.db")
  file.create(db_path)
  file.create(file.path(tmp_dir, "other.txt"))
  file.create(file.path(tmp_dir, "data.dat"))

  expect_null(find_blob_file(db_path))
})

test_that("find_blob_file works with TypSammlung.DB (uppercase .MB)", {
  db_path <- system.file("extdata", "TypSammlung.DB", package = "Rparadox")
  expected <- system.file("extdata", "TypSammlung.MB", package = "Rparadox")

  expect_equal(find_blob_file(db_path), expected)
})

test_that("find_blob_file works with biolife.db (lowercase .mb)", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
  expected <- system.file("extdata", "biolife.mb", package = "Rparadox")

  expect_equal(find_blob_file(db_path), expected)
})

test_that("find_blob_file works with empty.db (lowercase .mb)", {
  db_path <- system.file("extdata", "empty.db", package = "Rparadox")
  expected <- system.file("extdata", "empty.mb", package = "Rparadox")

  expect_equal(find_blob_file(db_path), expected)
})

test_that("find_blob_file returns NULL for country.db (no .mb file)", {
  db_path <- system.file("extdata", "country.db", package = "Rparadox")

  expect_null(find_blob_file(db_path))
})

test_that("find_blob_file returns NULL for of.db (no .mb file)", {
  db_path <- system.file("extdata", "of.db", package = "Rparadox")

  expect_null(find_blob_file(db_path))
})
