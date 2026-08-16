# Generate honeycomb hex maps for Hospital Referral Regions

Joins physician point data to HRR polygons, computes per-HRR physician
counts, and renders a honeycomb choropleth of the contiguous US with
Alaska, Hawaii, and Puerto Rico as inset maps. The figure is saved as
both `.tiff` and `.png` to `output_dir`.

## Usage

``` r
mysterymaps_hrr_maps(
  physician_sf,
  trait_map = "all",
  honey_map = "all",
  output_dir = NULL,
  dpi = 600,
  width = 7,
  height = 5
)
```

## Arguments

- physician_sf:

  An `sf` object with one row per physician. Must have a `geometry`
  column of POINT geometries; CRS is auto-transformed to EPSG:4326 if
  needed.

- trait_map:

  Character scalar used as a label in the output filename (e.g. `"all"`,
  `"neurotology"`). No validation; used as-is.

- honey_map:

  Character scalar used as a secondary label in the output filename
  (e.g. `"all"`). No validation; used as-is.

- output_dir:

  Directory where generated figures are written. Defaults to a
  session-specific folder inside
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- dpi:

  Integer. Raster resolution in DPI for the saved figure. Default `600`.

- width:

  Numeric. Figure width in inches. Default `7`.

- height:

  Numeric. Figure height in inches. Default `5`.

## Value

Invisibly returns a `grob` object (from
[`gridExtra::arrangeGrob`](https://rdrr.io/pkg/gridExtra/man/arrangeGrob.html))
containing the arranged multi-panel map. Side effects: writes two files
to `output_dir` - `<trait_map>_<honey_map>_honey.tiff` and
`<trait_map>_<honey_map>_honey.png`.

## See also

[`mysterymaps_hrr()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr.md)
to obtain the HRR `sf` object;
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md)

Other mapping:
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md)

## Examples

``` r
if (FALSE) { # interactive()
mysterymaps_hrr_maps(physician_sf)
}
```
