library(testthat)
library(Rparadox)

test_that("pxlib_open_file warns when BLOB file fails to attach", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")

  tmp_dir <- tempfile("blobfail")
  dir.create(tmp_dir, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Use normalized paths to avoid issues on Windows
  tmp_dir <- normalizePath(tmp_dir, winslash = "/", mustWork = TRUE)
  target_db <- file.path(tmp_dir, "biolife.db")
  target_mb <- file.path(tmp_dir, "biolife.mb")

  # Copy .db file to tmp_dir
  file.copy(db_path, target_db)

  # Create a file with invalid size (1 byte) which will fail pxlib validation
  writeBin(as.raw(0), target_mb)

  # Verify find_blob_file finds it (internal check)
  expect_false(is.null(Rparadox:::find_blob_file(target_db)))

  # Now pxlib_open_file will find "biolife.mb" but PX_set_blob_file should fail
  # because the size is not multiple of 4KB.
  # It should trigger BOTH a C warning and an R warning.
  # We use a broad regex or no regex to be safe.
  expect_warning(
    pxdoc <- pxlib_open_file(target_db),
    "failed to (set|attach)"
  )

  if (!is.null(pxdoc)) {
    pxlib_close_file(pxdoc)
  }
})
