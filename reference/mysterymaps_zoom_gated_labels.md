# Show point labels only where they are legible

Permanent tooltips on a large point layer are unreadable at national
zoom and essential at street zoom. This opens tooltips only for markers
currently in view, only at or above `min_zoom`, and only up to
`max_labels` of them.

## Usage

``` r
mysterymaps_zoom_gated_labels(map, group, min_zoom = 9, max_labels = 400)
```

## Arguments

- map:

  A leaflet map.

- group:

  Name of the marker group to label.

- min_zoom:

  Zoom at which labels appear. Default 9.

- max_labels:

  Cap on simultaneous labels. Default 400.

## Value

The leaflet map with the handler attached.

## Details

Marker clustering is the usual answer to a crowded point layer and is a
poor one: it replaces the data with a count and forces repeated zooming
before the reader learns anything. Drawing every point on a canvas
renderer and gating the *labels* keeps the distribution visible at every
zoom.

## See also

Other coverage-surfaces:
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md),
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md),
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
[`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md)
