# Rate choropleth map (numerator per denominator)

Shades each polygon by a rate – `numerator_var / denominator_var * per`
– rather than a raw count, so a reader compares areas fairly instead of
larger-population areas simply looking darker.

## Usage

``` r
mysterymaps_rate_choropleth_map(
  polygons,
  numerator_var,
  denominator_var,
  numerator_label,
  denominator_label,
  per = 1e+05,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  k = 6,
  digits = 1,
  zero_color = "#e0e0e0",
  na_color = "#ffffff",
  viridis_option = "viridis",
  crs = 5070
)
```

## Arguments

- polygons:

  `sf` polygon layer.

- numerator_var, denominator_var:

  `character(1)`: numeric columns in `polygons`.

- numerator_label, denominator_label:

  `character(1)`: full-word labels used to build the legend title.

- per:

  `numeric(1)`: rate denominator scale, e.g. `100000` for "per 100,000".
  Default `100000`.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- k:

  `integer(1)`: target number of Jenks classes for the positive rates,
  passed to
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md).
  Default `6`.

- digits:

  `integer(1)`: decimal places in the legend's rate labels. Default `1`;
  pass `0` when the rate reads more naturally as a whole number (e.g.
  "per 1,000" counts that are rarely fractional in practice).

- zero_color, na_color:

  Colours for a measured-zero rate and for an undefined
  (zero-denominator) rate, respectively. Defaults match
  [`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)'s
  own.

- viridis_option:

  `character(1)`: passed to the `option` argument of the
  [`viridisLite::viridis()`](https://sjmgarnier.github.io/viridisLite/reference/viridis.html)
  palette used for the positive classes.

- crs:

  Projection for display. Default EPSG:5070 (Albers Equal Area),
  appropriate for the contiguous United States.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

This function takes `polygons` with both variables already attached and
does no joining itself. That is deliberate: in at least one prior use of
this pattern (Virginia counties), joining a rate's two halves by the
`NAME` column silently merged the wrong rows, because Fairfax, Franklin,
Richmond, and Roanoke each name both a county AND a same-named
independent city. Push any such join to the caller, and join by a stable
identifier (e.g. `GEOID`), never by a place name.

The legend title is always built from `numerator_label` and
`denominator_label` in full words – pass `"Urogynecologists"` and
`"Women Age 40 and Older"`, not `"Urogyn"` and `"W40+"` – because this
title is the one place in the map an abbreviation would otherwise land
by default.

## Zero is a category, not the bottom of a gradient

An earlier version of this function coloured the rate with a plain
continuous
[`scale_fill_viridis_c()`](https://ggplot2.tidyverse.org/reference/scale_viridis.html)
(optionally log1p-transformed for skew). That repeats, on a brand-new
function, the exact mistake
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
exists to prevent: a polygon with a **measured rate of zero** (real
population, no provider) rendered identically to one just barely above
zero, both near the dark end of the gradient – on a prior national map
this put over half the counties in the country into one
indistinguishable "low" class when the honest answer for most of them
was "none". This function now classifies `.mm_rate` with
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md)
instead: zero gets its own colour and legend entry, positive rates are
Jenks-classified (which is also why there is no `log_scale` argument any
more – natural breaks already handle the right-skewed distribution a log
transform was compensating for), and a polygon with a zero *denominator*
(`.mm_rate` is `NA`, an undefined rate, not a measured one) gets
`na_color` rather than being folded into the zero class.

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
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)

## Examples

``` r
if (FALSE) { # interactive()
counties <- sf::st_sf(
  n_providers = c(1, 2, 0, 4),
  population = c(10000, 100000, 50000, 200000),
  geometry = sf::st_sfc(lapply(1:4, function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
  }), crs = 4326)
)
mysterymaps_rate_choropleth_map(
  counties, numerator_var = "n_providers", denominator_var = "population",
  numerator_label = "Urogynecologists", denominator_label = "Women Age 40 and Older")
}
```
