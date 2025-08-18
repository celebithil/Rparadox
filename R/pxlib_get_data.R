#
# File: pxlib_get_data.R
#
# This file contains the R wrapper function for retrieving data from an open
# Paradox file handle. It serves as a user-friendly interface to the underlying
# C function `R_pxlib_get_data`.
#

#' @title Read Data from a Paradox File
#' @description
#' Retrieves all records from an open Paradox database file and returns them
#' as a tibble.
#'
#' @details
#' This function orchestrates the data retrieval process. It calls a C function
#' (`R_pxlib_get_data`) which reads the raw data into an R list of vectors.
#'
#' A key post-processing step in this R function is the handling of binary
#' (BLOB) columns. The C backend creates list-columns (`VECSXP`) specifically
#' for binary data types. This function identifies these columns by checking
#' `is.list()` and then converts each element into a `blob` object from the
#' `blob` package. This approach is efficient as it relies on the data structure
#' itself rather than separate metadata.
#'
#' It also ensures that columns intended to represent time are correctly
#' formatted using the `hms` package.
#'
#' @param pxdoc An object of class `pxdoc_t`, representing an open Paradox file
#'   connection. This object is obtained from `pxlib_open_file()`.
#'
#' @return A `tibble` containing the data from the Paradox file. Each row
#'   represents a record and each column represents a field. If the file contains
#'   no records, an empty tibble is returned.
#'
#' @importFrom tibble as_tibble tibble
#' @importFrom blob as_blob
#' @importFrom hms as_hms
#' @export
#' @examples
#' \dontrun{
#'   # Assuming 'test.db' is a Paradox file in the working directory
#'   pxdoc <- pxlib_open_file("test.db")
#'   if (!is.null(pxdoc)) {
#'     my_data <- pxlib_get_data(pxdoc)
#'     print(my_data)
#'     pxlib_close_file(pxdoc)
#'   }
#' }
pxlib_get_data <- function(pxdoc) {
  # --- Step 1: Validate Input ---
  # Ensure the provided argument is a valid 'pxdoc_t' object, which acts
  # as a handle to the open file.
  if (!inherits(pxdoc, "pxdoc_t")) {
    stop("Argument 'pxdoc' must be an object of class 'pxdoc_t', obtained from pxlib_open_file().")
  }
  
  # --- Step 2: Call the C Backend to Get Raw Data ---
  # The `.Call` interface invokes the C function "R_pxlib_get_data".
  # This C function reads the entire Paradox table and returns it as a named
  # R list, where each list element is a vector corresponding to a column.
  data_list <- .Call("R_pxlib_get_data", pxdoc)
  
  # --- Step 3: Handle Empty Results ---
  # If the file has no records, the C function returns NULL. Check for this
  # or an empty list and return an empty tibble for consistency.
  if (is.null(data_list) || length(data_list) == 0) {
    return(tibble::tibble())
  }
  
  # --- Step 4: Identify Binary (BLOB) Columns ---
  # The C code is designed to return binary columns as a list of raw vectors (VECSXP).
  # We can therefore identify these columns simply by checking which elements of the
  # main list are themselves lists. This is a clean and robust way to distinguish
  # binary columns without needing extra attributes.
  is_list_col <- sapply(data_list, is.list)
  binary_indices <- which(is_list_col)
  
  # --- Step 5: Convert Binary Columns to 'blob' Objects ---
  # If any binary columns were found, iterate over them and apply the
  # `blob::as_blob` function. This converts the list of raw vectors into a
  # proper 'blob' column type, which is well-supported in the tidyverse.
  if (length(binary_indices) > 0) {
    data_list[binary_indices] <- lapply(data_list[binary_indices], blob::as_blob)
  }
  
  # --- Step 6: Convert the List to a Tibble ---
  # `tibble::as_tibble()` efficiently converts the named list of vectors into a
  # modern data frame (a tibble).
  data_tbl <- tibble::as_tibble(data_list)
  
  # --- Step 7: Final Type Coercion for Time Columns ---
  # While the C code sets the 'hms' class, some environments or R versions might
  # not fully recognize it without an explicit conversion. This loop ensures
  # that any column with the 'hms' class is correctly treated as such.
  time_cols_indices <- which(sapply(data_tbl, inherits, "hms"))
  if (length(time_cols_indices) > 0) {
    for (idx in time_cols_indices) {
      data_tbl[[idx]] <- hms::as_hms(data_tbl[[idx]])
    }
  }
  
  # --- Step 8: Return the Final Tibble ---
  return(data_tbl)
}