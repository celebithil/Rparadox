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
