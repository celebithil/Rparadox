# Rparadox/R/pxlib_open_file.R

#' Open a Paradox Database File
#'
#' @description
#' Opens a Paradox database (.db) file and prepares it for reading. This function
#' serves as the entry point for interacting with a Paradox database.
#'
#' @details
#' This function initializes a connection to a Paradox file via the underlying C library.
#' It automatically performs two key setup tasks:
#' 1.  **Encoding Override:** It allows the user to specify the character encoding of the
#'     source file via the `encoding` parameter. This is crucial for legacy files
#'     where the encoding stored in the header may be incorrect. If `encoding` is
#'     `NULL`, the function will attempt to use the codepage from the file header.
#' 2.  **BLOB File Attachment:** It automatically searches for an associated BLOB file
#'     (with a `.mb` extension, case-insensitively) in the same directory and,
#'     if found, attaches it to the database handle.
#'
#' @param path A character string specifying the path to the Paradox (.db) file.
#' @param encoding An optional character string specifying the input encoding of
#'   the data (e.g., "cp866", "cp1252"). If `NULL` (the default), the encoding
#'   is determined from the file header.
#' @return An external pointer of class 'pxdoc_t' if the file is successfully
#'   opened, or `NULL` if an error occurs (e.g., file not found).
#' @export
#' @examples
#' # Example 1: Open a bundled demo file (biolife.db)
#' db_path <- system.file("extdata", "biolife.db", package = "Rparadox")
#' pxdoc <- pxlib_open_file(db_path)
#' if (!is.null(pxdoc)) {
#'   # normally you'd read data here
#'   pxlib_close_file(pxdoc)
#' }
#'
#' # Example 2: Open a file with overridden encoding (of_cp866.db)
#' db_path2 <- system.file("extdata", "of_cp866.db", package = "Rparadox")
#' pxdoc2 <- pxlib_open_file(db_path2, encoding = "cp866")
#' if (!is.null(pxdoc2)) {
#'   # read some data ...
#'   pxlib_close_file(pxdoc2)
#' }
pxlib_open_file <- function(path, encoding = NULL) {
  # --- 1. Input Validation ---
  if (!is.character(path) || length(path) != 1 || is.na(path)) {
    stop("File path must be a single, non-NA character string.")
  }
  if (!is.null(encoding) && (!is.character(encoding) || length(encoding) != 1 || is.na(encoding))) {
    stop("Encoding must be NULL or a single, non-NA character string.")
  }
  if (!file.exists(path)) {
    warning("File not found: ", path)
    return(NULL)
  }
  
  # --- 2. Call C backend to open the main .db file ---
  pxdoc <- .Call("R_pxlib_open_file", path)
  
  # --- 3. Encoding determination and preservation ---
  if (is.null(pxdoc)) {
    return(pxdoc)
  }
  
  # Use user-specified encoding if provided, otherwise get codepage from file header via C function
  db_encoding <- if (!is.null(encoding)) {
    encoding
  } else {
    .Call("R_pxlib_get_codepage", pxdoc)
  }
  
  # Store determined encoding as pointer attribute for later use by pxlib_get_data()
  if (!is.null(db_encoding)) {
    attr(pxdoc, "px_encoding") <- db_encoding
  }
  
  # Auto-detect and attach associated .mb (BLOB) file
  blob_file_path <- find_blob_file(path)
  # `find_blob_file` is an internal utility to find the .mb file case-insensitively.
  if (!is.null(blob_file_path)) {
    # If a blob file is found, call the C function to attach it.
    success <- .Call("R_pxlib_set_blob_file", pxdoc, blob_file_path)
    if (!success) {
      warning("Found BLOB file '", basename(blob_file_path), "' but failed to attach it.")
    }
  }
  
  return(pxdoc)
}