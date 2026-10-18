# Generate honeycomb hex maps for Hospital Referral Regions

Joins physician point data to HRR polygons, computes per-HRR physician
counts, and renders a honeycomb choropleth of the contiguous US with
Alaska, Hawaii, and Puerto Rico as inset maps. The figure is saved as
both `.tiff` and `.png` to `output_dir`.

## Usage

``` r
mysterymaps_hrr_maps(
  physician_sf,
  trait_map = "all",
  honey_map = "all",
  output_dir = NULL,
  dpi = 600,
  width = 7,
  height = 5,
  min_count = 2L,
  k = 6,
  zero_color = "#e0e0e0",
  na_color = "#ffffff"
)
```

## Arguments

- physician_sf:

  An `sf` object with one row per physician. Must have a `geometry`
  column of POINT geometries; CRS is auto-transformed to EPSG:4326 if
  needed.

- trait_map:

  Character scalar used as a label in the output filename (e.g. `"all"`,
  `"neurotology"`). No validation; used as-is.

- honey_map:

  Character scalar used as a secondary label in the output filename
  (e.g. `"all"`). No validation; used as-is.

- output_dir:

  Directory where generated figures are written. Defaults to a
  session-specific folder inside
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- dpi:

  Integer. Raster resolution in DPI for the saved figure. Default `600`.

- width:

  Numeric. Figure width in inches. Default `7`.

- height:

  Numeric. Figure height in inches. Default `5`.

- min_count:

  Integer. Cells holding fewer than this many providers are coloured as
  suppressed (`na_color`) rather than drawn with their true count.
  Default `2L`, the long-standing behaviour: a cell with exactly one
  provider is small-cell-suppressed rather than potentially identifying.
  A cell with *zero* providers is a different, measured finding and is
  never suppressed by this argument – see Details.

- k:

  Integer. Target number of Jenks classes for the positive
  (at-or-above-`min_count`) cell counts, passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md).
  Default `6`.

- zero_color, na_color:

  Colours for a cell with a measured zero count and a
  small-cell-suppressed cell, respectively. Defaults match
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
  own.

## Value

Invisibly returns a `grob` object (from
[`gridExtra::arrangeGrob`](https://rdrr.io/pkg/gridExtra/man/arrangeGrob.html))
containing the arranged multi-panel map. Side effects: writes two files
to `output_dir` - `<trait_map>_<honey_map>_honey.tiff` and
`<trait_map>_<honey_map>_honey.png`.

## Details

Earlier versions of this function called
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md),
which drops every cell below `min_count` – including genuine zero-count
cells – so a region with no providers at all had no hexagon drawn rather
than one visibly shaded as zero. That is the same "zero is a category,
not an absence" problem this package's other choropleth builders have
been fixed for one at a time; this function was the one
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md)
and
[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md)
were originally extracted from, and had not itself been updated to use
either.

This function now calls the internal full-grid counter (every cell in
`usa`, zero-count ones included) and classifies the result with
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
instead of a continuous
[`scale_fill_viridis_c()`](https://ggplot2.tidyverse.org/reference/scale_viridis.html):
a true zero gets `zero_color` and its own legend entry, a cell below
`min_count` is suppressed to `na_color` with a "Suppressed" legend entry
(a measurement that exists but is not separately reportable, not an
unmeasured cell – the two are different claims, the same distinction
[`mysterymaps_hex_bin_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_rate.md)
makes for a zero denominator), and cells at or above `min_count` are
Jenks-classified. The same scale – computed once, before the
contiguous/Alaska/Hawaii/ Puerto Rico split – colours every panel, so
the legend shown on the main map is valid for the insets too.

## See also

[`mysterymaps_hrr()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr.md)
to obtain the HRR `sf` object;
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md)

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
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_pathway_small_multiples_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pathway_small_multiples_map.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
mysterymaps_hrr_maps(physician_sf)
}
```
