/**
 * @file interface.c
 * @brief R interface to the pxlib library for reading Paradox database files.
 *
 * This file contains C functions that are callable from R (.Call entry points)
 * to open, read, and close Paradox (.DB) files, including associated .MB BLOB files.
 * It handles the conversion of Paradox data types to their corresponding R SEXP types,
 * ensuring robust and efficient data retrieval. The design relies on creating native
 * R data structures (vectors) for each column and populating them record by record.
 * A key feature is the direct creation of lists (VECSXP) for binary/BLOB columns,
 * which simplifies post-processing on the R side.
 */

#include <R.h>          // Standard R header for C extensions
#include <Rinternals.h> // R SEXP objects and functions
#include <stdlib.h>     // For malloc, free, realloc
#include <string.h>     // For strcmp, strlen, memcpy
#include <iconv.h>      // For re-encoding character strings to UTF-8

#include "paradox.h"    // pxlib main header, contains pxdoc_t, pxval_t, pxfield_t etc.

// Forward declarations for static helper functions.
// These functions are internal to this file and not exposed to R directly.
static void pxdoc_finalizer(SEXP extptr);
static pxdoc_t* check_pxdoc_ptr(SEXP pxdoc_extptr);
static char* re_encode_string_to_utf8(pxdoc_t* pxdoc, const char* input_str);
static SEXP px_to_sexp(pxdoc_t* pxdoc, pxval_t* val, int px_ftype);

