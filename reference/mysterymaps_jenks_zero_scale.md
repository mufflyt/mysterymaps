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
  coverage = NULL,
  outside_col = "#efe7d5",
  outside_label = "No provider within the modelled drive time",
  palette = viridisLite::viridis,
  digits = NULL
)
```

## Arguments

- n:

  Numeric vector of non-negative values (counts or rates). A negative
  value is an upstream arithmetic error rather than a low value and is
  rejected; see the `Negative values` section.

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

- coverage:

  Optional per-geography coverage state, parallel to `n`. Accepts either
  shape `twostep::compute_e2sfca()` emits: the character
  `coverage_status` (`"within_modeled_catchment"` /
  `"outside_all_modeled_catchments"`) or the logical `reached`. When
  supplied, geographies outside every catchment get `outside_col` and
  their own legend entry instead of falling into the no-data class.

- outside_col:

  Colour for geographies outside every modelled catchment.

- outside_label:

  Legend entry for `outside_col`, added only when some geography is
  actually outside.

- palette:

  Palette function taking `k`. Default
  [`viridisLite::viridis`](https://sjmgarnier.github.io/viridisLite/reference/viridis.html).

- digits:

  Decimal places for continuous labels; `NULL` gives integer count
  labels.

## Value

A list with `color` (a function `color(x, coverage = NULL)` mapping
values to colours; the coverage given at construction is reused when `x`
is the same length), `leg_cols` and `leg_labs` for
[`leaflet::addLegend()`](https://rstudio.github.io/leaflet/reference/addLegend.html).

## Details

Jenks rather than equal intervals because provider rates are heavily
right-skewed; equal intervals put almost every county in the first bin.

## Outside the model is not missing data

Three states reach this scale and all three are different:

- measured zero:

  The geography is inside somebody's catchment and the supply reaching
  it works out to zero. A measurement. Takes `zero_col`.

- outside every catchment:

  The model ran and no provider is reachable within the modelled drive
  time. Also a measurement – usually the finding the map exists to
  report – and emphatically not a gap in the data. Takes `outside_col`,
  when `coverage` is supplied.

- missing:

  The value is unknown: a suppressed denominator, a failed join. Takes
  `na_col`.

Without `coverage` the second and third collapse, because both arrive as
`NA`. That is better than the older behaviour, in which the second
arrived as `0` and was indistinguishable from the first – 190 of 1,447
Colorado tracts on one subspecialty surface, 13% of the state, every one
shaded in the zero class under a legend reading `0`. But it still files
a finding under "unknown", so pass `coverage` whenever the producer
supplies it.

Coverage cannot be inferred from the value: an outside geography and an
unmeasured one are both `NA`, which is precisely why it has to travel
alongside as its own column.

## Negative values

A negative count or rate is rejected rather than coloured. It used to
take `zero_col`, so a county whose supply arrived as -3 rendered
identically to a county measured at zero and the legend labelled it `0`
– the same conflation this scale exists to prevent at the other end of
the ramp, with an arithmetic error concealed inside it. No class
represents a negative supply honestly, so the map is not built.

If the intent is to map a *change* between two periods, this scale is
the wrong one: zero here is a distinguished floor category, not a
midpoint, and a diverging scale is what a difference needs.

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
