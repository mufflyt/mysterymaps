# Clear the isochrone memoization cache

[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md)
caches every result in memory for the duration of the R session. Call
this after processing a large batch to release that memory. Has no
effect if the `memoise` package is not installed (memoization is skipped
in that case).

## Usage

``` r
mysterymaps_clear_isochrone_cache()
```

## Value

Invisibly `NULL`.

## See also

[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md)
which builds the memoized cache.

Other mapping:
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
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
mysterymaps_clear_isochrone_cache()
```