/**
 * @brief Finalizer for the pxdoc_t external pointer.
 *
 * This function is registered with R's garbage collector. It is called automatically
 * when the SEXP object wrapping the `pxdoc_t` pointer is no longer reachable.
 * Its purpose is to ensure that `PX_delete()` is called to properly free all
 * resources associated with the pxlib document, preventing memory leaks.
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
    // Clear the external pointer's address to signal that it's no longer valid.
    R_ClearExternalPtr(extptr);
  }
}

/**
 * @brief Explicitly closes a Paradox file and releases associated resources.
 *
 * This function provides a way for the R user to explicitly close a Paradox file
 * and free the memory associated with the `pxdoc_t` object before R's garbage
 * collector finalizes it. It calls `PX_delete()` and clears the external pointer.
 *
 * @param pxdoc_extptr An R external pointer of class 'pxdoc_t' representing an
 * open Paradox database.
 * @return `R_NilValue`, invisibly, indicating success.
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
 * Initiates a connection to a Paradox database file. It allocates a `pxdoc_t`
 * object, opens the specified file, and configures pxlib for UTF-8 target
 * encoding if a codepage is detected.
 *
 * @param filename_sexp An R character string SEXP containing the path to the .DB file.
 * @return An R external pointer of class "pxdoc_t" on success. This pointer is
 * used in subsequent `pxlib` functions. Returns `R_NilValue` on failure.
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
  
  // If a DOS codepage is defined, set pxlib's target encoding to UTF-8
  // to ensure character data is correctly converted.
  if (pxdoc->px_head->px_doscodepage > 0) {
    PX_set_targetencoding(pxdoc, "UTF-8");
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
  
  UNPROTECT(2); // Unprotect pxdoc_extptr and class_attr.
  return pxdoc_extptr;
}

/**
 * @brief Associates a BLOB file (.MB) with an open Paradox database.
 *
 * Paradox databases can store BLOB (Binary Large Object) data in a separate
 * .MB file. This function tells pxlib where to find this associated BLOB file.
 *
 * @param pxdoc_extptr The R external pointer to the open Paradox database.
 * @param blob_filename_sexp An R character string SEXP containing the path to the .MB file.
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
 * @brief Reads all records from an open Paradox file and returns them as an R list of vectors.
 *
 * This is the core data retrieval function. It queries the Paradox file's structure,
 * allocates R vectors of appropriate types for each column, and then iterates through
 * each record to populate them. Column names are set, and special R classes (e.g.,
 * "Date", "POSIXct") are applied where appropriate.
 *
 * A key aspect of the implementation is how BLOBs are handled. Binary Paradox
 * types (BLOB, OLE, etc.) are mapped to a `VECSXP` (an R list), where each element
 * of the list will contain a `RAWSXP` (raw vector) for a single record's binary data.
 * The R-side wrapper function (`pxlib_get_data`) identifies these columns by checking
 * `is.list()` and converts them to `blob` objects. This avoids passing redundant
 * type information between C and R.
 *
 * @param pxdoc_extptr An R external pointer to the open Paradox database.
 * @return An R list (`VECSXP`), where each element is a vector representing a column.
 * The list elements are named after the Paradox field names. Returns `R_NilValue`
 * if the file contains no records.
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
    case pxfBLOb:
    case pxfOLE:
    case pxfGraphic:
    case pxfBytes:
      column = PROTECT(allocVector(VECSXP, num_records));
      break;
      
      // Integer types.
    case pxfShort:
    case pxfLong:
    case pxfAutoInc:
      column = PROTECT(allocVector(INTSXP, num_records));
      break;
      
      // Floating-point types. Dates and times are also stored as doubles.
    case pxfNumber:
    case pxfCurrency:
    case pxfDate:
    case pxfTime:
    case pxfTimestamp:
      column = PROTECT(allocVector(REALSXP, num_records));
      break;
      
      // Logical type.
    case pxfLogical:
      column = PROTECT(allocVector(LGLSXP, num_records));
      break;
      
      // Text types and unhandled types default to character strings.
    case pxfAlpha:
    case pxfMemoBLOb:
    case pxfFmtMemoBLOb:
    case pxfBCD: // BCD is returned as a string by pxlib.
    default:
      column = PROTECT(allocVector(STRSXP, num_records));
      break;
    }
    SET_VECTOR_ELT(data_list, j, column);
    // The column is now part of data_list, which is protected, so we can unprotect the 'column' variable.
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
      // Convert the Paradox value to an R SEXP.
      SEXP r_val = px_to_sexp(pxdoc, record_values[j], fields[j].px_ftype);
      SEXP column = VECTOR_ELT(data_list, j);
      
      // Place the converted value into the correct position in the column vector.
      switch(TYPEOF(column)) {
      case VECSXP: // For BLOBs (list of raw vectors)
        SET_VECTOR_ELT(column, i, r_val);
        break;
      case STRSXP: // For character strings
        SET_STRING_ELT(column, i, Rf_isNull(r_val) ? NA_STRING : r_val);
        break;
      case INTSXP: // For integers
        INTEGER(column)[i] = Rf_isNull(r_val) ? NA_INTEGER : asInteger(r_val);
        break;
      case REALSXP: // For doubles (numeric, date, time)
        REAL(column)[i] = Rf_isNull(r_val) ? NA_REAL : asReal(r_val);
        break;
      case LGLSXP: // For logicals
        LOGICAL(column)[i] = Rf_isNull(r_val) ? NA_LOGICAL : asLogical(r_val);
        break;
      default:
        // This case should not be reached with the current logic.
        Rf_warning("Unhandled R SEXP type for column %d, record %d.", j + 1, i + 1);
      break;
      }
      // Free the memory for the individual Paradox value.
      FREE_PXVAL(pxdoc, record_values[j]);
    }
    // Free the memory for the record's value array.
    pxdoc->free(pxdoc, record_values);
  }
  
  // --- Step 3: Set column names for the data_list ---
  SEXP col_names = PROTECT(allocVector(STRSXP, num_fields));
  for (int j = 0; j < num_fields; j++) {
    // Re-encode field names from the database's codepage to UTF-8 for R.
    char* utf8_fname = re_encode_string_to_utf8(pxdoc, fields[j].px_fname);
    if (utf8_fname != NULL) {
      SET_STRING_ELT(col_names, j, mkCharCE(utf8_fname, CE_UTF8));
      free(utf8_fname);
    } else {
      // Fallback to the original name if re-encoding is not needed or fails.
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
    default:
      // No special class needed for other types.
      break;
    }
  }
  
  UNPROTECT(2); // Unprotect data_list and col_names.
  return data_list;
}

/**
 * @brief Converts a single pxlib value (pxval_t) to a scalar R SEXP.
 *
 * This helper function takes a `pxval_t` structure and converts it into an
 * equivalent scalar R SEXP (e.g., character, integer, double, raw vector).
 * It handles NULL values from Paradox by returning `R_NilValue`.
 *
 * @param pxdoc Pointer to the pxdoc_t object for context (e.g., string encoding).
 * @param val Pointer to the pxval_t structure containing the Paradox value.
 * @param px_ftype The Paradox field type, used for specific conversion logic.
 * @return A scalar R SEXP representing the value. Returns `R_NilValue` for NULLs.
 */
