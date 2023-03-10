#===============================================================================
# Banquo v1.0
#===============================================================================
# README
# This script merges platemaps and repeat sizing data. 
# Input the platemap as an Excel spreadsheet with a series of vertically stacked
# 8x12 tables with plate name above in column 1.
# Input the caginstability.ml output.
# The plate name prefix must match in the platemap and sample file names.
# by Mike Flower, 10/5/23


#===============================================================================
# Useful functions
#===============================================================================
#rm(list = ls())
#.rs.restartR()
choose_directory = function(caption = 'Select directory') {
  if (exists('utils::choose.dir')) {
    choose.dir(caption = caption) 
  } else {
    tk_choose.dir(caption = caption)
  }
}

#===============================================================================
# Load programs
#===============================================================================
packages <- c("readxl", "xlsx", "dplyr", "tidyr", "tidyverse", "janitor", "tibble",
              "stringr", "data.table", "tcltk", "svDialogs")
install.packages(setdiff(packages, rownames(installed.packages())))
lapply(packages, library, character.only = TRUE)

#===============================================================================
# Variables
#===============================================================================
filepath_platemap = tk_choose.files(caption = "Select platemap file (Excel format)")
filepath_data = tk_choose.files(caption = "Select caginstability file (csv format)")
platename_prefix <- dlgInput(message = "Enter plate name prefix", default = "plate")$res
out_directory <- choose_directory(caption = "Select output folder")

#===============================================================================
# Import platemap spreadsheet
#===============================================================================
platemap <- read_excel(filepath_platemap, col_names = F) %>%
  janitor::clean_names()

# Add blank columns if <12 columns
if(ncol(platemap) < 12) {
  platemap[,(ncol(platemap)+1):12] <- NA
  platemap <- platemap %>%
    janitor::clean_names()
}

#===============================================================================
# Extract platemaps into a list
#===============================================================================
plate_starts <- which(grepl(platename_prefix, platemap$x1, ignore.case = T))
names(plate_starts) <- platemap$x1[plate_starts]
platemap_long <- lapply(names(plate_starts), function(p) {
  start <- plate_starts[[p]]
  names <- data.frame(platemap %>% slice((start+1):(start+8)))
  colnames(names) <- c(1:12)
  rownames(names) <-  LETTERS[1:8]
  names <- tibble::rownames_to_column(names, "row")
  names <- names %>%
    pivot_longer(!row, names_to = "col", values_to = "name") %>%
    mutate(well = paste0(row, str_pad(col, 2, pad = "0")))
  names$plate <- p
  names <- names %>%
    relocate(plate, well, row, col)
  return(names)
  
})
platemap_long <- rbindlist(platemap_long)

#===============================================================================
# Import data
#===============================================================================
data <- read.csv(file = file.path(filepath_data), header = T, stringsAsFactor = FALSE) %>%
  mutate(well = substr(sample, 1, 3),
         plate = paste0(platename_prefix, sub("_.*", "", sub(paste0(".*", platename_prefix), "", sample)))) %>%
  relocate(plate, well)

#===============================================================================
# Merge platemap and data
#===============================================================================
data_annotated <- platemap_long %>%
  left_join(data, by = c("plate", "well"))

#===============================================================================
# Summarise
#===============================================================================
summary <- data.frame(
  data_annotated %>%
  group_by(name) %>%
  dplyr::summarise_if(is.numeric, 
               list(mean = mean, sd = sd),
               na.rm = T) %>%
  left_join(data_annotated %>%
              group_by(name) %>%
              dplyr::summarise(n = n()),
            by = "name") %>%
  relocate(name, n) %>%
  mutate_all(~ifelse(is.nan(.), NA, .))
)

#===============================================================================
# Output results
#===============================================================================
write.xlsx(data_annotated,
           file = paste0(out_directory, "/banquo.xlsx"),
           sheetName = "data",
           row.names = F)
write.xlsx(summary,
           file = paste0(out_directory, "/banquo.xlsx"),
           sheetName = "summary",
           append = T,
           row.names = F)


