# Build a collapsible notes panel with a data-vintage list

Every access map needs the same footnote furniture: what the shading
means, what a blank county means, and when each source was current. This
renders it as one collapsed panel rather than repeating caveats in every
popup.

## Usage

``` r
mysterymaps_notes_panel(
  map,
  title,
  sections,
  vintages,
  as_of = NULL,
  max_height = "44vh",
  bottom = "52px"
)
```

## Arguments

- map:

  a leaflet map.

- title:

  `character(1)`: panel heading; the year belongs here.

- sections:

  `named list`: heading -\> HTML paragraph.

- vintages:

  `data.frame`: columns `source` and `vintage`; optional `url` renders
  the source name as a link.

- as_of:

  `character(1)`: the "Data as of" line, e.g. the roster year.

- max_height:

  `character(1)`: CSS max-height so the panel never covers the map.

- bottom:

  `character(1)`: CSS offset; the default clears a bottom-left scale
  bar, which otherwise draws underneath the panel.

## Value

the map, with the panel attached.

## Details

A caveat repeated per feature is a caveat the reader stops seeing. On
the midwifery map the sentence "which reflects roster, linkage and
geocoding coverage as much as who practises here" fired on 1,801 county
popups, so the map spent its ink telling the reader not to trust it. It
belongs here, once.

`vintages` is deliberately required rather than optional. A map whose
sources span 2013 to 2026 and says only "2026" is asserting a currency
it does not have, and the year in the title is always the freshest
input, never the oldest.

## See also

Other county-access-template:
[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_gate_provider_coverage()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_gate_provider_coverage.md),
[`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md),
[`mysterymaps_name_search()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_name_search.md)
