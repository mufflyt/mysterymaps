# Assert every provider falls inside the coverage surface built from them

A drive-time surface is dissolved from per-provider isochrones, so every
provider must lie inside it: a provider is always within 30 minutes of
themselves. Any who do not are providers whose isochrone is missing, and
the surface understates access by exactly that much.

## Usage

``` r
mysterymaps_gate_provider_coverage(
  providers,
  surface,
  label = "coverage",
  max_missing_pct = 0,
  group_col = NULL,
  on_fail = c("error", "warn")
)
```

## Arguments

- providers:

  `sf`: provider points.

- surface:

  `sf|sfc`: the dissolved coverage polygon(s).

- label:

  `character(1)`: band name for the message, e.g. "30-minute".

- max_missing_pct:

  `numeric(1)`: tolerated share outside, as a percentage. Defaults to 0
  – a provider outside their own isochrone is a defect, not a rounding
  error.

- group_col:

  `character(1)|NULL`: column to break the report down by (a state
  column makes a clustered failure obvious immediately).

- on_fail:

  `"error"` (default) or `"warn"`.

## Value

Invisibly a list with `n`, `n_outside`, `pct_outside` and, when
`group_col` is given, `by_group`.

## Details

This fails quietly without a gate. A missing isochrone does not error,
does not warn, and does not leave a hole you would notice – it simply
removes shading that should have been there, and the map still looks
plausible. On the midwifery access map 490 of 11,792 midwives sat
outside their own 30-minute surface, concentrated in Missouri (117),
Iowa (112) and Kansas (79). Clustered like that, the loss is not random:
it biases the coverage gap toward exactly the regions the map exists to
describe.

## See also

Other county-access-template:
[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md),
[`mysterymaps_name_search()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_name_search.md),
[`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md)
