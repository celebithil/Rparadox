/**
 * @file interface.c
 * @brief R interface to the pxlib library for reading Paradox database files.
 *
 * This file contains C functions that are callable from R (.Call entry points)
 * to open, read, and close Paradox (.DB) files. It handles the conversion of
 * Paradox data types to their corresponding R SEXP types, including character
 * encoding conversion and robust handling of binary (BLOB) data. The design
 * relies on creating native R data structures for each column and populating
 * them record by record.
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Riconv.h>
#include <stdlib.h>     // For malloc, free, realloc
#include <string.h>     // For strcmp, strlen, memcpy
#include "paradox.h"    // pxlib main header, contains pxdoc_t, pxval_t, pxfield_t etc.

// Forward declarations for static helper functions.
static void pxdoc_finalizer(SEXP extptr);
static pxdoc_t* check_pxdoc_ptr(SEXP pxdoc_extptr);
static char* re_encode_string_to_utf8(pxdoc_t* pxdoc, const char* input_str);
static SEXP px_to_sexp(pxdoc_t* pxdoc, pxval_t* val, int px_ftype);

/**
 * @brief Finalizer for the pxdoc_t external pointer.
 *
 * Registered with R's garbage collector, this function ensures that `PX_delete()`
 * is called to properly free all resources associated with the pxlib document,
 * preventing memory leaks when the R object is garbage collected.
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
SEXP pxlib_open_file_c(SEXP filename_sexp, SEXP encoding_sexp) {
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
  
  // --- Encoding Handling Logic ---
  const char* source_encoding_str = NULL;
  char codepage_buffer[30];
  
  // 1. Check for user-provided encoding override.
  if (TYPEOF(encoding_sexp) == STRSXP && LENGTH(encoding_sexp) == 1) {
    source_encoding_str = CHAR(STRING_ELT(encoding_sexp, 0));
  }
  
  // 2. If no override, try to get codepage from file header.
  if (source_encoding_str == NULL && pxdoc->px_head->px_doscodepage > 0) {
    snprintf(codepage_buffer, sizeof(codepage_buffer), "CP%d", pxdoc->px_head->px_doscodepage);
    source_encoding_str = codepage_buffer;
  }
  
  // 3. If a source encoding is determined, set up iconv for UTF-8 conversion.
  if (source_encoding_str != NULL) {
    const char* target_encoding = "UTF-8";
    
    if (pxdoc->out_iconvcd != (Riconv_t)(-1)) {
      Riconv_close(pxdoc->out_iconvcd);
    }
    pxdoc->out_iconvcd = Riconv_open(target_encoding, source_encoding_str);
    
    if (pxdoc->out_iconvcd == (Riconv_t)(-1)) {
      Rf_warning("Failed to set up encoding conversion from '%s' to '%s'.",
                 source_encoding_str, target_encoding);
    } else {
      if (pxdoc->targetencoding) pxdoc->free(pxdoc, pxdoc->targetencoding);
      pxdoc->targetencoding = PX_strdup(pxdoc, target_encoding);
    }
  }
  // --- End of Encoding Logic ---
  
  SEXP pxdoc_extptr = PROTECT(R_MakeExternalPtr(pxdoc, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(pxdoc_extptr, pxdoc_finalizer, TRUE);
  
  SEXP class_attr = PROTECT(allocVector(STRSXP, 2));
  SET_STRING_ELT(class_attr, 0, mkChar("pxdoc_t"));
  SET_STRING_ELT(class_attr, 1, mkChar("externalptr"));
  setAttrib(pxdoc_extptr, R_ClassSymbol, class_attr);
  
  UNPROTECT(2);
  return pxdoc_extptr;
}

/**
 * @brief Associates a BLOB file (.MB) with an open Paradox database.
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
  
  SEXP data_list = PROTECT(allocVector(VECSXP, num_fields));
  
  // --- Step 1: Allocate R vectors (columns) based on Paradox field types ---
  for (int j = 0; j < num_fields; j++) {
    SEXP column;
    switch(fields[j].px_ftype) {
    case pxfBLOb: case pxfOLE: case pxfGraphic: case pxfBytes:
      column = PROTECT(allocVector(VECSXP, num_records)); break;
    case pxfShort: case pxfLong: case pxfAutoInc:
      column = PROTECT(allocVector(INTSXP, num_records)); break;
    case pxfNumber: case pxfCurrency: case pxfDate: case pxfTime: case pxfTimestamp:
      column = PROTECT(allocVector(REALSXP, num_records)); break;
    case pxfLogical:
      column = PROTECT(allocVector(LGLSXP, num_records)); break;
    case pxfAlpha: case pxfMemoBLOb: case pxfFmtMemoBLOb: case pxfBCD: default:
      column = PROTECT(allocVector(STRSXP, num_records)); break;
    }
    SET_VECTOR_ELT(data_list, j, column);
    UNPROTECT(1);
  }
  
  // --- Step 2: Populate columns record by record ---
  for (int i = 0; i < num_records; i++) {
    pxval_t** record_values = PX_retrieve_record(pxdoc, i);
    if (record_values == NULL) {
      UNPROTECT(1); // Unprotect data_list before erroring.
      Rf_error("Failed to retrieve record #%d.", i + 1);
    }
    
    for (int j = 0; j < num_fields; j++) {
      SEXP r_val = px_to_sexp(pxdoc, record_values[j], fields[j].px_ftype);
      SEXP column = VECTOR_ELT(data_list, j);
      
      switch(TYPEOF(column)) {
      case VECSXP:  SET_VECTOR_ELT(column, i, r_val); break;
      case STRSXP:  SET_STRING_ELT(column, i, Rf_isNull(r_val) ? NA_STRING : r_val); break;
      case INTSXP:  INTEGER(column)[i] = Rf_isNull(r_val) ? NA_INTEGER : asInteger(r_val); break;
      case REALSXP: REAL(column)[i] = Rf_isNull(r_val) ? NA_REAL : asReal(r_val); break;
      case LGLSXP:  LOGICAL(column)[i] = Rf_isNull(r_val) ? NA_LOGICAL : asLogical(r_val); break;
      default:      Rf_warning("Unhandled R SEXP type for column %d, record %d.", j + 1, i + 1); break;
      }
      FREE_PXVAL(pxdoc, record_values[j]);
    }
    pxdoc->free(pxdoc, record_values);
  }
  
  // --- Step 3: Set column names for the data_list ---
  SEXP col_names = PROTECT(allocVector(STRSXP, num_fields));
  for (int j = 0; j < num_fields; j++) {
    char* utf8_fname = re_encode_string_to_utf8(pxdoc, fields[j].px_fname);
    if (utf8_fname != NULL) {
      SET_STRING_ELT(col_names, j, mkCharCE(utf8_fname, CE_UTF8));
      free(utf8_fname);
    } else {
      SET_STRING_ELT(col_names, j, mkChar(fields[j].px_fname));
    }
  }
  setAttrib(data_list, R_NamesSymbol, col_names);
  
  // --- Step 4: Set special R class attributes for dates and times ---
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
  
  switch(px_ftype) {
  case pxfAlpha:
    return mkCharCE(val->value.str.val, CE_UTF8);
    
  case pxfBCD:
    if (strcmp(val->value.str.val, "-??????????????????????????.??????") == 0) {
      return R_NilValue;
    }
    return mkChar(val->value.str.val);
    
  case pxfMemoBLOb:
  case pxfFmtMemoBLOb:
  {
    if (val->value.str.val == NULL) return R_NilValue;
    
    // pxlib does not guarantee null-termination for memo fields. To pass them
    // safely to C string functions, we create a temporary, null-terminated buffer.
    int len = val->value.str.len;
    char* safe_buffer = (char*) malloc(len + 1);
    if (safe_buffer == NULL) {
      Rf_warning("Failed to allocate memory for memo field buffer.");
      return R_NilValue;
    }
    
    memcpy(safe_buffer, val->value.str.val, len);
    safe_buffer[len] = '\0'; // Ensure null-termination
    
    // Attempt to re-encode the string to UTF-8
    SEXP r_string;
    char* utf8_string = re_encode_string_to_utf8(pxdoc, safe_buffer);
    if (utf8_string != NULL) {
      r_string = mkCharCE(utf8_string, CE_UTF8);
      free(utf8_string);
    } else {
      // Fallback: create a native-encoded string if re-encoding fails or is not needed.
      r_string = mkChar(safe_buffer);
    }
    
    free(safe_buffer); // Free the temporary buffer
    return r_string;
  }
    
  case pxfBLOb: case pxfGraphic: case pxfBytes: case pxfOLE:
    if (val->value.str.len == 0) {
      return R_NilValue;
    }
    SEXP raw_vec = PROTECT(allocVector(RAWSXP, val->value.str.len));
    memcpy(RAW(raw_vec), val->value.str.val, val->value.str.len);
    UNPROTECT(1);
    return raw_vec;
    
  case pxfShort: case pxfLong: case pxfAutoInc:
    return ScalarInteger(val->value.lval);
    
  case pxfNumber: case pxfCurrency:
    return ScalarReal(val->value.dval);
    
  case pxfLogical:
    return ScalarLogical(val->value.lval);
    
  case pxfDate:
    if (val->value.lval <= 0) return R_NilValue;
    return ScalarReal((double)val->value.lval - 719163.0);
    
  case pxfTime:
    if (val->value.lval < 0) return R_NilValue;
    return ScalarReal((double)val->value.lval / 1000.0);
    
  case pxfTimestamp: {
    double paradox_seconds = val->value.dval / 1000.0;
    if (val->value.dval == 0.0 || paradox_seconds < 0) return R_NilValue;
    return ScalarReal(paradox_seconds - (719163.0 * 86400.0));
  }
    
  default:
    Rf_warning("Unhandled Paradox field type encountered: %d. Returning R_NilValue.", px_ftype);
    return R_NilValue;
  }
}

/**
 * @brief Re-encodes a string from the file's encoding to UTF-8 using iconv.
 *
 * The caller is responsible for freeing the returned `char*` pointer.
 *
 * @param pxdoc Pointer to the pxdoc_t object, which contains the iconv context.
 * @param input_str The input C string to be re-encoded.
 * @return A newly allocated, UTF-8 encoded C string, or `NULL` on failure or if
 * re-encoding is not configured.
 */
