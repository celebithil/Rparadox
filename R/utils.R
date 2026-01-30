# Rparadox/R/utils.R

#' @title Find Case-Insensitive Associated BLOB File
#'
#' @description
#' An internal helper function that searches for a Paradox BLOB file (.mb)
#' associated with the specified database file (.db). The search is performed
#' in the same directory as the .db file and is case-insensitive,
#' allowing it to find files with extensions like `.mb`, `.MB`, etc.
#'
#' @details
#' The function extracts the directory path and base filename (without extension)
#' from the provided .db file path. It then creates a regular expression pattern
#' to search for files with the same base name but with the `.mb` extension.
#' If multiple matches are found (e.g., `data.mb` and `data.MB`),
#' the function returns the path to the first matching file.
#'
#' @param db_path Full path to the main Paradox database file (.db).
#'
#' @return
#' A character string containing the full path to the found `.mb` file,
#' or `NULL` if no such file is found.
#'
#' @noRd
find_blob_file <- function(db_path) {
  # Extract directory name and base filename without extension
  dir_name <- dirname(db_path)
  base_name <- tools::file_path_sans_ext(basename(db_path))
  
  # Get list of all files in the directory
  all_files <- list.files(dir_name)
  
  # Create search pattern: "filename.mb"
  # ^ - start of string, \\. - literal dot, $ - end of string
  pattern <- paste0("^", base_name, "\\.mb$")
  
  # Find files matching pattern (case-insensitive)
  matching_files <- grep(pattern, all_files, ignore.case = TRUE, value = TRUE)
  
  if (length(matching_files) > 0) {
    # If multiple files found (e.g., data.mb and data.MB),
    # take the first one and return its full path
    return(file.path(dir_name, matching_files[1]))
  }
  
  # Return NULL if no matches found
  return(NULL)
}

#' @title Recode a character vector if an encoding is provided
#'
#' @description
#' Safe wrapper around stringi::stri_encode() that leaves non-character
#' vectors untouched and preserves NA values.
#'
#' @param char_vector character vector to recode (or other); if not character, returned unchanged
#' @param encoding character(1) source encoding (e.g. "cp866", "CP1251"). If NULL or empty,
#'                 the vector is returned unchanged.
#' @return Vector recoded to UTF-8 (or original input if not character or encoding is not specified)
#' @noRd
recode_if_needed <- function(char_vector, encoding) {
  # If encoding is not specified, nothing to do
  if (is.null(encoding) || !nzchar(encoding)) {
    return(char_vector)
  }
  
  # Only operate on character vectors
  if (!is.character(char_vector)) {
    return(char_vector)
  }
  
  # Handle NA values: recode only non-NA elements
  na_mask <- is.na(char_vector)
  if (all(na_mask)) return(char_vector)
  
  # Use stringi for reliable recoding; recode only non-NA entries
  char_vector[!na_mask] <- stringi::stri_encode(char_vector[!na_mask], from = encoding, to = "UTF-8")
  char_vector
}
