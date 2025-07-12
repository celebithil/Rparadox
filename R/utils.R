# Внутренняя (не экспортируемая) функция для регистронезависимого поиска .mb файла
find_blob_file <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path)) {
    return(NULL)
  }
  
  # Получаем директорию и имя файла без расширения
  dir_name <- dirname(db_path)
  base_name <- tools::file_path_sans_ext(basename(db_path))
  
  # Получаем список всех файлов в директории
  all_files <- list.files(dir_name)
  
  # Создаем паттерн для поиска: "имя_файла.mb"
  # ^ - начало строки, \\. - точка, $ - конец строки
  pattern <- paste0("^", base_name, "\\.mb$")
  
  # Ищем файл, игнорируя регистр
  matching_files <- grep(pattern, all_files, ignore.case = TRUE, value = TRUE)
  
  if (length(matching_files) > 0) {
    # Если найдено несколько файлов (например, data.mb и data.MB),
    # берем первый и возвращаем полный путь к нему
    return(file.path(dir_name, matching_files[1]))
  }
  
  # Если ничего не найдено
  return(NULL)
}