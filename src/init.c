#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // Required for `NULL` in some contexts
#include <R_ext/Rdynload.h> // Required for R_init_packagename, R_CallMethodDef, R_registerRoutines, R_useDynamicSymbols

/*
 * The following functions are declared in src/interface.c
 * and are exposed to R via .Call.
 */
extern SEXP pxlib_open_file_c(SEXP filename_sexp, SEXP password_sexp);
extern SEXP pxlib_close_file_c(SEXP pxdoc_extptr);
extern SEXP pxlib_get_data_c(SEXP pxdoc_extptr);
extern SEXP pxlib_set_blob_file_c(SEXP pxdoc_extptr, SEXP blob_filename_sexp);
extern SEXP pxlib_get_codepage_c(SEXP pxdoc_extptr);
extern SEXP pxlib_get_metadata_c(SEXP pxdoc_extptr);

// Define the R_CallMethodDef structure to register C functions
static const R_CallMethodDef CallEntries[] = {
  {"R_pxlib_open_file", (DL_FUNC) &pxlib_open_file_c, 2},   // "R_pxlib_open_file" is the name R will use for .Call()
  {"R_pxlib_close_file", (DL_FUNC) &pxlib_close_file_c, 1}, // "R_pxlib_close_file" is the name R will use for .Call()
  {"R_pxlib_get_data", (DL_FUNC) &pxlib_get_data_c, 1},
  {"R_pxlib_set_blob_file", (DL_FUNC) &pxlib_set_blob_file_c, 2},
  {"R_pxlib_get_codepage", (DL_FUNC) &pxlib_get_codepage_c, 1},
  {"R_pxlib_get_metadata", (DL_FUNC) &pxlib_get_metadata_c, 1},
  {NULL, NULL, 0} // Sentinel for the end of the array
};

// Package initialization function.
// This function is automatically called by R when the package is loaded.
void R_init_Rparadox(DllInfo *dll)
{
  // Register the .Call entry points
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  // Prevent searching for symbols in the global environment
  R_useDynamicSymbols(dll, FALSE);
}
