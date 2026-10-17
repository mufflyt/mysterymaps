# Drive-time cartogram map

Redraws each polygon scaled radially around its nearest hub (e.g. a
provider or partner site), so areas whose real drive time is far out of
proportion to their straight-line distance balloon outward, and
well-connected areas pull inward. This is **not a true-area map** – it
deliberately distorts geography to encode travel time instead.

## Usage

``` r
mysterymaps_cartogram_map(
  polygons,
  hub_id_var,
  hub_lon_var,
  hub_lat_var,
  time_var,
  straight_distance_var,
  distance_unit = "miles",
  scale_clip = c(0.2, 3),
  hub_points = NULL,
  hub_label = "Site",
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  reference_minutes = 30
)
```

## Arguments

- polygons:

  `sf` polygon layer, one row per area to warp.

- hub_id_var:

  `character(1)`: column in `polygons` identifying the polygon (joined
  to `hub_lon_var`/`hub_lat_var`/`time_var`/ `straight_distance_var`,
  all also columns of `polygons`, one value per row).

- hub_lon_var, hub_lat_var:

  `character(1)`: numeric columns in `polygons` giving each row's hub
  longitude/latitude (WGS84).

- time_var:

  `character(1)`: numeric column, drive time in minutes from each
  polygon to its hub.

- straight_distance_var:

  `character(1)`: numeric column, straight-line distance from each
  polygon to its hub, in the unit named by `distance_unit`.

- distance_unit:

  `character(1)`: unit of `straight_distance_var`, one of `"miles"`
  (default) or `"kilometers"`. Only used to label the drive- time
  reference line; the warp math itself is unit-agnostic as long as
  `straight_distance_var` is consistent.

- scale_clip:

  Length-2 numeric: `c(min, max)` bounds on the per-row warp scale
  factor. Default `c(0.2, 3)`.

- hub_points, hub_label:

  Optional `sf` POINT layer of the hubs themselves (e.g. provider
  locations), warped the same way and drawn on top, with its own
  `hub_time_var`/`hub_straight_distance_var` columns (minutes/distance
  from each hub to *itself*, i.e. `0`, OR from each named target site to
  its nearest hub – see examples in package tests). `NULL` omits.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- reference_minutes:

  `numeric(1)`: length, in minutes of typical-pace travel, of the drawn
  reference line. Default `30`.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

A straight-line distance near zero (the hub essentially inside the
polygon) makes the warp ratio `time / distance` blow up into a
meaningless value that has nothing to do with genuine circuitousness –
it is purely an artifact of dividing by a near-zero denominator. Per-row
scale factors are clipped to `scale_clip` (default `c(0.2, 3)`) for
exactly this reason: without the clip, a handful of near-zero-distance
polygons would misleadingly read as "the most distorted" on the map.

The calibration constant (how much distance one minute of drive time
"should" correspond to, in the undistorted/typical-pace case) is derived
automatically from the data:
`median(straight_distance_var) / median(time_var)` across all rows with
both values present. A polygon whose warp ratio is near this median pace
is drawn close to its true shape and position; a polygon far slower or
faster than that pace is pushed out or pulled in accordingly.

A real distance scale bar would misrepresent this map, since distance on
it deliberately does not mean distance – this function draws a "drive
time scale" reference line instead, equal to `reference_minutes` of
typical-pace travel, rather than calling
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md).

## See also

Other mapping:
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_catchment_redundancy_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_catchment_redundancy_map.md),
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
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
  id = 1:4,
  hub_lon = -97.5, hub_lat = 40.5,
  time_min = c(10, 20, 30, 60),
  straight_miles = c(9.6, 19.2, 28.8, 57.6),
  geometry = sf::st_sfc(lapply(1:4, function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
  }), crs = 4326)
)
mysterymaps_cartogram_map(
  counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
  time_var = "time_min", straight_distance_var = "straight_miles")
}
```
