# Rparadox/R/pxlib_open_file.R

#' Open a Paradox database file
#'
#' This function opens a Paradox database file. It will also automatically
#' search for and attach an associated BLOB file (.mb) in a case-insensitive
#' manner if one exists in the same directory.
#'
#' @param path A character string specifying the path to the Paradox (.db) file.
#' @return An external pointer of class 'pxdoc_t' if the file is successfully
#'   opened, or `NULL` if an error occurs.
#' @export
pxlib_open_file <- function(path) {
  # Проверка входных данных
  if (!is.character(path) || length(path) != 1 || is.na(path)) {
    stop("File path must be a single, non-NA character string.")
  }
  
  if (!file.exists(path)) {
    warning("File not found: ", path)
    return(NULL)
  }
  
  # Вызываем C-функцию для открытия основного .db файла
  pxdoc <- .Call("R_pxlib_open_file", path)
  
  # Если основной файл успешно открыт, ищем и подключаем .mb файл
  if (!is.null(pxdoc)) {
    blob_file_path <- find_blob_file(path)
    
    if (!is.null(blob_file_path)) {
      # Если .mb файл найден, вызываем C-функцию для его подключения
      success <- .Call("R_pxlib_set_blob_file", pxdoc, blob_file_path)
      if (!success) {
        warning("Found BLOB file '", basename(blob_file_path), "' but failed to attach it.")
      }
    }
  }
  
  return(pxdoc)
}