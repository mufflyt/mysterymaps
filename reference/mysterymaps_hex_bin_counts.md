# Hex-bin point counts over any study-area boundary

Builds a hexagonal grid over `boundary_sf`, counts how many `points_sf`
fall in each cell, and returns the cells that cleared `min_count` – the
GEOLYTIX-style "bin points into hexagons, shade by count" map,
generalized from the HRR/physician case in
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md)
to any boundary and any point dataset. It is a thin, renaming wrapper
around
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md),
which carries the tested fixes (coastline slivers under s2, the
westernmost-cells defect, CRS transforms); this function adds no new
hex-counting logic of its own.

## Usage

``` r
mysterymaps_hex_bin_counts(
  boundary_sf,
  points_sf,
  value_col = "count",
  cellsize = 0.3,
  min_count = 1L,
  southern_limit = -90,
  include_zero_cells = FALSE
)
```

## Arguments

- boundary_sf:

  `sf`: polygon(s) defining the study area the grid is built over and
  clipped to.

- points_sf:

  `sf`: point data to count per hex cell. Transformed to `boundary_sf`'s
  CRS automatically if it arrives in another one.

- value_col:

  `character(1)`: name of the output count column. Default `"count"`.

- cellsize:

  `numeric(1)`: hexagon size in the units of `boundary_sf`'s CRS
  (degrees, if left in EPSG:4326). Default `0.3`.

- min_count:

  `integer(1)`: cells holding fewer than this many points are dropped
  rather than returned – small-cell suppression, not a rendering detail.
  Default `1L` (no suppression). Ignored when
  `include_zero_cells = TRUE` (see below).

- southern_limit:

  `numeric(1)`: cells entirely south of this latitude are dropped.
  [`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md)
  defaults this to `15` to cut outlying US territory out of HRR maps;
  that is wrong for a boundary that is not the continental US (it would
  silently delete most of the Southern Hemisphere), so this wrapper
  defaults to `-90`, i.e. no clipping.

- include_zero_cells:

  `logical(1)`: return every hex cell in `boundary_sf`, including ones
  no point fell in, with `value_col = 0` there, instead of silently
  omitting them. Default `FALSE`, matching
  [`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md)'s
  original point-counting behaviour. A reader cannot tell "zero,
  measured" from "not drawn" on a map with gaps in the grid – the
  distinction
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
  and `mysterymaps_hex_bin_rate()` both exist to preserve. `min_count`
  does not apply in this mode: suppressing small counts and asserting
  that a cell is a true zero are different, incompatible claims about
  the same cell.

## Value

An `sf` of hex cells carrying a `value_col` count column. With the
default `include_zero_cells = FALSE`, cells with fewer than `min_count`
points are not returned at all; with `include_zero_cells = TRUE`, every
cell in `boundary_sf` is returned, zero-count ones included.

## See also

[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
which wraps
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md)
for the HRR/physician use case with AK/HI/PR insets baked in;
`mysterymaps_hex_bin_rate()`, which always returns the full grid because
a rate needs to distinguish zero from missing.

Other geospatial:
[`mm_area_in()`](https://mufflyt.github.io/mysterymaps/reference/mm_area_in.md),
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md),
`mysterymaps_hex_bin_rate()`,
[`validate_sf_inputs()`](https://mufflyt.github.io/mysterymaps/reference/validate_sf_inputs.md)

## Examples

``` r
if (FALSE) { # interactive()
mysterymaps_hex_bin_counts(boundary_sf, points_sf, value_col = "flood_risk")
mysterymaps_hex_bin_counts(boundary_sf, points_sf, include_zero_cells = TRUE)
}
```
