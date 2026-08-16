# Add dissolved coverage surfaces as mutually exclusive base layers

Adds one or more area-coverage surfaces (drive-time isochrone unions,
service areas, catchments) to a leaflet map as `baseGroups`, each with
its own legend. Unlike
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md)
and
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
the surfaces carry no per-geography value: a dissolved union answers "is
this ground covered?", not "what is this county's number?", so there is
nothing to classify or bin.

## Usage

``` r
mysterymaps_add_coverage_surfaces(
  map,
  surfaces,
  colors,
  legend_labels = names(surfaces),
  legend_titles = "Coverage",
  fill_opacity = 0.55,
  weight = 0.6,
  popups = NULL
)
```

## Arguments

- map:

  A leaflet map.

- surfaces:

  Named list of `sf` polygon objects; names become group names.

- colors:

  Character vector of fills, recycled to `length(surfaces)`.

- legend_labels:

  Character vector, one legend line per surface.

- legend_titles:

  Character vector of legend titles, recycled.

- fill_opacity:

  Numeric fill opacity. Default 0.55.

- weight:

  Outline weight. Default 0.6.

- popups:

  Character vector of popup HTML, one per surface, or `NULL` for no
  popups.

## Value

The leaflet map, with a `mysterymaps_base_legends` attribute mapping
group names to legend CSS keys, for
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md).

## Details

- **Pipeline step:** Presentation (map assembly)

- **Why base groups:** stacking translucent surfaces over a choropleth
  multiplies two colour scales and yields a third that belongs to
  neither. Coverage layers are alternative views of the same map, not
  additions to it.

- **Legends:** registered with
  [`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md),
  which is required because `leaflet::addLegend(group=)` follows overlay
  groups only.

## See also

Other coverage-surfaces:
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md),
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
[`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md),
[`mysterymaps_zoom_gated_labels()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_zoom_gated_labels.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  m <- mysterymaps_add_coverage_surfaces(
    m, list("Within 30 minutes" = u30, "Within 60 minutes" = u60),
    colors = c("#08519c", "#3182bd"),
    legend_labels = c("within 30 min", "within 60 min"))
} # }
```
