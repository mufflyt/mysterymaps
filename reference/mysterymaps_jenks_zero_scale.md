# Zero-aware Jenks natural-breaks colour scale

Classifies POSITIVE values with Jenks natural breaks and gives zero its
own colour and legend entry. Zero is a category, not the low end of a
scale: a county with no provider is categorically different from one
with a low rate, and binning them together hides exactly the finding a
workforce map exists to show. A first draft of a midwifery access map
used an equal-interval bottom bin of 0.0-0.5 and so coloured 1,619 of
3,109 counties – over half the map – as "low" when the truth was "none".

## Usage

``` r
mysterymaps_jenks_zero_scale(
  n,
  k = 6,
  zero_col = "#e0e0e0",
  na_col = "#ffffff",
  na_label = "No data",
  palette = viridisLite::viridis,
  digits = NULL
)
```

## Arguments

- n:

  Numeric vector of values (counts or rates).

- k:

  Target number of classes for the positive values. Default 6.

- zero_col:

  Colour for zero. Default light grey.

- na_col:

  Colour for `NA` and `NaN`, which mean unmeasured rather than none.
  Default white. Pass `zero_col` to restore the pre-0.2.1 behaviour of
  shading unmeasured geographies as if they were zero.

- na_label:

  Legend entry for `na_col`. The entry is added only when the data
  actually contains `NA`, so legends do not gain an empty category.

- palette:

  Palette function taking `k`. Default
  [`viridisLite::viridis`](https://sjmgarnier.github.io/viridisLite/reference/viridis.html).

- digits:

  Decimal places for continuous labels; `NULL` gives integer count
  labels.

## Value

A list with `color` (a function mapping values to colours), `leg_cols`
and `leg_labs` for
[`leaflet::addLegend()`](https://rstudio.github.io/leaflet/reference/addLegend.html).

## Details

Jenks rather than equal intervals because provider rates are heavily
right-skewed; equal intervals put almost every county in the first bin.

## See also

Other coverage-surfaces:
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md),
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md),
[`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md),
[`mysterymaps_zoom_gated_labels()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_zoom_gated_labels.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  sc <- mysterymaps_jenks_zero_scale(counties$rate, k = 6, digits = 1)
  leaflet::addPolygons(map, fillColor = sc$color(counties$rate))
  leaflet::addLegend(map, colors = sc$leg_cols, labels = sc$leg_labs)
} # }
```
