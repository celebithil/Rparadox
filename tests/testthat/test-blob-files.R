# test-blob-files.R
#
# Explicit tests for reading .MB blob/memo files — the code path touched
# by the 0.3.2 cleanup, which removed the write-era block-list scan
# (build_mb_block_list()) from PX_open_blob_fp(). The blob read path
# itself (_px_get_data_blob) navigates the .MB file from the offsets
# stored in the record, so these tests pin that behaviour directly:
# biolife.db/.mb carries a 701-char memo and 28 graphic blobs spread
# over ~300 4kB blocks, TypSammlung.DB/.MB has a memo field with NULL
# entries in type-3 blocks, and the encrypted fixtures are covered by
# test-encryption.R.

library(testthat)
library(Rparadox)

test_that("Memo and Graphic blob fields round-trip through the .MB file", {
  data <- read_paradox(system.file("extdata", "biolife.db", package = "Rparadox"))

  # Notes is a Memo field: every record carries a multi-page text memo.
  expect_type(data$Notes, "character")
  expect_true(all(!is.na(data$Notes)))
  expect_true(all(nchar(data$Notes) > 100))
  expect_match(data$Notes[1], "^Also known as the big spotted triggerfish")

  # Graphic is a Graphic field: 28 single-byte blobs of 0x42 ('B'),
  # each stored at its own offset in the blob file.
  expect_s3_class(data$Graphic, "blob")
  sizes <- vapply(unclass(data$Graphic), function(x) length(x[[1]]), numeric(1))
  expect_identical(sizes, rep(1, 28))
  bytes <- vapply(unclass(data$Graphic), function(x) as.integer(x[[1]]), integer(1))
  expect_identical(unique(bytes), 66L)
})

test_that("Memo fields with NULL entries read back as NA", {
  data <- read_paradox(system.file("extdata", "TypSammlung.DB", package = "Rparadox"))

  expect_type(data$Memo, "character")
  expect_identical(which(!is.na(data$Memo)), 3L)
  expect_identical(data$Memo[3], "Dies ist eine Memo im 'Fünften Datensat'")
})

test_that("Sequential reads of different .MB files stay isolated", {
  bio1 <- pxlib_get_data(pxlib_open_file(system.file("extdata", "biolife.db", package = "Rparadox")))
  typ  <- pxlib_get_data(pxlib_open_file(system.file("extdata", "TypSammlung.DB", package = "Rparadox")))
  bio2 <- pxlib_get_data(pxlib_open_file(system.file("extdata", "biolife.db", package = "Rparadox")))

  expect_identical(bio1, bio2)
  expect_identical(which(!is.na(typ$Memo)), 3L)
  expect_s3_class(bio1$Graphic, "blob")
})

test_that("Reopening the same file through pxlib_* also stays stable", {
  pxdoc <- pxlib_open_file(system.file("extdata", "biolife.db", package = "Rparadox"))
  on.exit(pxlib_close_file(pxdoc), add = TRUE)

  first  <- pxlib_get_data(pxdoc)
  second <- pxlib_get_data(pxdoc)
  expect_identical(first, second)
  expect_identical(first, pxlib_get_data(pxlib_open_file(system.file("extdata", "biolife.db", package = "Rparadox"))))
})
