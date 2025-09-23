#' Get Metadata from a Paradox Database File
#'
#' @description
#' Retrieves metadata from an open Paradox file handle without reading the
#' entire dataset.
#'
#' @param pxdoc An object of class `pxdoc_t`, representing an open Paradox file
#'   connection, obtained from `pxlib_open_file()`.
#'
#' @return A list containing:
#' \item{num_records}{The total number of records in the database.}
#' \item{num_fields}{The total number of fields (columns).}
#' \item{encoding}{The character encoding specified in the file header (e.g., "CP1251").}
#' \item{fields}{A data frame with details for each field, with names recoded to UTF-8.}
#'
#' @export
#' @examples
#' db_path <- system.file("extdata", "country.db", package = "Rparadox")
#' pxdoc <- pxlib_open_file(db_path)
#' if (!is.null(pxdoc)) {
#'   metadata <- pxlib_metadata(pxdoc)
#'   print(metadata)
#'   pxlib_close_file(pxdoc)
#' }
pxlib_metadata <- function(pxdoc) {
  # --- 1. Input Validation ---
  if (!inherits(pxdoc, "pxdoc_t")) {
    stop("Argument 'pxdoc' must be an object of class 'pxdoc_t', obtained from pxlib_open_file().")
  }
  
  # --- 2. Call the C backend ---
  # The C function takes the existing handle and reads metadata.
  # The encoding is already set in the pxdoc object from when it was opened.
  metadata_list <- .Call("R_pxlib_get_metadata", pxdoc)
  
  # --- 3. Get encoding and add it to metadata ---
  db_encoding <- attr(pxdoc, "px_encoding")
  metadata_list$encoding <- db_encoding
  
  # --- 4. Recode field names in the 'fields' data frame ---
  # Check that the `fields` data frame exists and contains the `name` column
  if (!is.null(metadata_list$fields) && "name" %in% names(metadata_list$fields)) {
    # Use the same common function for recoding
    metadata_list$fields$name <- recode_if_needed(metadata_list$fields$name, db_encoding)
  }
  
  # --- 5. Return the metadata list ---
  return(metadata_list)
}