static char* re_encode_string_to_utf8(pxdoc_t* pxdoc, const char* input_str) {
  if (pxdoc->targetencoding == NULL || input_str == NULL || input_str[0] == '\0') {
    return NULL;
  }
  
  size_t input_len = strlen(input_str);
  if (input_len == 0) return NULL;
  
  // Heuristic: allocate 2x input length for safety during conversion (e.g., ASCII to UTF-16).
  size_t output_len = input_len * 2 + 1;
  char* output_buf = (char*) malloc(output_len);
  if (output_buf == NULL) {
    Rf_warning("Memory allocation failed for string re-encoding.");
    return NULL;
  }
  
  const char* input_ptr = (const char*) input_str;
  char* output_ptr = output_buf;
  size_t output_len_remaining = output_len;
  
  // Reset iconv state before each conversion.
  Riconv(pxdoc->out_iconvcd, NULL, NULL, NULL, NULL);
  
  size_t result = Riconv(pxdoc->out_iconvcd, &input_ptr, &input_len, &output_ptr, &output_len_remaining);
  *output_ptr = '\0'; // Null-terminate the output string.
  
  if (result == (size_t)-1) {
    free(output_buf);
    // This warning can be noisy if some strings fail, so it's commented out.
    // Rf_warning("String re-encoding with iconv failed.");
    return NULL;
  }
  
  // Reallocate to the exact size to save memory.
  char* final_buf = (char*) realloc(output_buf, strlen(output_buf) + 1);
  return (final_buf == NULL) ? output_buf : final_buf; // Return original if realloc fails
}

/**
 * @brief Validates that a SEXP is a valid, non-NULL external pointer to pxdoc_t.
 *
 * Throws an R error if the pointer is invalid.
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