# Add an imperial-unit scale bar to a ggplot map

Thin wrapper around
[`ggspatial::annotation_scale()`](https://paleolimbot.github.io/ggspatial/reference/annotation_scale.html)
that defaults to miles instead of kilometers.

## Usage

``` r
mysterymaps_scale_bar(
  location = "bl",
  width_hint = 0.25,
  unit_category = "imperial",
  ...
)
```

## Arguments

- location:

  `character(1)`: corner to place the bar in – one of `"bl"`, `"br"`,
  `"tl"`, `"tr"`.

- width_hint:

  `numeric(1)`: target width as a fraction of the plot panel.

- unit_category:

  `character(1)`: passed through to
  [`ggspatial::annotation_scale()`](https://paleolimbot.github.io/ggspatial/reference/annotation_scale.html).
  Default `"imperial"`; pass `"metric"` or `"SI"` to override.

- ...:

  Additional arguments forwarded to
  [`ggspatial::annotation_scale()`](https://paleolimbot.github.io/ggspatial/reference/annotation_scale.html)
  (e.g. `bar_cols`, `text_cex`, `pad_x`).

## Value

A ggplot2 layer, addable to a plot with `+`.

## Details

`unit_category = "imperial"` is accepted by `annotation_scale()` only
through its `...` forwarding – it does not appear in the function's own
formal arguments (`args(ggspatial::annotation_scale)` omits it). A
caller who does not already know that can reasonably assume the function
has no imperial option and ship a kilometer bar on a United States map,
silently: there is no error or warning either way. This wrapper exists
so every static map in this package picks up miles by default without
each caller having to rediscover the `...`-forwarding behaviour.

## See also

Other mapping:
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
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
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("ggspatial", quietly = TRUE)
library(ggplot2)
ggplot() + mysterymaps_scale_bar()
}
```
