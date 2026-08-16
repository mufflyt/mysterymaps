# Get Hospital Referral Region Shapefile

Loads the Dartmouth Atlas Hospital Referral Region (HRR) shapefile,
transforming it to EPSG:4326 (WGS84) and optionally dropping Alaska and
Hawaii. The shapefile (~8 MB) is downloaded on first use and cached in
the user's R cache directory for subsequent calls.

## Usage

``` r
mysterymaps_hrr(remove_HI_AK = TRUE)
```

## Arguments

- remove_HI_AK:

  Logical. When `TRUE` (default), HRRs whose `hrrcity` starts with
  `"AK"` or `"HI"` are dropped from the returned object.

## Value

An `sf` object with one row per HRR and columns:

- `hrrcity`:

  Character. HRR city identifier (e.g. `"CA-Sacramento"`).

- `hrrnum`:

  Integer. Numeric HRR code from the Dartmouth Atlas.

- `geometry`:

  sfc_MULTIPOLYGON in EPSG:4326 (WGS84).

Additional columns from the raw shapefile may be present.

## See also

[`ensure_hrr_shapefile()`](https://mufflyt.github.io/mysterycall/reference/ensure_hrr_shapefile.html),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md)

Other geospatial helpers:
[`mysterymaps_calculate_overlap()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_calculate_overlap.md),
[`mysterymaps_geocode()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_geocode.md)

## Examples

``` r
if (FALSE) { # interactive()
mysterymaps_hrr()
}
```
