#
# File: R/read_paradox.R
#

#' @title Read a Paradox Database File into a Tibble
#'
#' @description
#' A high-level, user-friendly wrapper function that reads an entire Paradox
#' database file (.db) and returns its contents as a tibble.
#'
#' @details
#' This function simplifies the process of reading Paradox files by handling the
#' complete workflow in a single call:
#'
#' 1.  It validates the input path and encoding.
#' 2.  It safely opens a handle to the file using `pxlib_open_file()`.
#' 3.  It ensures the file handle is always closed using `on.exit()`, even if
#'     errors occur during data reading.
#' 4.  It reads the data using `pxlib_get_data()`.
#' 5.  It returns a clean `tibble`.
#'
#' If the specified file does not exist, the function will issue a warning and
#' return an empty tibble.
#'
#' @param path A character string specifying the path to the Paradox (.db) file.
#' @param encoding An optional character string specifying the input encoding of
#'   the data (e.g., "cp866", "cp1252"). If `NULL` (the default), the encoding
#'   is determined from the file header.
#'
#' @return A `tibble` containing the data from the Paradox file.
#'
#' @export
#' @examples
#' # Read the demo database in one step
#' db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
#' if (file.exists(db_path)) {
#'   biolife_data <- read_paradox(db_path)
#'   print(biolife_data)
#' }
read_paradox <- function(path, encoding = NULL) {
  # --- 1. Input Validation ---
  # This function performs its own validation
  if (!is.character(path) || length(path) != 1 || is.na(path)) {
    stop("Argument 'path' must be a single character string.", call. = FALSE)
  }
  if (!is.null(encoding) && (!is.character(encoding) || length(encoding) != 1 || is.na(encoding))) {
    stop("Argument 'encoding' must be NULL or a single character string.", call. = FALSE)
  }
  
  # --- 2. Open File Handle ---
  # We call the lower-level function to open the file.
  pxdoc <- pxlib_open_file(path, encoding = encoding)
  
  # --- 3. Handle File-Not-Found Case ---
  # pxlib_open_file() returns NULL and issues a warning if the file is not found.
  # We check for NULL and return an empty tibble, allowing the test to pass.
  if (is.null(pxdoc)) {
    return(tibble::tibble())
  }
  
  # --- 4. Ensure Cleanup ---
  # This is crucial. `on.exit` guarantees that `pxlib_close_file` is called
  # when the function exits, whether normally or due to an error. This
  # prevents memory leaks from unclosed file handles.
  on.exit(pxlib_close_file(pxdoc), add = TRUE)
  
  # --- 5. Read Data ---
  # If the handle is valid, we proceed to read the data.
  data_tbl <- pxlib_get_data(pxdoc)
  
  # --- 6. Return Result ---
  return(data_tbl)
}