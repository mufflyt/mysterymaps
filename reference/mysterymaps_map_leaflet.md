# Create a Leaflet Base Map

This function creates a Leaflet BASE map with specific configurations,
including the base tile layer, scale bar, default view settings, and
layers control.

## Usage

``` r
mysterymaps_map_leaflet()
```

## Value

A `leaflet` map object (class `"leaflet"` from the leaflet package)
pre-configured with tile providers, scale bar, and layer controls.

## See also

Other mapping:
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md)

## Examples

``` r
if (FALSE) { # interactive()
map <- mysterymaps_map_leaflet()
}
```
