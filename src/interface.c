/**
 * @file interface.c
 * @brief R interface to the pxlib C library for reading Paradox database files.
 *
 * This file acts as a bridge between the R language and the underlying `pxlib`
 * C library. It contains the `.Call` entry points that are exposed to R.
 *
 * The main responsibilities of this interface are:
 * - Managing the lifecycle of the `pxdoc_t` object via R's external pointers.
 * - Translating R arguments (like file paths) into C types.
 * - Orchestrating calls to `pxlib` functions to read data.
 * - Converting the C-level data retrieved from `pxlib` into appropriate
 * R objects (SEXP), including handling type mapping, memory management,
 * and character encoding.
 */

#include <stdlib.h>  // For malloc, free, realloc
#include <string.h>  // For strcmp, strlen, memcpy
#include "paradox.h" // pxlib main header, contains pxdoc_t, pxval_t, pxfield_t etc.

// Forward declarations for static helper functions.
// These functions are internal to this file and not exposed to R directly.
static void pxdoc_finalizer(SEXP extptr);
static pxdoc_t* check_pxdoc_ptr(SEXP pxdoc_extptr);
static SEXP px_to_sexp(pxdoc_t* pxdoc, pxval_t* val, int px_ftype);

/**
 * @brief Finalizer for the pxdoc_t external pointer.
 *
 * Registered with R's garbage collector, this function ensures that `PX_delete()`
 * is called to properly free all resources associated with the pxlib document.
 * This prevents memory leaks when the R object is garbage collected or the
 * R session ends.
 *
 * @param extptr The R external pointer SEXP that holds the `pxdoc_t` address.
 */
static void pxdoc_finalizer(SEXP extptr) {
  if (TYPEOF(extptr) != EXTPTRSXP) {
    return;
  }
  pxdoc_t* pxdoc = (pxdoc_t*) R_ExternalPtrAddr(extptr);
  
  if (pxdoc != NULL) {
    PX_delete(pxdoc);
    // Clear the external pointer's address. This prevents dangling pointers
    // and signals that the handle is no longer valid.
    R_ClearExternalPtr(extptr);
  }
}

/**
 * @brief Explicitly closes a Paradox file and releases associated resources.
 *
 * Allows the R user to explicitly close a Paradox file before R's garbage
 * collector finalizes it. It calls `PX_delete()` and clears the external pointer.
 *
 * @param pxdoc_extptr An R external pointer of class 'pxdoc_t'.
 * @return `R_NilValue`, invisibly.
 */
SEXP pxlib_close_file_c(SEXP pxdoc_extptr) {
  pxdoc_t* pxdoc = check_pxdoc_ptr(pxdoc_extptr);
  
  if (pxdoc != NULL) {
    PX_delete(pxdoc);
    R_ClearExternalPtr(pxdoc_extptr);
  }
  return R_NilValue;
}


/**
 * @brief Opens a Paradox file and returns an external pointer to the pxdoc_t struct.
 *
 * Initiates a connection to a Paradox database. It allows overriding the source
 * character encoding if specified by the user.
 *
 * @param filename_sexp An R character string SEXP containing the path to the .DB file.
 * @param encoding_sexp An R character string SEXP for the source encoding, or R_NilValue.
 * @return An R external pointer of class "pxdoc_t" on success, or `R_NilValue` on failure.
 */
SEXP pxlib_open_file_c(SEXP filename_sexp) {
  if (TYPEOF(filename_sexp) != STRSXP || LENGTH(filename_sexp) != 1 || STRING_ELT(filename_sexp, 0) == NA_STRING) {
    Rf_error("Filename must be a single, non-NA character string.");
  }
  const char *filename = CHAR(STRING_ELT(filename_sexp, 0));
  
  pxdoc_t* pxdoc = PX_new();
  if (pxdoc == NULL) {
    Rf_error("Failed to allocate new pxdoc_t object via PX_new().");
  }
  
  if (PX_open_file(pxdoc, filename) != 0) {
    PX_delete(pxdoc);
    Rf_warning("pxlib failed to open file: %s", filename);
    return R_NilValue;
  }
  
  // Create an R external pointer to hold the pxdoc_t object.
  // PROTECT ensures the SEXP is not garbage collected prematurely.
  SEXP pxdoc_extptr = PROTECT(R_MakeExternalPtr(pxdoc, R_NilValue, R_NilValue));
  // Register the finalizer to ensure resources are freed when R garbage collects the object.
  R_RegisterCFinalizerEx(pxdoc_extptr, pxdoc_finalizer, TRUE);
  // Set the S3 class for method dispatch in R.
  SEXP class_attr = PROTECT(allocVector(STRSXP, 2));
  SET_STRING_ELT(class_attr, 0, mkChar("pxdoc_t"));
  SET_STRING_ELT(class_attr, 1, mkChar("externalptr"));
  setAttrib(pxdoc_extptr, R_ClassSymbol, class_attr);
  // Release the objects from GC protection as they are now safe.
  // Unprotect pxdoc_extptr and class_attr.
  UNPROTECT(2);
  return pxdoc_extptr;
}

