library(testthat)
library(Rparadox)

test_that("empty string password is rejected", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  skip_if_not(file.exists(enc_path), "country_encrypted.db not found")

  expect_error(
    pxlib_open_file(enc_path, password = ""),
    "Incorrect password"
  )
})

test_that("password with special characters works correctly", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  skip_if_not(file.exists(enc_path), "country_encrypted.db not found")

  expect_error(
    pxlib_open_file(enc_path, password = "rparadox!"),
    "Incorrect password"
  )
})

test_that("very long password (255 chars, max) is handled without buffer overflow", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  skip_if_not(file.exists(enc_path), "country_encrypted.db not found")

  long_pw <- paste0(rep("x", 255), collapse = "")
  expect_error(
    pxlib_open_file(enc_path, password = long_pw),
    "Incorrect password"
  )
})

test_that("read_paradox rejects empty string password", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  skip_if_not(file.exists(enc_path), "country_encrypted.db not found")

  expect_error(
    read_paradox(enc_path, password = ""),
    "Incorrect password"
  )
})

test_that("read_paradox rejects very long password (255 chars)", {
  enc_path <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
  skip_if_not(file.exists(enc_path), "country_encrypted.db not found")

  long_pw <- paste0(rep("x", 255), collapse = "")
  expect_error(
    read_paradox(enc_path, password = long_pw),
    "Incorrect password"
  )
})
