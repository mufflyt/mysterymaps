# Two-variable (bivariate) choropleth map

Shades each polygon by the joint tercile class of two numeric variables
at once – e.g. population need versus provider scarcity – so a reader
sees where the two overlap without needing two separate maps. Includes a
3x3 legend grid rendered as an inset, not a separate figure.

## Usage

``` r
mysterymaps_bivariate_choropleth_map(
  polygons,
  x_var,
  y_var,
  x_label,
  y_label,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  palette = MYSTERYMAPS_BIVARIATE_PALETTE,
  na_color = "grey85",
  crs = 5070,
  legend_position = "br"
)
```

## Arguments

- polygons:

  `sf` polygon layer.

- x_var, y_var:

  `character(1)`: numeric columns in `polygons`.

- x_label, y_label:

  `character(1)`: full-word axis labels for the legend grid (e.g.
  `"Women Age 40 and Older"`, not `"Women 40+"`).

- title, subtitle, caption:

  Character labels. `NULL` omits.

- palette:

  Named length-9 colour vector, keys `"1-1"` .. `"3-3"` (x class first,
  y class second). Default
  [MYSTERYMAPS_BIVARIATE_PALETTE](https://mufflyt.github.io/mysterymaps/reference/MYSTERYMAPS_BIVARIATE_PALETTE.md).

- na_color:

  Colour for polygons missing `x_var` or `y_var`.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

- legend_position:

  `character(1)`: corner for the legend inset, one of `"br"`, `"bl"`,
  `"tr"`, `"tl"`. Default `"br"`, which leaves the bottom-left corner
  free for
  [`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md).

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

The legend inset is built with
[`ggplot2::annotation_custom()`](https://ggplot2.tidyverse.org/reference/annotation_custom.html)
around a small second `ggplot`, not `cowplot::draw_plot()`. This package
does not depend on `cowplot`, and
[`annotation_custom()`](https://ggplot2.tidyverse.org/reference/annotation_custom.html)
does the same job – drawing one grob inside another plot's panel –
without adding a dependency for it.

Each variable is split into terciles independently with
[`classInt::classIntervals()`](https://r-spatial.github.io/classInt/reference/classIntervals.html)
(`style = "quantile"`), so the bivariate class reflects each variable's
own distribution rather than a shared arbitrary cutoff. A polygon with
`NA` in either variable gets `NA` for the joint class and is drawn in
`na_color`.

## See also

Other mapping:
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
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
counties <- sf::st_sf(
  rate = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
  need = c(9, 8, 7, 6, 5, 4, 3, 2, 1),
  geometry = sf::st_sfc(lapply(1:9, function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
  }), crs = 4326)
)
mysterymaps_bivariate_choropleth_map(
  counties, x_var = "rate", y_var = "need",
  x_label = "Providers per Capita", y_label = "Population Need")
}
```
