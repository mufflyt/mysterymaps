# Add a name-search box over a point layer

Wraps
[Leaflet.Control.Search](https://github.com/stefanocudini/leaflet-search)
so a reader can find one provider among thousands instead of hunting
dots.

## Usage

``` r
mysterymaps_name_search(
  map,
  group = NULL,
  placeholder = "Search name...",
  zoom = 11L,
  position = "topleft"
)
```

## Arguments

- map:

  a leaflet map.

- group:

  [character](https://rdrr.io/r/base/character.html) or NULL: marker
  groups to search. NULL detects them.

- placeholder:

  `character(1)`: text shown in the empty box.

- zoom:

  `integer(1)`: zoom level to fly to on a hit.

- position:

  `character(1)`: leaflet control position.

## Value

the map, with the control attached.

## Details

The plugin ships with `leaflet.extras` as a local HTML dependency, so a
self-contained widget stays self-contained. An earlier version loaded it
from a CDN to save a few hundred kilobytes in a 15-20 MB file; the cost
was that the search box was inert for anyone opening the saved map
offline, and a control that silently does nothing is worse than an
absent one. The size argument was real but small, and it was buying the
wrong thing.

## Which layers are searched

`group = NULL` reads the marker groups already added to the map. leaflet
stores the group name positionally in the widget call list – argument 5
for `addCircleMarkers` – which is undocumented, so the extraction is
validated and the control is skipped with a warning rather than attached
to nothing. Pass `group` explicitly to be certain, and to restrict the
search.

Markers must carry a `label`; that is the text searched.

## See also

Other county-access-template:
[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_gate_provider_coverage()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_gate_provider_coverage.md),
[`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md),
[`mysterymaps_notes_panel()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_notes_panel.md)
