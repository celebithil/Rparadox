library(testthat)
library(Rparadox)

test_that("read_paradox works without .mb file present (BLOB data becomes NULL)", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
  mb_path <- system.file("extdata", "biolife.mb", package = "Rparadox")

  skip_if_not(file.exists(db_path), "biolife.db not found")
  skip_if_not(file.exists(mb_path), "biolife.mb not found")

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  file.copy(db_path, file.path(tmp_dir, "biolife.db"))

  result <- suppressMessages(read_paradox(file.path(tmp_dir, "biolife.db")))
  expect_s3_class(result, "tbl_df")
  expect_true("Notes" %in% names(result) || "Category" %in% names(result))
})

test_that("read_paradox handles .db file when .mb file is renamed", {
  db_path <- system.file("extdata", "empty.db", package = "Rparadox")
  mb_path <- system.file("extdata", "empty.mb", package = "Rparadox")

  skip_if_not(file.exists(db_path), "empty.db not found")
  skip_if_not(file.exists(mb_path), "empty.mb not found")

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  file.copy(db_path, file.path(tmp_dir, "empty.db"))

  result <- suppressMessages(read_paradox(file.path(tmp_dir, "empty.db")))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("read_paradox works with corrupted BLOB file", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
  skip_if_not(file.exists(db_path), "biolife.db not found")

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  file.copy(db_path, file.path(tmp_dir, "biolife.db"))
  writeLines("not a blob file", file.path(tmp_dir, "biolife.mb"))

  result <- suppressMessages(suppressWarnings(read_paradox(file.path(tmp_dir, "biolife.db"))))
  expect_s3_class(result, "tbl_df")
  expect_gt(ncol(result), 0)
})