static SEXP px_to_sexp(pxdoc_t* pxdoc, pxval_t* val, int px_ftype) {
  if (val->isnull) {
    return R_NilValue;
  }
  
  switch(px_ftype) {
  // --- Text-like Types ---
  case pxfAlpha:
    if (val->isnull) return R_NilValue;
    return mkCharCE(val->value.str.val, CE_UTF8);
  case pxfBCD: // BCDs are represented as strings by pxlib
    if (val->isnull) return R_NilValue;
    // pxlib can represent BCD NULLs as a string of '?'
    if (strcmp(val->value.str.val, "-??????????????????????????.??????") == 0) {
      return R_NilValue;
    }
    return mkChar(val->value.str.val);
  case pxfMemoBLOb:
  case pxfFmtMemoBLOb:
    if (val->isnull) return R_NilValue;
    // `pxlib` не гарантирует, что строка из Memo-поля будет завершена нулевым символом.
    // Чтобы безопасно передать ее в R, мы создаем временный буфер,
    // копируем в него данные и вручную добавляем нулевой символ в конец.
    int len = val->value.str.len;
    char* safe_buffer = (char*) malloc(len + 1);
    if (safe_buffer == NULL) {
      Rf_warning("Failed to allocate memory for memo field buffer.");
      return R_NilValue;
    }
    
    memcpy(safe_buffer, val->value.str.val, len);
    safe_buffer[len] = '\0'; // Гарантируем наличие нулевого символа
    
    SEXP r_string;
    char* utf8_string = re_encode_string_to_utf8(pxdoc, safe_buffer);
    if (utf8_string != NULL) {
      r_string = mkCharCE(utf8_string, CE_UTF8);
      free(utf8_string);
    } else {
      // Fallback to the original name if re-encoding is not needed or fails.
      r_string = mkChar(safe_buffer);
    }
    
    free(safe_buffer); // Освобождаем временный буфер
    return r_string;
    // --- True Binary Types ---
  case pxfBLOb:
  case pxfGraphic:
  case pxfBytes:
  case pxfOLE:
    // Create an R raw vector (RAWSXP). This will be placed into the list (VECSXP)
    // for the corresponding column.
    if (val->isnull || val->value.str.len == 0) {
      return R_NilValue;
    }
    SEXP raw_vec = PROTECT(allocVector(RAWSXP, val->value.str.len));
    memcpy(RAW(raw_vec), val->value.str.val, val->value.str.len);
    UNPROTECT(1);
    return raw_vec;
    
    // --- Other Types (Numeric, Logical, Date/Time) ---
  case pxfShort:
  case pxfLong:
  case pxfAutoInc:
    return ScalarInteger(val->value.lval);
  case pxfNumber:
  case pxfCurrency:
    return ScalarReal(val->value.dval);
  case pxfLogical:
    return ScalarLogical(val->value.lval);
  case pxfDate:
    // Paradox dates are days since 1899-12-30. R dates are days since 1970-01-01.
    // Conversion: Paradox_Date - R_Epoch_Offset.
    if (val->value.lval <= 0) return R_NilValue; // Handle invalid/null dates.
    return ScalarReal((double)val->value.lval - 719163.0);
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
 * @brief Re-encodes a string from pxlib's internal encoding to UTF-8.
 *
 * This helper function uses `iconv` to convert character strings received from
 * pxlib into UTF-8, which is standard for R. The caller is responsible for
 * freeing the returned `char*` pointer.
 *
 * @param pxdoc Pointer to the pxdoc_t object, which contains the iconv context.
 * @param input_str The input C string to be re-encoded.
 * @return A newly allocated, UTF-8 encoded C string. Returns `NULL` if `iconv`
 * is not used, input is NULL, or memory allocation fails.
 */
static char* re_encode_string_to_utf8(pxdoc_t* pxdoc, const char* input_str) {
  if (pxdoc->targetencoding == NULL || input_str == NULL || input_str[0] == '\0') {
    return NULL;
  }

  size_t input_len = strlen(input_str);
  if (input_len == 0) return NULL;
  
  size_t output_len = input_len * 2 + 1; // Heuristic: allocate 2x input length for safety
  char* output_buf = (char*) malloc(output_len);
  if (output_buf == NULL) {
    Rf_warning("Memory allocation failed for string re-encoding.");
    return NULL;
  }
  
  char* input_ptr = (char*) input_str;
  char* output_ptr = output_buf;
  size_t output_len_remaining = output_len;
  
  // Reset iconv state before each conversion.
  iconv(pxdoc->out_iconvcd, NULL, NULL, NULL, NULL);
  
  size_t result = iconv(pxdoc->out_iconvcd, &input_ptr, &input_len, &output_ptr, &output_len_remaining);
  *output_ptr = '\0'; // Null-terminate the output string.
  
  if (result == (size_t)-1) {
    free(output_buf);
    Rf_warning("String re-encoding with iconv failed.");
    return NULL;
  }
  
  // Optional: reallocate to the exact size to save memory.
  char* final_buf = (char*) realloc(output_buf, strlen(output_buf) + 1);
  return (final_buf == NULL) ? output_buf : final_buf; // Return original if realloc fails
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