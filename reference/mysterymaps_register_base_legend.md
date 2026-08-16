# Register a legend as belonging to a base group

Tags an already-added legend so
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md)
can show and hide it. Use for legends added outside
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md),
such as a choropleth legend that shares the layer control with coverage
surfaces.

## Usage

``` r
mysterymaps_register_base_legend(map, group, key = NULL)
```

## Arguments

- map:

  A leaflet map whose most recent legend should be tagged.

- group:

  Base group name the legend belongs to.

- key:

  Short CSS-safe key. Defaults to a slug of `group`.

## Value

The leaflet map with the mapping recorded.

## See also

Other coverage-surfaces:
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md),
[`mysterymaps_base_legend_switcher()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_base_legend_switcher.md),
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
[`mysterymaps_zoom_gated_labels()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_zoom_gated_labels.md)
