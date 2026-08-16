# Package index

## Map templates

Whole maps, assembled.

- [`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md)
  : County access map: choropleth, drive-time coverage, provider dots
- [`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md)
  : Create a Configurable Leaflet Base Map
- [`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md)
  : Create a Leaflet Base Map
- [`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md)
  : Build a collapsible notes panel with a data-vintage list

## Layers and controls

Pieces for maps that are not the template.

- [`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md)
  : Add dissolved coverage surfaces as mutually exclusive base layers
- [`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md)
  : Register a legend as belonging to a base group
- [`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md)
  : Show only the active base layer's legend
- [`mysterymaps_zoom_gated_labels()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_zoom_gated_labels.md)
  : Show point labels only where they are legible
- [`mysterymaps_name_search()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_name_search.md)
  : Add a name-search box over a point layer
- [`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md)
  : Create and Save a Leaflet Dot Map of Physicians

## Scales and labels

Colour classes and the text that goes beside them.

- [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
  : Zero-aware Jenks natural-breaks colour scale
- [`mysterymaps_pluralize()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pluralize.md)
  : Agree a noun with its count
- [`mysterymaps_format_credentials()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_format_credentials.md)
  : Format provider credentials for display after a name
- [`mysterymaps_place_title_case()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_place_title_case.md)
  : Title-case a place name without mangling it

## Static maps

ggplot2 output.

- [`mysterymaps_geographic_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_geographic_map.md)
  : State-Level Choropleth Map of Acceptance Rates

- [`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md)
  : Choropleth map of appointment acceptance rates by US state

- [`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md)
  : Generate honeycomb hex maps for Hospital Referral Regions

- [`mysterymaps_hrr()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr.md)
  : Get Hospital Referral Region Shapefile

- [`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md)
  :

  Create `sf` Polygons for ACOG Districts

- [`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md)
  : Function to create and export a map showing block group overlap with
  isochrones

- [`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md)
  : Create Individual Isochrone Maps and Shapefiles

## Isochrones, geocoding and overlap

- [`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md)
  : Calculate drive-time isochrones for a location
- [`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md)
  : Get isochrones for each point in a dataframe
- [`mysterymaps_calculate_overlap()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_calculate_overlap.md)
  : Calculate intersection overlap and save results to shapefiles.
- [`mysterymaps_gate_provider_coverage()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_gate_provider_coverage.md)
  : Assert every provider falls inside the coverage surface built from
  them
- [`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md)
  : Reject a water mask that is really a state outline
- [`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md)
  : Clear the isochrone memoization cache
- [`mysterymaps_geocode()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_geocode.md)
  : Geocode unique addresses from a file
