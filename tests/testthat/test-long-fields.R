# test-long-fields.R

library(testthat)
library(Rparadox)

# Regression tests for Long value decoding (get_long_be() in
# src/px_misc.c), released in Rparadox 0.3.1.
#
# The 0.3.1 fix restored the signed interpretation of the 32-bit
# big-endian word inside get_long_be(): the pre-0.3.1 implementation
# zero-extended it, which is undefined-behaviour-adjacent and diverges
# from upstream pxlib. NB: at the R level that defect was masked by the
# long -> int truncation in px_to_sexp() (src/interface.c), so these
# tests pin the R-level contract rather than the C internal: every
# storable Long value must round-trip exactly through
# pxlib_open_file() -> pxlib_get_data().
#
# The bundled corpora contain only one negative Long (-40 in
# TypSammlung.DB, checked implicitly by a golden-file comparison), which
# is not enough to pin down the boundary behaviour; these tests exercise
# it explicitly via a minimal generated Paradox 3.0 table (see
# helper-long-fixture.R).

test_that("Long boundary values round-trip exactly", {
  values <- c(-1L, 1L, 0L, 40L, -40L, 2147483647L, -2147483647L)
  db_path <- make_long_db(values)

  pxdoc <- pxlib_open_file(db_path)
  expect_s3_class(pxdoc, "pxdoc_t")
  on.exit(pxlib_close_file(pxdoc), add = TRUE)

  data <- pxlib_get_data(pxdoc)

  expect_identical(data$value, expected = values)
})

test_that("Negative Long values keep the signed interpretation", {
  values <- c(-1L, -2L, -100L, 100L)
  db_path <- make_long_db(values)

  pxdoc <- pxlib_open_file(db_path)
  on.exit(pxlib_close_file(pxdoc), add = TRUE)

  data <- pxlib_get_data(pxdoc)

  expect_identical(data$value, expected = values)
  expect_type(data$value, "integer")
})

test_that("Stored 0x00000000 reads back as NA (Paradox has no -2^31 Long)", {
  values <- c(NA_integer_, 5L, NA_integer_, -5L)
  db_path <- make_long_db(values)

  pxdoc <- pxlib_open_file(db_path)
  on.exit(pxlib_close_file(pxdoc), add = TRUE)

  data <- pxlib_get_data(pxdoc)

  expect_identical(data$value, expected = values)
  expect_true(is.na(data$value[1]))
  expect_true(is.na(data$value[3]))
})

test_that("Generated Long table reports correct metadata", {
  values <- c(-1L, 0L, 1L, 2147483647L, -2147483647L)
  db_path <- make_long_db(values)

  pxdoc <- pxlib_open_file(db_path)
  on.exit(pxlib_close_file(pxdoc), add = TRUE)

  metadata <- pxlib_metadata(pxdoc)

  expect_identical(metadata$num_records, 5L)
  expect_identical(metadata$num_fields, 1L)
  expect_identical(metadata$fields$type, "Long")
  expect_identical(metadata$fields$name, "value")
})
