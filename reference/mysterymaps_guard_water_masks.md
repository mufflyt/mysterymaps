# Reject a water mask that is really a state outline

A land clip subtracts water from a coverage surface. If the "water"
polygon is actually the state boundary, the clip subtracts the state –
silently, because removing too much geometry does not error, does not
warn, and leaves no hole a reader would recognise as a defect.

## Usage

``` r
mysterymaps_guard_water_masks(
  masks,
  census_water_km2,
  max_ratio = 5,
  action = c("exclude", "error")
)
```

## Arguments

- masks:

  `named list of sf/sfc`: water masks, named by state abbreviation.

- census_water_km2:

  `named numeric`: census `AWATER` per state, in km^2. Supply from
  `tigris::states()$AWATER / 1e6`.

- max_ratio:

  `numeric(1)`: a mask larger than this multiple of the state's mapped
  water is not water. Defaults to 5.

- action:

  `"exclude"` (default) drops the offenders and returns the rest;
  `"error"` aborts. Excluding is usually right: a surface carrying some
  open water beats one that erases whole states, and masks generally
  cannot be regenerated at the point of use.

## Value

The masks, minus any judged inverted. The `"inverted"` attribute records
which were dropped and their ratios.

## Details

Five states once carried a single-feature mask covering 102-104% of
their own land area.
[`st_difference()`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html)
erased every isochrone in Missouri, Iowa, Kansas, West Virginia and
Arkansas, and the map reported the rural interior as having no provider
access at all. The upstream cause was a downloader that logged "Empty
response, assuming complete": those states never received a
high-resolution mask, and a fallback wrote the state boundary in its
place.

## Why census water area is the denominator

The obvious test – mask area as a share of the state's LAND area – flags
Michigan at 68% and would exclude it. Michigan's boundary contains the
Great Lakes, so a mask that size is correct there, and dropping it lets
the surface run across Lake Michigan: the exact failure the clip exists
to prevent.

Measured against census `AWATER` the cases separate cleanly – Michigan
is 0.95x its mapped water, while the inverted masks are 45x to 162x.
Choose the denominator that distinguishes the failure from the
legitimate extreme, not the one that is easiest to reach.

## See also

Other county-access-template:
[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_gate_provider_coverage()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_gate_provider_coverage.md),
[`mysterymaps_name_search()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_name_search.md),
[`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
st <- tigris::states(cb = TRUE, year = 2023)
aw <- setNames(as.numeric(st$AWATER) / 1e6, st$STUSPS)
masks <- mysterymaps_guard_water_masks(masks, aw)
} # }
```
