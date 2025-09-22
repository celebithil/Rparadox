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
