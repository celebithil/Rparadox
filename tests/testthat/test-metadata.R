# tests/testthat/test-metadata.R

library(testthat)
library(Rparadox)

# Helper function to run a standard metadata check
check_metadata <- function(db_path, encoding = NULL, exp_records, exp_fields, exp_names) {
  pxdoc <- pxlib_open_file(db_path, encoding = encoding)
  
  if (is.null(pxdoc)) {
    stop("Failed to open test file: ", basename(db_path))
  }
  
  on.exit(pxlib_close_file(pxdoc), add = TRUE)
  
  # Action: Get the metadata
  metadata <- pxlib_metadata(pxdoc)
  
  # Assertions
  expect_type(metadata, "list")
  expect_named(metadata, c("num_records", "num_fields", "fields", "encoding"))
  
  expect_equal(metadata$num_records, exp_records)
  expect_equal(metadata$num_fields, exp_fields)
  
  if (!is.null(encoding)) {
    expect_equal(metadata$encoding, encoding)
  }
  
  expect_s3_class(metadata$fields, "data.frame")
  expect_equal(nrow(metadata$fields), exp_fields)
  expect_named(metadata$fields, c("name", "type", "size"))
  
  # Compare field names
  expect_equal(metadata$fields$name, exp_names)
}

# --- Test Cases ---
test_that("pxlib_metadata reads metadata from country.db correctly", {
  check_metadata(
    db_path = system.file("extdata", "country.db", package = "Rparadox"),
    exp_records = 18,
    exp_fields = 5,
    exp_names = c("Name", "Capital", "Continent", "Area", "Population")
  )
})

test_that("pxlib_metadata handles encoding override for of_cp866.db correctly", {
  expected_names <- c(
    "Инвентарный номер", "Группа для переоценки", "Код по ОКОФ", "Наименование",
    "Дата приобретения", "Норма износа %", "Переоценка %", "Служебные отметки",
    "Отметка о списании", "Заводской номер", "метка", "Наименование КОМ", "Адрес",
    "Площадь", "На счет 2", "Назначение", "Примечание", "Основной счет", "Мол"
  )
  
  check_metadata(
    db_path = system.file("extdata", "of_cp866.db", package = "Rparadox"),
    encoding = "cp866",
    exp_records = 2197,
    exp_fields = 19,
    exp_names = expected_names
  )
})

test_that("pxlib_metadata for of.db correctly", {
  expected_names <- c(
    "Инвентарный номер", "Группа для переоценки", "Код по ОКОФ", "Наименование",
    "Дата приобретения", "Норма износа %", "Переоценка %", "Служебные отметки",
    "Отметка о списании", "Заводской номер", "метка", "Наименование КОМ", "Адрес",
    "Площадь", "На счет 2", "Назначение", "Примечание", "Основной счет", "Мол"
  )
  
  check_metadata(
    db_path = system.file("extdata", "of.db", package = "Rparadox"),
    encoding = "cp866",
    exp_records = 2197,
    exp_fields = 19,
    exp_names = expected_names
  )
})

test_that("pxlib_metadata handles empty files correctly", {
  check_metadata(
    db_path = system.file("extdata", "empty.db", package = "Rparadox"),
    exp_records = 0,
    exp_fields = 7,
    exp_names = c("ID", "ScientificName", "CommonName", "Order", "Genus", "Notes", "Picture")
  )
})

test_that("pxlib_metadata validates input correctly", {
  expect_error(pxlib_metadata("not_a_pxdoc"), "class 'pxdoc_t'")
  expect_error(pxlib_metadata(NULL), "class 'pxdoc_t'")
})