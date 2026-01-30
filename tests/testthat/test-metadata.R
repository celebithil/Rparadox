# tests/testthat/test-metadata.R

library(testthat)
library(Rparadox)

# Helper function to run a standard metadata check
# Updated to include checks for types and sizes
check_metadata <- function(db_path, encoding = NULL, exp_records, exp_fields, 
                           exp_names, exp_types = NULL, exp_sizes = NULL) {

  pxdoc <- pxlib_open_file(db_path, encoding = encoding)
  
  if (is.null(pxdoc)) {
    stop("Failed to open test file: ", basename(db_path))
  }
  
  on.exit(pxlib_close_file(pxdoc), add = TRUE)
  
  # Action: Get the metadata
  metadata <- pxlib_metadata(pxdoc)
  
  # --- Assertions ---
  expect_type(metadata, "list")
  expect_named(metadata, c("num_records", "num_fields", "fields", "encoding"))
  
  expect_equal(metadata$num_records, exp_records, label = "Number of records")
  expect_equal(metadata$num_fields, exp_fields, label = "Number of fields")

  if (!is.null(encoding)) {
    expect_equal(metadata$encoding, encoding, label = "Encoding")
  }

  expect_s3_class(metadata$fields, "data.frame")
  expect_equal(nrow(metadata$fields), exp_fields)
  expect_named(metadata$fields, c("name", "type", "size"))

  # Compare field names
  expect_equal(metadata$fields$name, exp_names, label = "Field names")

  # Compare field types (if provided)
  if (!is.null(exp_types)) {
    expect_equal(metadata$fields$type, exp_types, label = "Field types")
  }

  # Compare field sizes (if provided)
  if (!is.null(exp_sizes)) {
    expect_equal(metadata$fields$size, exp_sizes, label = "Field sizes")
  }
}

# --- Test Case 1: Comprehensive Data Types (TypSammlung.DB) ---
test_that("pxlib_metadata correctly identifies all Paradox field types", {
  expected_names <- c(
    "Alpha", "Numerisch", "Währung", "Integer kurz", "Integer lang", 
    "BCD", "Datum", "Zeit", "Datum/Zeit", "Memo", 
    "Logisch", "Zähler", "Binär", "Bytes"
  )

  expected_types <- c(
    "Alpha", "Number", "Currency", "Short", "Long",
    "BCD", "Date", "Time", "Timestamp", "Memo",
    "Logical", "Autoincrement", "Binary", "Bytes"
  )

  expected_sizes <- c(30, 8, 8, 2, 4, 17, 4, 4, 8, 11, 1, 4, 10, 255)

  check_metadata(
    db_path = system.file("extdata", "TypSammlung.DB", package = "Rparadox"),
    # Note: Auto-detection often finds the encoding, but here we expect CP1252 based on output
    encoding = NULL,
    exp_records = 5,
    exp_fields = 14,
    exp_names = expected_names,
    exp_types = expected_types,
    exp_sizes = expected_sizes
  )
})

# --- Test Case 2: Standard English Data (country.db) ---
test_that("pxlib_metadata reads metadata from country.db correctly", {
  expected_names <- c("Name", "Capital", "Continent", "Area", "Population")
  expected_types <- c("Alpha", "Alpha", "Alpha", "Number", "Number")
  expected_sizes <- c(24, 24, 24, 8, 8)

  check_metadata(
    db_path = system.file("extdata", "country.db", package = "Rparadox"),
    encoding = NULL, # The output showed CP850 is auto-detected or default
    exp_records = 18,
    exp_fields = 5,
    exp_names = expected_names,
    exp_types = expected_types,
    exp_sizes = expected_sizes
  )
})

# --- Test Case 3: Cyrillic Data CP866 (of_cp866.db) ---
test_that("pxlib_metadata handles CP866 encoding correctly", {
  expected_names <- c(
    "Инвентарный номер", "Группа для переоценки", "Код по ОКОФ", "Наименование",
    "Дата приобретения", "Норма износа %", "Переоценка %", "Служебные отметки",
    "Отметка о списании", "Заводской номер", "метка", "Наименование КОМ", "Адрес",
    "Площадь", "На счет 2", "Назначение", "Примечание", "Основной счет", "Мол"
  )
  
  # Based on output: mostly Alpha, with Date at index 5, Numbers at 6 and 7
  expected_types <- c(
    "Alpha", "Alpha", "Alpha", "Alpha", 
    "Date", "Number", "Number", "Alpha",
    "Alpha", "Alpha", "Alpha", "Alpha", "Alpha",
    "Alpha", "Alpha", "Alpha", "Alpha", "Alpha", "Alpha"
  )

  check_metadata(
    db_path = system.file("extdata", "of_cp866.db", package = "Rparadox"),
    encoding = NULL,
    exp_records = 2197,
    exp_fields = 19,
    exp_names = expected_names,
    exp_types = expected_types
  )
})

# --- Test Case 4: Cyrillic Data CP866 (of.db) ---
test_that("pxlib_metadata handles force CP866 encoding correctly", {
  expected_names <- c(
    "Инвентарный номер", "Группа для переоценки", "Код по ОКОФ", "Наименование",
    "Дата приобретения", "Норма износа %", "Переоценка %", "Служебные отметки",
    "Отметка о списании", "Заводской номер", "метка", "Наименование КОМ", "Адрес",
    "Площадь", "На счет 2", "Назначение", "Примечание", "Основной счет", "Мол"
  )
  
  # Based on output: mostly Alpha, with Date at index 5, Numbers at 6 and 7
  expected_types <- c(
    "Alpha", "Alpha", "Alpha", "Alpha",
    "Date", "Number", "Number", "Alpha",
    "Alpha", "Alpha", "Alpha", "Alpha", "Alpha",
    "Alpha", "Alpha", "Alpha", "Alpha", "Alpha", "Alpha"
  )

  check_metadata(
    db_path = system.file("extdata", "of.db", package = "Rparadox"),
    encoding = "CP866", # Explicitly checking we can pass encoding
    exp_records = 2197,
    exp_fields = 19,
    exp_names = expected_names,
    exp_types = expected_types
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