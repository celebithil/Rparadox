# Raradox/pxlib_open_file.R

#' @title Open a Paradox Database File
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
#' ## Encryption Handling
#' 
#' This function automatically handles encrypted Paradox files:
#' 
#' 1. If the file is **not encrypted**, the `password` parameter is ignored
#' 2. If the file **is encrypted** and `password` is provided, it validates the password
#' 3. If the file **is encrypted** and `password` is `NULL`, an error is thrown
#' 4. If the provided password is **incorrect**, an error is thrown
#' 
#' When a file is successfully opened with the correct password, all subsequent
#' operations (like `pxlib_get_data()`) will automatically decrypt the data.
#' 
#' ## Resource Management
#' 
#' It's important to always close the file handle using `pxlib_close_file()`
#' when you're done to prevent resource leaks. Using `on.exit()` is recommended:
#' 
#' ```r
#' px_doc <- pxlib_open_file("myfile.db", password = "secret")
#' on.exit(pxlib_close_file(px_doc), add = TRUE)
#' # ... work with the file ...
#' ```
#'
#' @param path A character string specifying the path to the Paradox (.db) file.
#' @param encoding An optional character string specifying the source encoding
#'   (e.g., "cp866", "cp1252"). If `NULL` (default), encoding is determined
#'   from the file header.
#' @param password An optional character string specifying the password for
#'   encrypted files. If the file is encrypted and no password is provided,
#'   an error will be thrown. Default is `NULL`.
#'
#' @return An external pointer of class `"pxdoc_t"` representing the opened
#'   Paradox file, or `NULL` if the file could not be opened (with a warning).
#'
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
#'
#' # Example 3: Open an encrypted file with password
#' db_path3 <- system.file("extdata", "country_encrypted.db", package = "Rparadox")
#' px_doc <- pxlib_open_file(db_path3, password = "rparadox")
#' data <- pxlib_get_data(px_doc)
#' pxlib_close_file(px_doc)
#'
pxlib_open_file <- function(path, encoding = NULL, password = NULL) {
  # --- 1. Input Validation ---
  if (!is.character(path) || length(path) != 1 || is.na(path)) {
    stop("Argument 'path' must be a single character string.", call. = FALSE)
  }
  
  if (!is.null(encoding) && (!is.character(encoding) || length(encoding) != 1 || is.na(encoding))) {
    stop("Argument 'encoding' must be NULL or a single character string.", call. = FALSE)
  }
  
  if (!is.null(password) && (!is.character(password) || length(password) != 1 || is.na(password))) {
    stop("Argument 'password' must be a single character string.", call. = FALSE)
  }
  
  # --- 2. Check File Existence ---
  if (!file.exists(path)) {
    warning("File not found: ", path, call. = FALSE)
    return(NULL)
  }

  # --- 3. Call C backend to open the main .db file ---
  pxdoc <- .Call("R_pxlib_open_file", path, password)
  
  # --- 4. Encoding determination and preservation ---
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