/**
 * @brief Extracts the code page from the Paradox file header.
 *
 * This function is called from R to retrieve the original encoding,
 * which will then be used by function in R.
 *
 * @param pxdoc_extptr External R pointer to an open Paradox database.
 * @return R string (SEXP) with the code page name (e.g., "CP866")
 * or R_NilValue if the code page is not found.
 */
SEXP pxlib_get_codepage_c(SEXP pxdoc_extptr) {
  pxdoc_t* pxdoc = check_pxdoc_ptr(pxdoc_extptr);
  int codepage = pxdoc->px_head->px_doscodepage;
  
  if (codepage > 0) {
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "CP%d", codepage);
    return mkString(buffer);
  }
  
  return R_NilValue;
}
/**
 * @brief Associates a BLOB file (.MB) with an open Paradox database.
 *
 * Paradox databases can store BLOB (Binary Large Object) data in a separate
 * .MB file. This function tells pxlib where to find this associated BLOB file.
 *
 * @param pxdoc_extptr The R external pointer to the open Paradox database.
 * @param blob_filename_sexp An R character string SEXP with the path to the .MB file.
 * @return A logical SEXP (`TRUE` on success, `FALSE` on failure).
 */
SEXP pxlib_set_blob_file_c(SEXP pxdoc_extptr, SEXP blob_filename_sexp) {
  pxdoc_t* pxdoc = check_pxdoc_ptr(pxdoc_extptr);
  
  if (TYPEOF(blob_filename_sexp) != STRSXP || LENGTH(blob_filename_sexp) != 1 || STRING_ELT(blob_filename_sexp, 0) == NA_STRING) {
    Rf_error("BLOB filename must be a single, non-NA character string.");
  }
  const char* blob_filename = CHAR(STRING_ELT(blob_filename_sexp, 0));
  
  if (PX_set_blob_file(pxdoc, blob_filename) == 0) {
    return ScalarLogical(TRUE);
  } else {
    Rf_warning("pxlib failed to set BLOB file: %s", blob_filename);
    return ScalarLogical(FALSE);
  }
}

/**
 * @brief Reads all records from an open Paradox file into an R list of vectors.
 *
 * This is the core data retrieval function. It allocates R vectors for each column,
 * iterates through records to populate them, and sets column names and classes.
 *
 * @param pxdoc_extptr An R external pointer to the open Paradox database.
 * @return An R list (`VECSXP`), with named elements representing columns.
 * Returns `R_NilValue` if the file is empty.
 */
