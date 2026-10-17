# Hex-bin a rate (point count per areal-interpolated denominator)

Builds a hexagonal grid over `boundary_sf`, counts `points_sf` per cell
(the numerator), area-weight interpolates
`denominator_sf[[denominator_col]]` onto the same grid (the denominator
– e.g. population), and returns both plus the resulting rate. This is
the exact composition
[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md)
was deliberately left out of (a raw point count has no denominator to
divide by): a rate needs a second, spatially-different data source, and
getting that second source onto the same grid as the first is areal
interpolation, not point-counting.

## Usage

``` r
mysterymaps_hex_bin_rate(
  boundary_sf,
  points_sf,
  denominator_sf,
  denominator_col,
  per = 1,
  cellsize = 0.3,
  min_denominator = 0,
  value_col = "rate"
)
```

## Arguments

- boundary_sf:

  `sf`: polygon(s) defining the study area the grid is built over and
  clipped to.

- points_sf:

  `sf`: point data to count per hex cell (the numerator).

- denominator_sf:

  `sf`: polygon layer carrying the denominator (e.g. census tracts with
  a population column). Does not need to share `boundary_sf`'s or
  `points_sf`'s CRS; transformed automatically.

- denominator_col:

  `character(1)`: numeric column in `denominator_sf` to interpolate
  (e.g. `"female_pop"`).

- per:

  `numeric(1)`: rate denominator scale, e.g. `100000` for "per 100,000".
  Default `1` (a plain proportion).

- cellsize:

  `numeric(1)`: hexagon size in the units of `boundary_sf`'s CRS
  (degrees, if left in EPSG:4326). Default `0.3`.

- min_denominator:

  `numeric(1)`: cells whose interpolated denominator falls below this
  are reported with `rate = NA` rather than a rate – a cell with a
  handful of interpolated residents produces a wild, near-meaningless
  rate (one point in a 40-person cell reads as 2,500-per-100k). Default
  `0` (no suppression; set this per study, the way
  [`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md)'s
  caller would set a population floor).

- value_col:

  `character(1)`: name of the output rate column. Default `"rate"`.

## Value

An `sf` of every hex cell in the grid, carrying `count` (integer,
numerator), `denominator` (numeric, interpolated), and `value_col`
(numeric, `NA` where `denominator < min_denominator`).

## Details

Unlike
[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md),
which drops cells below `min_count` entirely, this function returns
every cell in the grid, including zero-count and zero-denominator ones –
a rate map needs the full grid to tell "no people live here"
(denominator near zero, rate correctly `NA`) apart from "people live
here and nothing was counted" (denominator present, count zero, rate
correctly `0`) apart from "people live here and some things were
counted" (a positive rate). Collapsing any of those three into either of
the others is the error
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
exists to prevent, and this function's output is built to feed that
scale directly.

Denominator interpolation assumes the denominator is uniformly
distributed within each `denominator_sf` polygon – the standard
areal-interpolation assumption
([`sf::st_interpolate_aw()`](https://r-spatial.github.io/sf/reference/interpolate_aw.html),
`extensive = TRUE`, appropriate because a population count is additive:
a hex covering half a tract is assumed to hold half that tract's
people). It is weakest where the denominator is not actually uniform
within a polygon, which it rarely is exactly – the same caveat as any
choropleth built on areal units coarser than the thing being counted.

A point that lands exactly on a shared edge between two hex cells is
counted in both – an inherent property of intersecting points against a
[`sf::st_make_grid()`](https://r-spatial.github.io/sf/reference/st_make_grid.html)
lattice, shared with
[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md)
and
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md).
Negligible for real geocoded coordinates (probability zero in practice);
a hazard only for hand-constructed or deliberately round test/example
coordinates.

## See also

[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md)
for a plain count with no denominator;
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
to colour the result.

Other geospatial:
[`mm_area_in()`](https://mufflyt.github.io/mysterymaps/reference/mm_area_in.md),
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md),
[`mysterymaps_hex_bin_counts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hex_bin_counts.md),
[`validate_sf_inputs()`](https://mufflyt.github.io/mysterymaps/reference/validate_sf_inputs.md)

## Examples

``` r
if (FALSE) { # interactive()
boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
  crs = 4326))
points_sf <- sf::st_as_sf(
  data.frame(lon = c(-99.1, -98.4, -97.7), lat = c(40.1, 40.3, 41.2)),
  coords = c("lon", "lat"), crs = 4326)
denominator_sf <- sf::st_sf(
  population = c(5000, 8000),
  geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98.5, -98.5, -100, -100), c(39, 39, 42, 42, 39)))),
    sf::st_polygon(list(cbind(c(-98.5, -97, -97, -98.5, -98.5), c(39, 39, 42, 42, 39)))),
    crs = 4326))
mysterymaps_hex_bin_rate(boundary_sf, points_sf, denominator_sf, "population",
                         per = 1000, cellsize = 0.5)
}
```
