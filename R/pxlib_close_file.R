# Rparadox/R/pxlib_close_file.R

#' Close a Paradox database file
#'
#' This function explicitly closes a Paradox database file associated with
#' a `pxdoc_t` external pointer and releases its resources.
#'
#' @param pxdoc An external pointer of class 'pxdoc_t' obtained from `pxlib_open_file()`.
#' @return Invisible `NULL`.
#' @export
#' @useDynLib Rparadox, .registration = TRUE
pxlib_close_file <- function(pxdoc) {
  #  Check for valid external pointer and correct class.
  if (!inherits(pxdoc, "pxdoc_t")) {
    stop("Invalid argument: 'pxdoc' must be an external pointer of class 'pxdoc_t'.")
  }
  
  # Call the C function to close the file.
  invisible(.Call("R_pxlib_close_file", pxdoc))
}