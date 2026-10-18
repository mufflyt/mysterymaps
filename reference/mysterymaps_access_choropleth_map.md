# Single-geography "closest provider" access choropleth, time vs. supply toggle

Renders one geography shaded two ways as switchable base layers – drive
time to the nearest provider, or provider supply per capita – plus a
hover-labelled access-desert overlay, click-to-highlight provider
markers (clicking a geography lights up the providers nearest it), a
combined place/provider name search, and a legend that swaps with the
active base layer.

## Usage

``` r
mysterymaps_access_choropleth_map(
  geo,
  providers,
  highlight_lookup,
  supply_pal,
  supply_values,
  band_colors,
  band_labels,
  title_html,
  labels = list(),
  text = list(),
  base_tiles = "CartoDB.Positron"
)
```

## Arguments

- geo:

  `sf` polygons, one row per geography, with columns: `mm_id` (unique
  id), `mm_label` (hover HTML), `mm_popup` (click HTML), `mm_fill_time`,
  `mm_fill_supply` (precomputed fill colours) and `mm_no_access`
  (logical; `TRUE` feeds the desert overlay).

- providers:

  `sf` POINTs with `mm_id` (matches the values in `highlight_lookup`),
  `mm_label` and `mm_popup`.

- highlight_lookup:

  Named list: geography `mm_id` -\> character vector of provider
  `mm_id`s to light up when that geography is clicked.

- supply_pal, supply_values:

  Leaflet palette function and the values it was built on, for the
  supply legend.

- band_colors, band_labels:

  Drive-time legend colours and labels.

- title_html:

  HTML for the top-left title control.

- labels:

  Named list overriding group labels: `time`, `supply`, `desert`,
  `providers`.

- text:

  Named list overriding legend/desert wording: `time_legend`,
  `supply_legend`, `desert`.

- base_tiles:

  `character(1)`: provider-tile name. Default `"CartoDB.Positron"`.

## Value

A `leaflet` htmlwidget.

## A sibling, not a duplicate, of [`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md)

[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md)
is the template for a *single* shading (one `value_col`) plus dissolved
drive-time **coverage-surface** base layers (e.g. "within 30 minutes" as
its own polygon). This function is for the different, complementary case
of *one* geography shaded two *different ways* that a reader toggles
between, with click-to-highlight tied to provider identity rather than a
dissolved surface. Read both docs before adding a third variant.

## Multi-geography sibling

[`mysterymaps_access_choropleth_map_multi()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map_multi.md)
is this same idea extended to several geographies (e.g. county AND
congressional district) switchable in one map.

## See also

[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_access_choropleth_map_multi()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map_multi.md)

Other mapping:
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
[`mysterymaps_pathway_small_multiples_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pathway_small_multiples_map.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
geo <- sf::st_sf(
  mm_id = c("A", "B"), mm_label = c("A", "B"), mm_popup = c("<b>A</b>", "<b>B</b>"),
  mm_fill_time = c("#2166ac", "#67a9cf"), mm_fill_supply = c("#67a9cf", "#2166ac"),
  mm_no_access = c(TRUE, FALSE),
  geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
    crs = 4326))
providers <- sf::st_as_sf(
  data.frame(mm_id = "P1", mm_label = "P1", mm_popup = "<b>P1</b>", lon = -97, lat = 40),
  coords = c("lon", "lat"), crs = 4326)
mysterymaps_access_choropleth_map(
  geo, providers, highlight_lookup = list(A = "P1"),
  supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
  band_colors = c("#2166ac", "#67a9cf"), band_labels = c("<=30 min", ">30 min"),
  title_html = "<b>Example</b>")
}
```
