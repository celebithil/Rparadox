library(testthat)
library(Rparadox)

test_that("pxlib_open_file warns when BLOB file fails to attach", {
  db_path <- system.file("extdata", "biolife.db", package = "Rparadox")

  # To simulate failure, we could create a directory with the name of the .mb file
  # so that PX_set_blob_file (which likely expects a file) fails.

  tmp_dir <- tempfile("blobfail")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Copy .db file to tmp_dir
  file.copy(db_path, file.path(tmp_dir, "biolife.db"))

  # Create a directory named biolife.mb
  dir.create(file.path(tmp_dir, "biolife.mb"))

  # Now pxlib_open_file will find "biolife.mb" but PX_set_blob_file should fail
  expect_warning(
    pxdoc <- pxlib_open_file(file.path(tmp_dir, "biolife.db")),
    "failed to attach it"
  )

  if (!is.null(pxdoc)) {
    pxlib_close_file(pxdoc)
  }
})
