# Routed drive-time flow map

Draws a set of pre-computed routed paths (e.g. shortest road routes from
each target site to its nearest provider) coloured by travel time, over
a basemap. This function only renders; it does not call a routing API –
build `routes` once with whatever routing engine is available (Valhalla,
HERE, OSRM) and pass the result in as an `sf` LINESTRING layer.

## Usage

``` r
mysterymaps_flow_map(
  routes,
  basemap,
  time_var,
  time_label = "Driving Time in Minutes",
  origin_points = NULL,
  destination_points = NULL,
  origin_label = "Origin Site",
  destination_label = "Destination Provider",
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  viridis_option = "inferno",
  crs = 5070
)
```

## Arguments

- routes:

  `sf` LINESTRING (or MULTILINESTRING) layer, one row per routed path.

- basemap:

  `sf` polygon layer to draw beneath the routes.

- time_var:

  `character(1)`: numeric column in `routes` giving travel time, used to
  colour each route.

- time_label:

  `character(1)`: full-word legend title for `time_var`. Default
  `"Driving Time in Minutes"`.

- origin_points, destination_points:

  Optional `sf` POINT layers drawn on top of the routes (e.g. the target
  sites and the nearest providers). `NULL` omits either.

- origin_label, destination_label:

  `character(1)`: full-word shape legend labels for `origin_points` /
  `destination_points`.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- viridis_option:

  `character(1)`: passed to
  [`ggplot2::scale_color_viridis_c()`](https://ggplot2.tidyverse.org/reference/scale_viridis.html)'s
  `option`. Default `"inferno"`.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

A straight-line ("as the crow flies") distance map can badly overstate
real access where the road network is constrained – a 60-mile straight
radius around a site cut off by a single bridge or mountain pass can
overstate the population actually reachable in that time by
several-fold. Routing each path on the real road network and drawing it
here, rather than drawing straight lines, is what keeps a flow map
honest in that case.

## See also

Other mapping:
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
[`mysterymaps_catchment_redundancy_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_catchment_redundancy_map.md),
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
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
routes <- sf::st_sf(
  trip = c("a", "b"), minutes = c(12, 45),
  geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(-99, 40), c(-98, 40.5))),
    sf::st_linestring(rbind(c(-98, 41), c(-97, 41.2))),
    crs = 4326))
basemap <- sf::st_sf(geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-100, -96, -96, -100, -100), c(39, 39, 43, 43, 39)))),
  crs = 4326))
mysterymaps_flow_map(routes, basemap, time_var = "minutes")
}
```