SEXP pxlib_get_data_c(SEXP pxdoc_extptr) {
  pxdoc_t* pxdoc = check_pxdoc_ptr(pxdoc_extptr);
  
  int num_records = PX_get_num_records(pxdoc);
  int num_fields = PX_get_num_fields(pxdoc);
  
  if (num_records <= 0) {
    return R_NilValue;
  }
  
  pxfield_t* fields = PX_get_fields(pxdoc);
  if (fields == NULL) {
    Rf_error("Could not retrieve field definitions from Paradox file.");
  }
  
  // data_list will hold all the column vectors. It must be protected from GC.
  SEXP data_list = PROTECT(allocVector(VECSXP, num_fields));
  
  // --- Step 1: Allocate R vectors (columns) based on Paradox field types ---
  for (int j = 0; j < num_fields; j++) {
    SEXP column;
    // A switch statement determines the appropriate R vector type (SEXP) for each Paradox field.
    switch(fields[j].px_ftype) {
    // Binary types are mapped to a VECSXP (list), which will hold raw vectors.
    case pxfBLOb: case pxfOLE: case pxfGraphic: case pxfBytes:
      column = PROTECT(allocVector(VECSXP, num_records)); break;
    // Integer types.
    case pxfShort: case pxfLong: case pxfAutoInc:
      column = PROTECT(allocVector(INTSXP, num_records)); break;
    // Floating-point types. Dates and times are also stored as doubles.
    case pxfNumber: case pxfCurrency: case pxfDate: case pxfTime: case pxfTimestamp:
      column = PROTECT(allocVector(REALSXP, num_records)); break;
    // Logical type.
    case pxfLogical:
      column = PROTECT(allocVector(LGLSXP, num_records)); break;
    // Text types and unhandled types default to character strings.
    // BCD is returned as a string by pxlib.
    case pxfAlpha: case pxfMemoBLOb: case pxfFmtMemoBLOb: case pxfBCD: default:
      column = PROTECT(allocVector(STRSXP, num_records)); break;
    }
    SET_VECTOR_ELT(data_list, j, column);
    // The column is now part of data_list, which is protected, so we can unprotect the 'column' variable.
    UNPROTECT(1);
  }
  
  // --- Step 2: Iterate through records and populate the R column vectors. ---
  for (int i = 0; i < num_records; i++) {
    pxval_t** record_values = PX_retrieve_record(pxdoc, i);
    if (record_values == NULL) {
      UNPROTECT(1); // Unprotect data_list before erroring.
      Rf_error("Failed to retrieve record #%d.", i + 1);
    }
    
    for (int j = 0; j < num_fields; j++) {
      // Convert the Paradox value to an R SEXP.
      SEXP r_val = px_to_sexp(pxdoc, record_values[j], fields[j].px_ftype);
      SEXP column = VECTOR_ELT(data_list, j);
      // Place the converted value into the correct position in the column vector.
      switch(TYPEOF(column)) {
      // For BLOBs (list of raw vectors)
      case VECSXP:  SET_VECTOR_ELT(column, i, r_val); break;
      // For character strings
      case STRSXP:  SET_STRING_ELT(column, i, Rf_isNull(r_val) ? NA_STRING : r_val); break;
      // For integers
      case INTSXP:  INTEGER(column)[i] = Rf_isNull(r_val) ? NA_INTEGER : asInteger(r_val); break;
      // For doubles (numeric, date, time)
      case REALSXP: REAL(column)[i] = Rf_isNull(r_val) ? NA_REAL : asReal(r_val); break;
      // For logicals
      case LGLSXP:  LOGICAL(column)[i] = Rf_isNull(r_val) ? NA_LOGICAL : asLogical(r_val); break;
      // This case should not be reached with the current logic.
      default:      Rf_warning("Unhandled R SEXP type for column %d, record %d.", j + 1, i + 1); break;
      }
      // pxlib requires manual memory management for retrieved values.
      FREE_PXVAL(pxdoc, record_values[j]);
    }
    // Free the memory for the record's value array.
    pxdoc->free(pxdoc, record_values);
  }
  
  // --- Step 3: Set column names for the data_list ---
  SEXP col_names = PROTECT(allocVector(STRSXP, num_fields));
  for (int j = 0; j < num_fields; j++) {
    SET_STRING_ELT(col_names, j, mkChar(fields[j].px_fname));
  }
  // No special class needed for other types.
  setAttrib(data_list, R_NamesSymbol, col_names);
  
  // --- Step 4: Set special S3 classes for date/time types for proper R dispatch. ---
  for (int j = 0; j < num_fields; j++) {
    SEXP column = VECTOR_ELT(data_list, j);
    switch(fields[j].px_ftype) {
    case pxfDate:
      setAttrib(column, R_ClassSymbol, mkString("Date"));
      break;
    case pxfTime: {
      SEXP time_class = PROTECT(allocVector(STRSXP, 2));
      SET_STRING_ELT(time_class, 0, mkChar("hms"));
      SET_STRING_ELT(time_class, 1, mkChar("difftime"));
      setAttrib(column, R_ClassSymbol, time_class);
      UNPROTECT(1);
      setAttrib(column, install("units"), mkString("secs"));
      break;
    }
    case pxfTimestamp: {
      SEXP ts_class = PROTECT(allocVector(STRSXP, 2));
      SET_STRING_ELT(ts_class, 0, mkChar("POSIXct"));
      SET_STRING_ELT(ts_class, 1, mkChar("POSIXt"));
      setAttrib(column, R_ClassSymbol, ts_class);
      UNPROTECT(1);
      setAttrib(column, install("tzone"), mkString("UTC"));
      break;
    }
    default: break;
    }
  }
  
  UNPROTECT(2); // Unprotect data_list and col_names.
  return data_list;
}

