# Catchment-redundancy choropleth map

Shows, for each target polygon, roughly how many distinct providers'
drive-time catchment areas reach it – `1` means that area has exactly
one option within range, `0` means none do, and higher numbers mean more
redundant coverage. This is the complement of a simple access map:
access maps show whether a provider is reachable at all, this shows how
much choice a reader at that location actually has.

## Usage

``` r
mysterymaps_catchment_redundancy_map(
  catchments,
  polygons,
  provider_id_var,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  grid_spacing_miles = 5,
  k = 6,
  zero_color = "#e0e0e0",
  na_color = "#ffffff",
  crs = 5070
)
```

## Arguments

- catchments:

  `sf` polygon layer, one row per provider catchment (single drive-time
  band; see Details).

- polygons:

  `sf` polygon layer: the target areas to summarize onto (e.g.
  counties).

- provider_id_var:

  `character(1)`: column in `catchments` identifying the distinct
  provider.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- grid_spacing_miles:

  `numeric(1)`: sample grid spacing, in miles. Default `5`. Smaller is
  more accurate and slower.

- k:

  `integer(1)`: target number of Jenks classes for the positive
  (1-or-more) redundancy counts, passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md).
  Default `6`.

- zero_color, na_color:

  Colours for a measured-zero (no coverage at all) and an unmeasured
  polygon, respectively. Defaults match
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
  own.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

Redundancy is estimated with a sample grid rather than an exact polygon
overlay, because an exact pairwise overlay across many overlapping
catchments is expensive and the exact boundary of that overlay is not
what the map needs – a representative per-polygon summary is. A regular
point grid (`grid_spacing_miles` apart, in EPSG:5070 meters) is laid
over the union of `catchments`' bounding box and `polygons`; each grid
point counts the number of **distinct** `provider_id_var` values among
the catchments containing it (`0` if none); each target polygon's value
is the **median** grid-point count among points falling inside it.
Median, not mean, so one corner with much higher or lower redundancy
than the rest of a large, irregularly-shaped polygon does not dominate
its summary value.

A small polygon can be narrower than `grid_spacing_miles` and catch zero
grid points at all – on Virginia's independent cities (Lexington,
Fairfax City, Manassas, Manassas Park, Colonial Heights, Covington,
Poquoson, Emporia, Bristol, Charlottesville; all under 20 square miles)
this left 10 of 133 polygons with no sample at all, rendered as a blank
gap in `na.value` even though they are not actually missing data. Any
polygon the grid misses entirely is sampled once more directly, at
[`sf::st_point_on_surface()`](https://r-spatial.github.io/sf/reference/geos_unary.html)
(guaranteed to land inside the polygon, unlike a bounding-box centroid,
which can fall outside an irregular shape).

A redundancy count is classified, not coloured continuously: `0` –
nothing covers this area at all – is as categorically different from `1`
as `1` is different from `5`, and a continuous
[`scale_fill_viridis_c()`](https://ggplot2.tidyverse.org/reference/scale_viridis.html)
(the original implementation) puts `0` at the dark end of the same
gradient as every low-but-nonzero value, where it reads as merely "low
redundancy" rather than the "no option at all" finding it actually is.
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
with `digits = NULL` gives whole-number legend labels appropriate to a
count and puts `0` in its own class, so it replaces the old
[`scale_fill_viridis_c()`](https://ggplot2.tidyverse.org/reference/scale_viridis.html)
plus a hand-written integer-breaks helper.

`catchments` must contain exactly one row per `(provider, band)` you
want counted. If `catchments` holds multiple drive-time bands per
provider, filter to a single band before calling this function – passing
all bands at once would double-count the same provider at a point
reachable within more than one of their bands.

## See also

Other mapping:
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
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
  geometry = sf::st_sfc(lapply(1:2, function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
  }), crs = 4326)
)
# county 1 is covered by provider A only, county 2 by both A and B
catch_a <- sf::st_sf(provider = "A", geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-99, -97, -97, -99, -99), c(40, 40, 42, 42, 40)))),
  crs = 4326))
catch_b <- sf::st_sf(provider = "B", geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-98, -97, -97, -98, -98), c(40, 40, 41, 41, 40)))),
  crs = 4326))
mysterymaps_catchment_redundancy_map(
  rbind(catch_a, catch_b), counties, provider_id_var = "provider",
  grid_spacing_miles = 10)
}
```
