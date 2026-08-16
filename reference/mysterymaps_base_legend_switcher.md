# Show only the active base layer's legend

`leaflet::addLegend(group=)` hides and shows a legend with its
**overlay** group; it does nothing for `baseGroups`. A map with several
base layers, each with a legend, therefore renders every legend at once,
stacked down the edge. This attaches a `baselayerchange` handler that
displays only the legend belonging to the active base layer.

## Usage

``` r
mysterymaps_base_legend_switcher(map, default = NULL)
```

## Arguments

- map:

  A leaflet map carrying an `mysterymaps_base_legends` attribute.

- default:

  Base group whose legend shows on load. Defaults to the first
  registered group.

## Value

The leaflet map with the handler attached.

## Details

Legends must carry class `mm-lg` plus `mm-lg-<key>`;
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md)
and
[`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md)
do that. The handler is defensive: a base group with no registered
legend simply leaves the legends hidden rather than erroring.

## See also

Other coverage-surfaces:
[`mysterymaps_add_coverage_surfaces()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_add_coverage_surfaces.md),
[`mysterymaps_jenks_zero_scale()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jenks_zero_scale.md),
[`mysterymaps_register_base_legend()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_register_base_legend.md),
[`mysterymaps_zoom_gated_labels()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_zoom_gated_labels.md)
