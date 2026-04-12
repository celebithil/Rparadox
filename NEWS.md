# Rparadox 0.3.0

## Major changes
* Complete rewrite of the C backend: removed all write functionality,
  making the library read-only. Removed dead write-code
  including `PX_create_file`, `PX_put_record`, `PX_update_record`,
  `PX_delete_record`, `PX_pack`, and all encoding write functions.
* Removed GSF (GNOME Structured File) and memprof support.
* Removed `paradox-gsf.h`, `paradox-mp.h`, `px_encode.c/h`,
  `px_memprof.c`.

## Bug fixes
* Fixed uninitialized memory access in `get_px_head()` that caused a
  segfault with `-O2 + LTO` when opening encrypted files.
* Added missing `#include "paradox.h"` in 5 `.c` files (`paradox.c`,
  `px_io.c`, `px_head.c`, `px_misc.c`, `px_memory.c`).
* Fixed buffer overflow in `px_passwd_checksum()` for passwords > 255 chars.
* `find_blob_file()` now normalises paths with forward slashes to ensure
  consistent `expect_equal()` comparisons on Windows UCRT.
* Fixed 238 Valgrind errors (uninitialised reads) in `get_px_head()` and
  `_px_get_data_blob()`: replaced `ret < 0` checks with exact-size
  comparisons (`ret != sizeof(...)`) after `read()` calls to detect
  short/truncated reads from corrupted files.

## Documentation
* README.Rmd: removed all runnable code examples, now links to vignette.
* Vignette: now contains all usage examples previously in README (magick
  plot, encrypted files, encoding override, advanced workflow).

## New tests
* `test-encryption.R`: Full encryption workflow tests.
* `test-find_blob_file.R`: BLOB file auto-detection tests.
* `test-recode_if_needed.R`: Encoding conversion tests.
* `test-px_close_file.R`: Error handling for file close operations.
* `test-corrupted_file.R`: Handling of non-Paradox files.
* `test-missing_blob.R`: Behavior when BLOB file is missing.
* `test-password_edge_cases.R`: Password validation edge cases.
* `test-encoding_edge_cases.R`: Invalid encoding handling.
* `test-path_edge_cases.R`: Path validation edge cases.

# Rparadox 0.2.2

## Bug fixes

* Fixed rchk warnings: "Suspicious call (two or more unprotected arguments) to Rf_setAttrib" in pxlib_get_data_c() (interface.c:341, 347)

# Rparadox 0.2.1

## Bug fixes and improvements

* Fixed rchk warnings:
  - Suspicious call (two or more unprotected arguments) to Rf_setAttrib at pxlib_get_data_c Rparadox/src/interface.c:317
  - Suspicious call (two or more unprotected arguments) to Rf_setAttrib at pxlib_get_data_c Rparadox/src/interface.c:326
* Optimized performance using local static variables for constant caching
  - Reduction in allocVector() calls for repeated file reads
  - Caches class vectors: c("pxdoc_t", "externalptr"), c("hms", "difftime"), c("POSIXct", "POSIXt")
  - Caches name vectors for metadata structure
* Added download statistics badges to README (total, weekly, daily)


# Rparadox 0.2.0

## New features

* **Encryption Support**: Added the `password` argument to `read_paradox()`. Users can now read password-protected Paradox files (.db) and associated BLOB/Memo files (.MB).
* **Enhanced Metadata**: `pxlib_metadata()` now returns human-readable field types (e.g., "Alpha", "Date", "Memo") instead of raw integer codes.
* **Encoding info**: Metadata now explicitly reports the detected encoding.

## Bug fixes and improvements (Core C library)

* **Major x64 compatibility update**: Integrated patches for the underlying `pxlib` engine to ensure stability on 64-bit systems.
    * Replaced `long int` with `int32_t` in data reading functions to ensure correct data width on 64-bit systems (Windows/Linux).
    * Fixed pointer arithmetic logic in `src/px_head.c` to prevent undefined behavior and header corruption.
    * Updated `writeproc` signature to `ssize_t` for POSIX compliance.


# Rparadox 0.1.5

## CRAN check Note fix

* remove incorrect CRAN link in Readme.


# Rparadox 0.1.4

## Cosmetic fixes

* Add misplaced picture link at Readme.Rmd.
* Add pxlib URL to DESCRIPTION file.
* Fix NEWS format.

# Rparadox 0.1.3

## New features

* Added a high-level `read_paradox()` function for a simple, one-step workflow to read Paradox files. This is now the recommended function for most users.
* Added a `pxlib_metadata()` function to retrieve database metadata (number of records, field details, encoding) without reading the entire dataset.

## Bug fixes and improvements

* The architecture for handling character encodings has been completely refactored.
  The C-level code now returns raw character data, and all conversion to UTF-8 is handled reliably in R via the `stringi` package(ICU) instead of Riconv.
  This fixes test failures on CRAN and improves robustness for files on various operating systems.
* Added `stringi` to package imports.
* Added extensive tests for the new `read_paradox()` and `pxlib_metadata()` functions.
* Documentation and examples have been updated to reflect the new functions and recommended workflow.

# Rparadox 0.1.2

## Bug fixes and improvements

* Fixed CRAN check issues on Debian: package no longer attempts to open
  Paradox files in write mode (`rb+` → `rb`).
  This ensures full compliance with CRAN Policy (no writes outside of
  temporary directories).
* Fixed heap-buffer-overflow in `PX_get_data_alpha` (discovered with
  AddressSanitizer). Now the function safely respects field length and
  prevents out-of-bounds reads for fixed-length strings without `\0`.
* Improved handling of invalid/null Paradox dates with an upper bound
  filter for extreme values.
* Added proper `.gitignore` entries for `cran-comments.md` and
  `CRAN-SUBMISSION`.
* Updated README with CRAN badges and installation instructions.
* Expanded test coverage: re-enabled datasets with German, English and
  Russian encodings, including CP866.

# Rparadox 0.1.1

## Bug fixes and improvements

* Fixed CRAN feedback:
  - Removed unnecessary `\dontrun{}` in examples.  
    Added fast, self-contained examples using demo files  
    (`biolife.db`, `of_cp866.db` in `inst/extdata`).  
  - Ensured no commented-out example code remains.
  - All examples now run in < 5s and without commented-out code.

* Fixed vignette build issue on CRAN check servers:
  - Explicitly added `rmarkdown` in `VignetteBuilder`  
    to avoid failures when running with `--no-suggests`.  

* Memory management improvements:
  - Fixed memory leaks in src/interface.c when reading BLOB fields.
  - Examples and vignette now run cleanly under Valgrind.

* Verified that all examples run in < 5 sec and vignettes build  
  successfully across test environments.


# Rparadox 0.1.0

* Initial CRAN submission.
