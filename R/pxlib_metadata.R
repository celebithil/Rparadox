# Rparadox/R/pxlib_metadata.R

#' @title Get Metadata from a Paradox Database File
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
  # Ensure the input is a valid object created by pxlib_open_file()
  if (!inherits(pxdoc, "pxdoc_t")) {
    stop("Argument 'pxdoc' must be an object of class 'pxdoc_t', obtained from pxlib_open_file().")
  }
  
  # --- 2. Call the C backend ---
  # The C function takes the existing handle and reads metadata.
  # The encoding is already set in the pxdoc object from when it was opened.
  metadata_list <- .Call("R_pxlib_get_metadata", pxdoc)
  
  # --- 3. Get encoding and add it to metadata ---
  # Retrieve the encoding stored in the object attributes and add it to the result.
  db_encoding <- attr(pxdoc, "px_encoding")
  metadata_list$encoding <- db_encoding
  
  # --- 4. Process Fields (if present) ---
  if (!is.null(metadata_list$fields)) {

    # 4.1 Recode field names if necessary
    # Check that the `fields` data frame exists and contains the `name` column
    if ("name" %in% names(metadata_list$fields)) {
      # Use the same common function for recoding
      metadata_list$fields$name <- recode_if_needed(metadata_list$fields$name, db_encoding)
    }

    # 4.2 Map numeric types to friendly names
    # Mapping logic based on Paradox file structure documentation (pxformat.txt)
    px_type_map <- c(
      "1"  = "Alpha",          # 0x01 Fixed-length character strings containing letters, numbers, and symbols; maximum length 255 bytes, padded with nulls.
      "2"  = "Date",           # 0x02 4-byte signed long integer representing days elapsed since January 1, 1 A.D.; valid from 100 to 9999 A.D.
      "3"  = "Short",          # 0x03 16-bit signed integer (2 bytes); range -32,767 to 32,767; used to save disk space for small whole numbers.
      "4"  = "Long",           # 0x04 32-bit signed integer (4 bytes); range -2,147,483,648 to 2,147,483,647; standard integer type in Paradox 5.0+.
      "5"  = "Currency",       # 0x05 Identical to Number (8-byte double), but automatically formatted for currency with 2 display and 6 internal decimal places.
      "6"  = "Number",         # 0x06 8-byte IEEE 754 double-precision floating-point numbers; range -10³⁰⁷ to 10³⁰⁸ with ~15 significant digits.
      "9"  = "Logical",        # 0x09 1-byte boolean field storing TRUE or FALSE values; used for binary state flags.
      "12" = "Memo",           # 0x0C BLOB text field; stores a leader in the.DB file and the rest in the.MB file; size up to 256 MB.
      "13" = "Binary",         # 0x0D BLOB field for arbitrary binary data; primarily stored in the external.MB file; size up to 256 MB.
      "14" = "FmtMemo",        # 0x0E BLOB field for Rich Formatted Text (RTF); includes formatting info.
      "15" = "OLE",            # 0x0F Object Linking and Embedding BLOB; used for embedding external application objects (spreadsheets, documents).
      "16" = "Graphic",        # 0x10 Specialized BLOB type for storing images (BMP, GIF, JPEG, etc.); maps to TGraphicField in Delphi/C++.
      "20" = "Time",           # 0x14 4-byte value representing milliseconds since midnight; represents a specific time within a 24-hour period.
      "21" = "Timestamp",      # 0x15 8-byte float; integer part is the date (days since 1/1/0001) and fractional part is the time as a fraction of a day.
      "22" = "Autoincrement",  # 0x16 4-byte long integer that automatically increments by 1 when a record is added; values are never reused.
      "23" = "BCD",            # 0x17 Binary Coded Decimal; stores numeric data with high precision, supporting up to 32 significant digits.
      "24" = "Bytes"           # 0x18 Short binary data (1-255 bytes) stored entirely within the main.DB file; used for GUIDs or barcodes.
    )

    # Convert raw types to character to ensure safe lookup
    raw_types <- as.character(metadata_list$fields$type)

    # Look up friendly names
    friendly_types <- px_type_map[raw_types]

    # Handle unknown types by keeping the original code
    unknown_mask <- is.na(friendly_types)
    if (any(unknown_mask)) {
      friendly_types[unknown_mask] <- paste0("Unknown (", raw_types[unknown_mask], ")")
    }

    metadata_list$fields$type <- friendly_types
  }
  
  # --- 5. Return the metadata list ---
  return(metadata_list)
}