# Suppress R CMD check notes for dplyr column-name variables and magrittr pipe
utils::globalVariables(c(
  ".",           # magrittr dot placeholder
  "address",     # geocode.R: dplyr column
  "GEOID",       # calculate_intersection_overlap_and_save.R
  "intersect_area",
  "area_method",
  "state.name",  # geographic_map.R: base datasets
  "state.abb"
))
