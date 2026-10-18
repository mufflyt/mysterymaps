# One-call E2SFCA accessibility map

Joins a `twostep::compute_e2sfca()` result onto its tract geometry and
renders it with the three-way zero/outside/missing distinction the
result already carries – in one call, instead of each caller re-deriving
the join and the colour classification by hand.

## Usage

``` r
mysterymaps_accessibility_map(
  e2sfca_result,
  tracts_sf,
  value_col = "access_scaled",
  legend_title = "Modeled Accessibility",
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  k = 6,
  digits = 1,
  zero_color = "#e0e0e0",
  na_color = "#ffffff",
  outside_color = "#efe7d5",
  viridis_option = "viridis",
  crs = 5070
)
```

## Arguments

- e2sfca_result:

  `list`: the object `twostep::compute_e2sfca()` returns. Must contain
  an `access` element: a data frame with columns `GEOID`,
  `coverage_status`, and `value_col`.

- tracts_sf:

  `sf` polygon layer with a `GEOID` column to join
  `e2sfca_result$access` onto.

- value_col:

  `character(1)`: column in `e2sfca_result$access` to map. Default
  `"access_scaled"` – the per-capita-scaled score (e.g. "per 100,000
  women"), which `compute_e2sfca()`'s own documentation names as the
  scientific value a reader, table or map should consume. Pass
  `"access"` for the unscaled score.

- legend_title:

  `character(1)`: legend heading. Default `"Modeled Accessibility"`.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- k:

  `integer(1)`: target number of Jenks classes for the positive scores,
  passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md).
  Default `6`.

- digits:

  `integer(1)`: decimal places in the legend's score labels. Default
  `1`.

- zero_color, na_color, outside_color:

  Colours for a measured zero, a missing value, and a tract outside
  every modelled catchment, respectively. Defaults match
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
  own.

- viridis_option:

  `character(1)`: passed to the `option` argument of the
  [`viridisLite::viridis()`](https://sjmgarnier.github.io/viridisLite/reference/viridis.html)
  palette used for the positive classes.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

`compute_e2sfca()`'s `$access` tibble distinguishes three states that a
plain continuous choropleth collapses into two:

- a measured zero:

  `coverage_status == "within_modeled_catchment"` and the accessibility
  score is `0` – the tract is reached, and the weighted supply reaching
  it is genuinely nil. Takes `zero_color`.

- outside every catchment:

  `coverage_status == "outside_all_modeled_catchments"` – no isochrone
  reaches this tract at all. This is the finding an access study usually
  exists to report, and is emphatically not missing data. Takes
  `outside_color`.

- missing:

  `value_col` is `NA` for a reached tract, or the tract's `GEOID` has no
  match in `tracts_sf`. Takes `na_color`.

Before this distinction existed in `twostep`, outside-catchment tracts
were zero-filled and became indistinguishable from a measured zero – 190
of 1,447 Colorado tracts, 13% of the state, each reported as "zero
accessibility" when the honest answer was "the model never reached
here".
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
`coverage` argument exists specifically for this shape, via
`coverage_status`; this function is the one-call assembler for it, the
same role
[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md)
plays for a plain leaflet supply choropleth.

This function does not call `twostep::compute_e2sfca()` itself and does
not depend on the `twostep` package – it only consumes the list shape
that function documents returning, so a caller can pass in anything with
the same shape.

## See also

Other mapping:
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md),
[`mysterymaps_access_choropleth_map_multi()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map_multi.md),
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
[`mysterymaps_pathway_small_multiples_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pathway_small_multiples_map.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
# The shape compute_e2sfca() returns -- see twostep::compute_e2sfca()'s own
# examples for how `access` is actually produced from provider isochrones.
e2sfca_result <- list(access = data.frame(
  GEOID = c("T1", "T2", "T3", "T4"),
  access_scaled = c(0, 4.2, NA, 7.8),
  coverage_status = c("within_modeled_catchment", "within_modeled_catchment",
                      "outside_all_modeled_catchments", "within_modeled_catchment")
))
tracts_sf <- sf::st_sf(
  GEOID = c("T1", "T2", "T3", "T4"),
  geometry = sf::st_sfc(lapply(1:4, function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
  }), crs = 4326)
)
mysterymaps_accessibility_map(e2sfca_result, tracts_sf)
}
```