/**
 * @brief Converts a single pxlib value (pxval_t) to a scalar R SEXP.
 *
 * @param pxdoc Pointer to the pxdoc_t object for context (e.g., encoding).
 * @param val Pointer to the pxval_t structure containing the Paradox value.
 * @param px_ftype The Paradox field type.
 * @return A scalar R SEXP representing the value. Returns `R_NilValue` for NULLs.
 */
static SEXP px_to_sexp(pxdoc_t* pxdoc, pxval_t* val, int px_ftype) {
  if (val->isnull) {
    return R_NilValue;
  }
  
  SEXP r_string;
  
  switch(px_ftype) {
  // --- Text-like Types ---
  case pxfAlpha:
    if (val->value.str.val == NULL) return NA_STRING;
    SEXP r_string = mkChar(val->value.str.val);
    pxdoc->free(pxdoc, val->value.str.val);
    return r_string;
  case pxfBCD:
    if (strcmp(val->value.str.val, "-??????????????????????????.??????") == 0) {
      //Free the memory even if the value is null-like.
      pxdoc->free(pxdoc, val->value.str.val);
      return R_NilValue;
    }
    r_string = mkChar(val->value.str.val);
    pxdoc->free(pxdoc, val->value.str.val);
    return r_string;
  case pxfMemoBLOb:
  case pxfFmtMemoBLOb:
    if (val->value.str.val == NULL) return R_NilValue;
    // pxlib does not guarantee null-termination for memo fields
    SEXP memo_string = mkCharLen(val->value.str.val, val->value.str.len);
    pxdoc->free(pxdoc, val->value.str.val);
    return memo_string;
  // --- True Binary Types ---
  case pxfBytes: {
    r_string = mkCharLen(val->value.str.val, val->value.str.len);
    pxdoc->free(pxdoc, val->value.str.val);
    return r_string;
  }
  case pxfBLOb: case pxfGraphic: case pxfOLE:
    if (val->value.str.len == 0) {
      if(val->value.str.val != NULL) {
        pxdoc->free(pxdoc, val->value.str.val);
      }
      return R_NilValue;
    }
    SEXP raw_vec = PROTECT(allocVector(RAWSXP, val->value.str.len));
    memcpy(RAW(raw_vec), val->value.str.val, val->value.str.len);
    UNPROTECT(1);
    pxdoc->free(pxdoc, val->value.str.val);
    return raw_vec;
  // --- Other Types (Numeric, Logical, Date/Time) ---
  case pxfShort: case pxfLong: case pxfAutoInc:
    return ScalarInteger(val->value.lval);
  case pxfNumber: case pxfCurrency:
    return ScalarReal(val->value.dval);
  case pxfLogical:
    return ScalarLogical(val->value.lval);
  case pxfDate: {
    long date_val = val->value.lval;
    // Paradox dates are days since 1899-12-30. R dates are days since 1970-01-01.
    // Conversion: Paradox_Date - R_Epoch_Offset.
    // Handle invalid/null dates. A valid date should not be <= 0.
    // Also, very large positive values often represent blank/null dates in Paradox files.
    // A value like 3,000,000 corresponds to a date far in the future (around year 10100),
    // making it a safe upper bound to filter out garbage values.
    static const long PARADOX_DATE_UPPER_BOUND = 3000000L;
    if (date_val <= 0 || date_val > PARADOX_DATE_UPPER_BOUND) {
      return R_NilValue;
    }
    return ScalarReal((double)date_val - 719163.0);
  }
  case pxfTime:
    // Paradox times are milliseconds since midnight. R 'hms' uses seconds.
    if (val->value.lval < 0) return R_NilValue;
    return ScalarReal((double)val->value.lval / 1000.0);
  case pxfTimestamp: {
    // Paradox timestamps are milliseconds since 1899-12-30. R POSIXct are seconds since 1970-01-01 UTC.
    // Conversion: Paradox_Date - R_Epoch_Offset.
    // R_Epoch_Offset = days between 1899-12-30 and 1970-01-01 = 719163 days.
    double paradox_seconds = val->value.dval / 1000.0;
    if (val->value.dval == 0.0 || paradox_seconds < 0) return R_NilValue; // Handle invalid/null timestamps.
    return ScalarReal(paradox_seconds - (719163.0 * 86400.0));
  }
    
  default:
    Rf_warning("Unhandled Paradox field type encountered: %d. Returning R_NilValue.", px_ftype);
    return R_NilValue;
  }
}

