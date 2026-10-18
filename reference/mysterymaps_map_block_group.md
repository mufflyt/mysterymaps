# Function to create and export a map showing block group overlap with isochrones

This function creates a map that displays block groups and their overlap
with isochrones. The map is exported as an HTML file and a PNG image.

## Usage

``` r
mysterymaps_map_block_group(
  bg_data,
  isochrones_data,
  output_dir = "figures/",
  k = 6,
  digits = 2,
  zero_color = "#e0e0e0",
  na_color = "#ffffff"
)
```

## Arguments

- bg_data:

  A SpatialPolygonsDataFrame representing block group data.

- isochrones_data:

  A SpatialPolygonsDataFrame representing isochrone data.

- output_dir:

  Directory path for exporting the map files. Default is "figures/".

- k:

  `integer(1)`: target number of Jenks classes for the positive
  (nonzero) overlap values, passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md).
  Default `6`.

- digits:

  `integer(1)`: decimal places in the legend's overlap labels. Default
  `2` (overlap is a proportion, typically fractional).

- zero_color, na_color:

  Colours for a block group with zero measured overlap and one whose
  overlap is unmeasurable (a degenerate polygon area – see Details),
  respectively. Defaults match
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
  own.

## Value

`invisible(NULL)`. Side effects: writes the block group overlap map as
an HTML file and a PNG image to `output_dir`.

## Details

`bg_data$overlap` carries two different kinds of absence that a plain
continuous
[`leaflet::colorNumeric()`](https://rstudio.github.io/leaflet/reference/colorNumeric.html)
scale (the original implementation) could not tell apart.
[`mysterymaps_calculate_overlap()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_calculate_overlap.md)
coalesces a block group's intersection area to `0` when it does not
intersect any isochrone at all – a measured zero, and the coverage gap
this map exists to show – but leaves `overlap` as `NA` when the block
group's own area is degenerate (zero or negative, an invalid polygon).
Putting a measured zero at the lightest end of the same purple gradient
as a 2% overlap reads as "barely covered" rather than "not covered at
all". This function now classifies `overlap` with
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
instead: a measured zero gets `zero_color`, a degenerate-area `NA` gets
`na_color`, and the positive values are Jenks-classified.

## See also

Other mapping:
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md),
[`mysterymaps_access_choropleth_map_multi()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map_multi.md),
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_aggregate_values_to_polygons()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_aggregate_values_to_polygons.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
[`mysterymaps_catchment_redundancy_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_catchment_redundancy_map.md),
[`mysterymaps_choropleth_point_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_choropleth_point_map.md),
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_count_points_in_polygons()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_count_points_in_polygons.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_flow_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_flow_map.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_pathway_small_multiples_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pathway_small_multiples_map.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
# Create and export the map with the default output directory
mysterymaps_map_block_group(block_groups, isochrones_joined_map)

# Create and export the map with a custom output directory
mysterymaps_map_block_group(block_groups, isochrones_joined_map, "custom_output/")
}
```
