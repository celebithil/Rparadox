
# Rparadox: A Modern Interface for Reading Paradox Databases in R

**Rparadox** provides a simple and efficient way to read data from
Paradox database files (`.db`) directly into R as modern `tibble` data
frames. It uses the underlying `pxlib` C library to handle the low-level
file format details and provides a clean, user-friendly R interface.

This package is designed to “just work” for the most common use case:
extracting the full dataset from a Paradox table, including its
associated BLOB/memo file (`.mb`).

------------------------------------------------------------------------

## Features

- **Direct Reading:** Reads Paradox `.db` files without needing database
  drivers or external software.
- **Tibble Output:** Returns data in the `tibble` format, which is fully
  compatible with the Tidyverse ecosystem.
- **Automatic BLOB Handling:** Automatically detects, attaches, and
  reads data from associated memo/BLOB (`.mb`) files.
- **Character Encoding Control:** Automatically handles character
  encoding conversion to UTF-8 and allows the user to manually override
  the source encoding for files with incorrect headers.
- **Type Conversion:** Correctly maps Paradox data types to their
  corresponding R types, including `Date`, `Time` (`hms`), `Timestamp`
  (`POSIXct`), `Logical`, `Integer`, `Numeric`, and binary `blob`
  objects.

------------------------------------------------------------------------

## Installation

You can install the development version of Rparadox from GitHub using
the `devtools` package.

``` r
# install.packages("devtools")
devtools::install_github("celebithil/Rparadox")
```

------------------------------------------------------------------------

## Usage

Using the package involves two main functions: `pxlib_open_file()` to
open a connection to the database and `pxlib_get_data()` to read the
data. The connection is then closed with `pxlib_close_file()`.

### Basic Example

This example reads a simple Paradox file included with the package. The
code below is executed live when this README is generated, ensuring the
output is always accurate.

``` r
# 1. Load the package
library(Rparadox)

# 2. Get the path to an example database
db_path <- system.file("extdata", "biolife.db", package = "Rparadox")

# 3. Open the file
# This automatically finds and attaches the 'biolife.mb' BLOB file.
pxdoc <- pxlib_open_file(db_path)

# 4. Read the data into a tibble
if (!is.null(pxdoc)) {
  biolife_data <- pxlib_get_data(pxdoc)

  # 5. Always close the file when you're done
  pxlib_close_file(pxdoc)
  
  # 6. View the data
  print(biolife_data)
}
#> # A tibble: 28 × 8
#>    `Species No` Category      Common_Name          `Species Name`             `Length (cm)` Length_In Notes                                                                                           Graphic
#>           <dbl> <chr>         <chr>                <chr>                              <dbl>     <dbl> <chr>                                                                                            <blob>
#>  1        90020 Triggerfish   Clown Triggerfish    Ballistoides conspicillum             50     19.7  "Also known as the big spotted triggerfish.  Inhabits outer reef areas and feeds upon c… <raw 38.88 kB>
#>  2        90030 Snapper       Red Emperor          Lutjanus sebae                        60     23.6  "Called seaperch in Australia.  Inhabits the areas around lagoon coral reefs and sandy … <raw 38.88 kB>
#>  3        90050 Wrasse        Giant Maori Wrasse   Cheilinus undulatus                  229     90.2  "This is the largest of all the wrasse.  It is found in dense reef areas, feeding on a … <raw 38.88 kB>
#>  4        90070 Angelfish     Blue Angelfish       Pomacanthus nauarchus                 30     11.8  "Habitat is around boulders, caves, coral ledges and crevices in shallow waters.  Swims… <raw 38.88 kB>
#>  5        90080 Cod           Lunartail Rockcod    Variola louti                         80     31.5  "Also known as the coronation trout.  It is found around coral reefs from shallow to ve… <raw 38.88 kB>
#>  6        90090 Scorpionfish  Firefish             Pterois volitans                      38     15.0  "Also known as the turkeyfish.  Inhabits reef caves and crevices.  The firefish is usua… <raw 38.88 kB>
#>  7        90100 Butterflyfish Ornate Butterflyfish Chaetodon Ornatissimus                19      7.48 "Normally seen in pairs around dense coral areas from very shallow to moderate depths. … <raw 38.88 kB>
#>  8        90110 Shark         Swell Shark          Cephaloscyllium ventriosum           102     40.2  "Inhabits shallow reef caves and crevices and kelp beds along the coast and offshore is… <raw 38.88 kB>
#>  9        90120 Ray           Bat Ray              Myliobatis californica                56     22.0  "Also know as the grinder ray because of its flat grinding teeth used to crush its meal… <raw 38.88 kB>
#> 10        90130 Eel           California Moray     Gymnothorax mordax                   150     59.1  "This fish hides in a shallow-water lair with just its head protruding during the day. … <raw 38.88 kB>
#> # ℹ 18 more rows
```

### Handling Incorrect Character Encoding

If you have a legacy file where the encoding is specified incorrectly in
the header (e.g., it says ASCII but is actually CP866), you can manually
override it using the `encoding` parameter.

``` r
# This tells the package to interpret the source data as CP866
pxdoc <- pxlib_open_file("path/to/your/file.db", encoding = "cp866")

# The rest of the process is the same
data <- pxlib_get_data(pxdoc)
pxlib_close_file(pxdoc)
```

This ensures that all text fields are correctly converted to UTF-8 in
the final `tibble`.