/**
 * @brief Validates that a SEXP is a valid, non-NULL external pointer to pxdoc_t.
 *
 * This helper function is used by other C functions to ensure that the `pxdoc_extptr`
 * argument from R is a valid, active connection. It throws an R error if not.
 *
 * @param pxdoc_extptr The R external pointer SEXP to be validated.
 * @return A `pxdoc_t*` pointer if validation passes.
 */
static pxdoc_t* check_pxdoc_ptr(SEXP pxdoc_extptr) {
  if (TYPEOF(pxdoc_extptr) != EXTPTRSXP || R_ExternalPtrAddr(pxdoc_extptr) == NULL) {
    Rf_error("The Paradox file connection is closed or invalid. "
               "Please use a valid object from pxlib_open_file().");
  }
  return (pxdoc_t*) R_ExternalPtrAddr(pxdoc_extptr);
}

/* In file: src/interface.c */

/**
 * @brief Retrieves metadata from an open Paradox file handle.
 *
 * This function is the C backend for pxlib_metadata(). It takes an existing,
 * open pxdoc_t object and extracts metadata without re-opening the file.
 *
 * @param pxdoc_extptr An R external pointer to the open Paradox database.
 * @return A named R list containing metadata.
 */
SEXP pxlib_get_metadata_c(SEXP pxdoc_extptr) {
  pxdoc_t* pxdoc = check_pxdoc_ptr(pxdoc_extptr);
  
  int num_fields = PX_get_num_fields(pxdoc);
  pxfield_t* fields = PX_get_fields(pxdoc);
  
  if (fields == NULL && num_fields > 0) {
    Rf_error("Could not retrieve field definitions from Paradox file.");
  }
  
  // --- Build the Result List for R ---
  SEXP result_list = PROTECT(allocVector(VECSXP, 3));
  SEXP result_names = PROTECT(allocVector(STRSXP, 3));
  SET_STRING_ELT(result_names, 0, mkChar("num_records"));
  SET_STRING_ELT(result_names, 1, mkChar("num_fields"));
  SET_STRING_ELT(result_names, 2, mkChar("fields"));
  setAttrib(result_list, R_NamesSymbol, result_names);
  
  SET_VECTOR_ELT(result_list, 0, ScalarInteger(PX_get_num_records(pxdoc)));
  SET_VECTOR_ELT(result_list, 1, ScalarInteger(num_fields));
  
  // --- Create and Populate the 'fields' DataFrame ---
  SEXP fields_df = PROTECT(allocVector(VECSXP, 3));
  SEXP fields_df_names = PROTECT(allocVector(STRSXP, 3));
  SET_STRING_ELT(fields_df_names, 0, mkChar("name"));
  SET_STRING_ELT(fields_df_names, 1, mkChar("type"));
  SET_STRING_ELT(fields_df_names, 2, mkChar("size"));
  setAttrib(fields_df, R_NamesSymbol, fields_df_names);
  
  SEXP name_col = PROTECT(allocVector(STRSXP, num_fields));
  SEXP type_col = PROTECT(allocVector(INTSXP, num_fields));
  SEXP size_col = PROTECT(allocVector(INTSXP, num_fields));
  
  for (int i = 0; i < num_fields; i++) {
    SET_STRING_ELT(name_col, i, mkChar(fields[i].px_fname));
    INTEGER(type_col)[i] = fields[i].px_ftype;
    INTEGER(size_col)[i] = fields[i].px_flen;
  }
  
  SET_VECTOR_ELT(fields_df, 0, name_col);
  SET_VECTOR_ELT(fields_df, 1, type_col);
  SET_VECTOR_ELT(fields_df, 2, size_col);
  
  SEXP row_names = PROTECT(allocVector(INTSXP, 2));
  INTEGER(row_names)[0] = NA_INTEGER;
  INTEGER(row_names)[1] = -num_fields;
  setAttrib(fields_df, R_RowNamesSymbol, row_names);
  setAttrib(fields_df, R_ClassSymbol, mkString("data.frame"));
  
  SET_VECTOR_ELT(result_list, 2, fields_df);
  
  UNPROTECT(8);
  
  return result_list;
}
