# Suppress R CMD check notes for dplyr column-name variables and magrittr pipe
utils::globalVariables(c(
  ".",              # magrittr dot placeholder
  "address",        # geocode.R
  "area_method",    # calculate_intersection_overlap_and_save.R
  "ACOG_District",  # map_create_base.R
  "geometry",       # map_create_acog_districts_sf.R / sf column
  "GEOID",          # calculate_intersection_overlap_and_save.R
  "grid_id",        # hrr.R: dplyr column inside mutate
  "group",          # map_acceptance_rate.R: ggplot2 aes
  "intersect_area", # calculate_intersection_overlap_and_save.R
  "lat",            # map_acceptance_rate.R / map_create_base.R
  "long",           # map_acceptance_rate.R
  "n",              # dplyr n() used unquoted
  "name",           # map_create_acog_districts_sf.R
  "physician_count",# hrr.R
  "postal",         # map_create_acog_districts_sf.R
  "rate_pct",       # map_acceptance_rate.R
  "state.name",     # geographic_map.R
  "state.abb"       # geographic_map.R
))
