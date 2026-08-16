# County access map: choropleth, drive-time coverage, provider dots

The template behind the urogynecology and midwifery access maps.
Composes the pieces this package already provides – a zero-aware Jenks
scale, dissolved coverage surfaces, base-group legends, zoom-gated point
labels – and adds the furniture every such map needs: a name search and
a notes panel with source vintages.

## Usage

``` r
mysterymaps_county_access_map(
  counties,
  value_col,
  label_col,
  popup_col,
  coverage = list(),
  points = NULL,
  point_label_col = NULL,
  point_popup_col = NULL,
  coverage_colors = NULL,
  coverage_labels = NULL,
  coverage_titles = NULL,
  overlay_group = "Provider locations",
  coverage_area_units = c("km", "mi"),
  coverage_popups = TRUE,
  mesh = TRUE,
  legend_title = "Rate",
  jenks_k = 6L,
  jenks_digits = 1L,
  legend_labels = NULL,
  point_fill = "#c2185b",
  point_alpha = 0.55,
  search = "Search name...",
  notes = NULL,
  bounds = c(24.5, -125, 49.4, -66.9)
)
```

## Arguments

- counties:

  `sf`: county polygons.

- value_col:

  `character(1)`: column in `counties` to shade.

- label_col, popup_col:

  `character(1)`: columns holding hover and click HTML.

- coverage:

  `named list of sf`: dissolved drive-time bands, e.g.
  `list("Within 30 minutes" = iso30, "Within 60 minutes" = iso60)`.

- points:

  `sf|NULL`: provider locations.

- point_label_col, point_popup_col:

  `character(1)`: columns on `points`.

- coverage_colors, coverage_labels, coverage_titles:

  passed through to
  [`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md).
  Real maps carry a "beyond" band whose legend title differs from the
  "within" bands ("Coverage gap" rather than "Drive-time coverage"), so
  these are exposed rather than fixed.

- overlay_group:

  `character(1)|NULL`: name of the point overlay in the layers control.
  Defaults to "Provider locations". Passing `NULL` when the caller adds
  its own point layer afterwards used to emit an overlay literally
  labelled "null" in the control.

- coverage_area_units:

  `"km"` (default) or `"mi"`. Square miles for a US audience; the popup
  and the unit label change together so they cannot disagree.

- coverage_popups:

  `logical(1)`: attach a popup to each coverage band naming the band,
  its area and how many origins were dissolved into it.

- mesh:

  `logical(1)`: draw an unfilled county outline that stays visible under
  every base group. It carries no `group` deliberately: three
  group-bound copies triple the county geometry in the output file.

- legend_title:

  `character(1)`: choropleth legend heading.

- jenks_k:

  `integer(1)`: positive-class count for the scale.

- jenks_digits:

  `integer(1)`: decimals in the legend breaks. Use 0 when the quantity
  is a count of people: "0.2-2.6 midwives per 1,000 births" invites a
  reader to picture a fifth of a person.

- legend_labels:

  `character|NULL`: replace the computed break labels outright. Wording
  such as "none" for the zero class, or "under 5" where rounding would
  otherwise render the first positive class as "0-5" and make it look
  like the zero class, is a caller decision.

- point_fill, point_alpha:

  point styling. The default alpha is 0.55 because thousands of opaque
  dots read as a solid mass over metros and hide the choropleth beneath
  them.

- search:

  placeholder text for the name box, or `NULL` to omit it.

- notes:

  a list of arguments for
  [`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md),
  or `NULL`.

- bounds:

  numeric length-4 `c(lat_min, lng_min, lat_max, lng_max)`.

## Value

a leaflet map.

## Why a single canvas renderer

`preferCanvas = TRUE` is set on the map and NO custom pane is used for
the points. Giving markers their own high-zIndex pane creates a second
canvas element covering the whole map, and that element swallows every
click – including clicks on empty ground where no marker is drawn. On
the midwifery map this silently disabled all 3,109 county popups: they
existed in the HTML and never opened. Sharing one renderer lets leaflet
hit-test markers and polygons together.

## Zero is a class, not a low value

Shading runs through
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
which gives zero its own colour. Folding "no provider" into the bottom
bin of a continuous ramp reads as "few" and is the single most
misleading thing an access map can do.

## See also

Other county-access-template:
[`mysterymaps_gate_provider_coverage()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_gate_provider_coverage.md),
[`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md),
[`mysterymaps_name_search()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_name_search.md),
[`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
mysterymaps_county_access_map(
  counties = cty, value_col = "midwives_per_1k_births",
  label_col = "tooltip", popup_col = "profile",
  coverage = list("Within 30 minutes" = u30, "Within 60 minutes" = u60),
  points = mw, point_label_col = "full_name", point_popup_col = "popup",
  legend_title = "Midwives per<br/>1,000 births",
  notes = list(title = "Access to midwives, 2026 - notes",
               sections = list("County shading" = "is providers per 1,000 births."),
               vintages = data.frame(source = "AMCB roster", vintage = "2026"),
               as_of = "2026"))
} # }
```
