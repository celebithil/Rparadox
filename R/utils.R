# Internal (not exported) function for a case-insensitive search for a .mb file
find_blob_file <- function(db_path) {
  # Get the directory and the filename without the extension
  dir_name <- dirname(db_path)
  base_name <- tools::file_path_sans_ext(basename(db_path))
  
  # Get a list of all files in the directory
  all_files <- list.files(dir_name)
  
  # Create a search pattern: "filename.mb"
  # ^ - start of string, \\. - dot, $ - end of string
  pattern <- paste0("^", base_name, "\\.mb$")
  
  # Search for the file, ignoring case
  matching_files <- grep(pattern, all_files, ignore.case = TRUE, value = TRUE)
  
  if (length(matching_files) > 0) {
    # If multiple files are found (e.g., data.mb and data.MB),
    # take the first one and return the full path to it
    return(file.path(dir_name, matching_files[1]))
  }
  
  # If nothing is found
  return(NULL)
}