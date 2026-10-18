# Small-multiple dot map, one panel per pathway

Facets a physician dot map by a grouping column – typically a
certification or training pathway – so each pathway's geographic
footprint is visible on its own panel instead of overplotted in one
colour-coded map. Optionally adds a combined "All Pathways Combined"
panel first, for a baseline readers can compare the per-pathway panels
against.

## Usage

``` r
mysterymaps_pathway_small_multiples_map(
  points,
  basemap,
  pathway_var,
  pathway_labels = NULL,
  include_combined_panel = TRUE,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  palette = NULL,
  point_size = 1.6,
  point_alpha = 0.9,
  crs = 5070,
  jitter_miles = 1.5,
  jitter_seed = 42,
  ncol = NULL
)
```

## Arguments

- points:

  `sf` POINT layer, one row per physician.

- basemap:

  `sf` polygon layer to draw beneath the points in every panel.

- pathway_var:

  `character(1)`: column in `points` identifying the pathway.

- pathway_labels:

  Optional named character vector recoding raw `pathway_var` values to
  full-word facet and legend labels. `NULL` uses the raw values as-is.

- include_combined_panel:

  `logical(1)`: add an "All Pathways Combined" panel containing every
  point. Default `TRUE`.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- palette:

  Optional named colour vector for `pathway_var` (after `pathway_labels`
  recoding), e.g. `c("Urology" = "#009E73")`. `NULL` uses a hue scale.

- point_size, point_alpha:

  Point aesthetics.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

- jitter_miles, jitter_seed:

  Passed to
  [`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md).
  Defaults `1.5` and `42`.

- ncol:

  Number of facet columns. `NULL` lets
  [`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  choose.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

`pathway_var`'s raw values become the facet titles verbatim, which makes
any abbreviation in the source data (`"OBGYN"`, `"ABU"`) land directly
on the figure. Pass `pathway_labels`, a named character vector mapping
raw values to full words (e.g.
`c(OBGYN = "Obstetrics and Gynecology", ABU = "Urology")`), to recode
them before faceting; this function does not expand abbreviations on its
own.

Jitter uses
[`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md)
with the same deterministic, under-2-mile default as
[`mysterymaps_physician_dot_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_physician_dot_map.md),
applied once before faceting so a physician's dot sits at the same
jittered position in every panel it appears in.

Points are coloured by pathway (the same grouping that drives the
facets), using
[`ggplot2::scale_color_hue()`](https://ggplot2.tidyverse.org/reference/scale_hue.html)
unless `palette` is supplied. Every per-pathway panel is then visually
uniform, as expected – but the "All Pathways Combined" panel keeps each
point's own pathway colour rather than flattening to one colour, so it
works as a real overview rather than a silhouette of the dataset.

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
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
pts <- sf::st_as_sf(
  data.frame(lon = -99.5 + 0:7, lat = 40.2 + (0:7) * 0.2,
            pathway = rep(c("OBGYN", "URO"), length.out = 8)),
  coords = c("lon", "lat"), crs = 4326)
basemap <- sf::st_sf(geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
  crs = 4326))
mysterymaps_pathway_small_multiples_map(pts, basemap, pathway_var = "pathway")
}
```
