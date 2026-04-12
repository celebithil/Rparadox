# tests/testthat/test-recode_if_needed.R
# Unit tests for the internal helper recode_if_needed()

library(testthat)

recode_if_needed <- Rparadox:::recode_if_needed

test_that("recode_if_needed returns unchanged when encoding is NULL", {
  input <- c("hello", "world")
  expect_identical(recode_if_needed(input, NULL), input)
})

test_that("recode_if_needed returns unchanged when encoding is empty string", {
  input <- c("hello", "world")
  expect_identical(recode_if_needed(input, ""), input)
})

test_that("recode_if_needed returns unchanged for non-character input", {
  expect_identical(recode_if_needed(1:5, "UTF-8"), 1:5)
  expect_identical(recode_if_needed(c(TRUE, FALSE), "UTF-8"), c(TRUE, FALSE))
  expect_identical(recode_if_needed(3.14, "UTF-8"), 3.14)
})

test_that("recode_if_needed returns unchanged when all values are NA", {
  input <- c(NA_character_, NA_character_)
  result <- recode_if_needed(input, "UTF-8")
  expect_identical(result, input)
  expect_true(all(is.na(result)))
})

test_that("recode_if_needed preserves NA values during recoding", {
  input <- c("hello", NA_character_, "world")
  result <- recode_if_needed(input, "UTF-8")

  expect_length(result, 3)
  expect_equal(result[1], "hello")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "world")
})

test_that("recode_if_needed converts encoding correctly", {
  # "Mädchen" — "ä" is 0xE4 in ISO-8859-1
  input <- "M\xe4dchen"

  result <- recode_if_needed(input, "ISO-8859-1")

  expect_equal(result, "M\u00e4dchen")
})

test_that("recode_if_needed handles single NA value", {
  result <- recode_if_needed(NA_character_, "UTF-8")
  expect_true(is.na(result))
  expect_length(result, 1)
})

test_that("recode_if_needed handles empty character vector", {
  result <- recode_if_needed(character(0), "UTF-8")
  expect_identical(result, character(0))
})
