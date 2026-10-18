# Multi-layer choropleth + point Leaflet map, switchable by base layer

Generic builder: several toggleable choropleth base groups (radio
buttons), a point overlay with name search, a scale bar, a per-layer
legend that swaps with the active base layer, and an optional title card
and footnote. Each layer is coloured with
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
so a `0` count always gets its own colour rather than the bottom of a
gradient.

## Usage

``` r
mysterymaps_choropleth_point_map(
  layers,
  points,
  value_col = "n",
  point_fill,
  point_legend = NULL,
  legend_title_fmt = "Count per %s",
  title_html = NULL,
  footnote_html = NULL,
  search_group = "Points",
  search_placeholder = "Search...",
  default_layer = names(layers)[1],
  jenks_k = 6,
  fill_opacity = 0.9,
  point_radius = 6
)
```

## Arguments

- layers:

  Named list of `sf` polygon layers. Each must carry `id`, the count
  column (`value_col`), a `label` column (hover HTML) and a `popup`
  column (click HTML). The list order sets the radio order;
  `default_layer` is shown first.

- points:

  `sf` point layer with `label` and `popup` columns.

- value_col:

  `character(1)`: count column used for colouring each layer. Default
  `"n"`.

- point_fill:

  `character(1)`: fill colour for the point markers.

- point_legend:

  Optional `list(colors=, labels=, title=)` for a separate point legend
  (top-right).

- legend_title_fmt:

  [`sprintf()`](https://rdrr.io/r/base/sprintf.html) template taking the
  layer name, used as each choropleth legend's title (may contain HTML).

- title_html:

  Optional HTML for a top-left title card.

- footnote_html:

  Optional HTML rendered as a caption (bottom-left).

- search_group:

  `character(1)`: group name for the searchable point layer.

- search_placeholder:

  `character(1)`: placeholder text for the search box.

- default_layer:

  `character(1)`: which layer is shown on load. Default the first name
  in `layers`.

- jenks_k:

  `integer(1)`: positive-class count passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
  for every layer.

- fill_opacity:

  `numeric(1)`: polygon fill alpha. Default `0.90`.

- point_radius:

  `numeric(1)`: circle-marker radius in px. Default `6`.

## Value

A `leaflet` htmlwidget.

## Details

Points render in their own
[`leaflet::addMapPane()`](https://rstudio.github.io/leaflet/reference/addMapPane.html)
above the choropleth (`zIndex = 650`) so they stay clickable over a dark
fill, without the custom-pane hit-testing hazard documented on
[`mysterymaps_physician_dot_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_physician_dot_map.md)
– that hazard is for a pane with a dedicated *canvas renderer*; this
pane shares the map's default renderer.

## See also

Other mapping:
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md),
[`mysterymaps_access_choropleth_map_multi()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map_multi.md),
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_aggregate_values_to_polygons()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_aggregate_values_to_polygons.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
[`mysterymaps_catchment_redundancy_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_catchment_redundancy_map.md),
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
counties <- sf::st_sf(
  id = 1:2, n = c(0, 4), label = c("A", "B"), popup = c("<b>A</b>", "<b>B</b>"),
  geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
    crs = 4326))
points <- sf::st_as_sf(
  data.frame(lon = -97, lat = 40, label = "Provider", popup = "<b>Provider</b>"),
  coords = c("lon", "lat"), crs = 4326)
mysterymaps_choropleth_point_map(list(Count = counties), points, point_fill = "#c2185b")
}
```
