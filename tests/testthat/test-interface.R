library(testthat)
library(Rparadox)

# Путь к тестовой базе данных. Пропускаем тесты, если ее нет.
db_path <- system.file("extdata", "country.db", package = "Rparadox")
skip_if_not(file.exists(db_path), "Test database 'country.db' not found in inst/extdata.")

test_that("pxlib_open_file and pxlib_close_file work correctly", {
  # 1. Открытие корректного файла
  px_doc <- pxlib_open_file(db_path)
  
  # Проверяем, что получили валидный объект
  expect_s3_class(px_doc, "pxdoc_t")
  expect_true(inherits(px_doc, "externalptr"))
  
  # Загрузка эталонных данных из RDS
  #expected_fields <- readRDS("country_fields.rds")
  
  # Проверка полного соответствия
  #expect_identical(actual_fields, expected_fields)
  
  # 4. Закрытие файла
  expect_invisible(pxlib_close_file(px_doc))
  
  # Проверка, что после закрытия указатель очищен
  # Повторный вызов C-функции на очищенном указателе должен вызвать ошибку
  expect_error(.Call("R_pxlib_num_fields", px_doc))
})

test_that("pxlib_open_file handles errors", {
  # Несуществующий файл должен вернуть NULL и выдать предупреждение
  expect_warning(
    expect_null(pxlib_open_file("non_existent_123.db")),
    "File not found"
  )
  
  # Неверный тип аргумента. Сообщение об ошибке должно ТОЧНО совпадать.
  expect_error(
    pxlib_open_file(123), 
    "File path must be a single, non-NA character string."
  )
})

test_that("pxlib_close_file handles errors", {
  # Неверный тип. Сообщение об ошибке должно ТОЧНО совпадать.
  # Обновляем ожидаемое сообщение
  expect_error(
    pxlib_close_file("not a pointer"), 
    "Invalid argument: 'pxdoc' must be an external pointer of class 'pxdoc_t'."
  )
})