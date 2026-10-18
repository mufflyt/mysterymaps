# Multi-geography "closest provider" access choropleth, with full control panel

Same idea as
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md)
but for SEVERAL geographies switchable in one map (e.g. county AND
congressional district). Each geography contributes a drive-time
shading, a supply shading, an optional coverage shading, a legend set, a
hover-labelled access-desert overlay, and click-to-highlight; providers
and the search box are shared across every geography. A collapsible
control panel (top right) drives geography/metric/basemap selection, an
optional zoom-to-ZIP box, a reset-to-CONUS button, geolocate, print, and
a worst-access quick-list; state round-trips through the URL hash for
shareable links.

## Usage

``` r
mysterymaps_access_choropleth_map_multi(
  geos,
  providers,
  highlight_lookup,
  band_colors,
  band_labels,
  title_html,
  base_tiles = "CartoDB.Positron",
  dark_tiles = "CartoDB.DarkMatter",
  provider_fill = "#3b0a45",
  coverage_by_geo = NULL,
  band_counts_by_geo = NULL,
  centroids_by_geo = NULL,
  worst_by_geo = NULL,
  iso_union = NULL,
  zip_centroids = NULL,
  conus_bounds = c(-125, 24.4, -66.9, 49.4),
  provider_noun = "provider",
  aria_label = NULL,
  desert_tooltip = NULL,
  coverage_metric_label = NULL,
  centroid_label = "Analysis point"
)
```

## Arguments

- geos:

  Named list; each element a list with `sf` (carrying the `mm_*` columns
  documented in
  [`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md),
  plus optional `mm_fill_coverage`, `mm_hover`, `mm_hover_supply`,
  `mm_hover_coverage`), `supply_pal`, `supply_values`, and optional
  `time_legend`, `supply_legend`, `coverage_pal`, `coverage_values`,
  `coverage_legend`, `desert`. Names become the geography labels shown
  in the control panel. The first geography is shown by default.

- providers:

  `sf` POINTs (`mm_id`, `mm_label`, `mm_popup`), shared across every
  geography.

- highlight_lookup:

  Named list merging every geography's geo-id -\> provider-id vectors
  (ids must be unique across geographies).

- band_colors, band_labels, title_html, base_tiles:

  As in
  [`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md).

- dark_tiles:

  `character(1)`: provider-tile name for the dark basemap option.
  Default `"CartoDB.DarkMatter"`, toggled from the control panel's
  Basemap switch.

- provider_fill:

  Fill colour (or a leaflet formula, e.g. `~mm_fill`) for the shared
  provider markers.

- coverage_by_geo:

  Optional named list (geography name -\> HTML string); the control
  panel shows the entry for the active geography and updates it when the
  geography changes.

- band_counts_by_geo:

  Optional named list (geography name -\> integer vector aligned to
  `band_labels`); appended as counts to the drive-time legend for that
  geography.

- centroids_by_geo:

  Optional named list (geography name -\> `sf` POINTs); each geography's
  scoring anchor point, shown as an optional overlay toggle. Makes the
  aggregation explicit – e.g. why a large district reads a slow band
  even with a provider inside it, when the anchor point sits elsewhere.

- worst_by_geo:

  Optional named list (geography name -\> data frame with `label`,
  `lat`, `lon`, optional `note`); rendered as a click-to-zoom "worst
  access" quick-list in the control panel.

- iso_union:

  Optional `sf` with a `band` column: nested drive-time union polygons
  (any set of bands; drawn widest-first, in descending `band` order),
  toggled as an "Isochrone reach" overlay. `NULL` omits it.

- zip_centroids:

  Optional data frame with `zip`, `lat`, `lon` columns; powers the
  client-side zoom-to-ZIP box (embedded as a compact lookup, no external
  geocoder). `NULL` hides the box.

- conus_bounds:

  Numeric `c(west, south, east, north)` used for the initial frame and
  the reset-view button (default lower-48).

- provider_noun:

  `character(1)`: singular noun for what a provider is, used in the
  isochrone-band labels (e.g.
  `"Reachable within 30 min of a <provider_noun>"`). Default
  `"provider"`. A caller mapping a specific specialty passes e.g.
  `"urogynecologist"`.

- aria_label:

  `character(1)` or `NULL`: the map container's `aria-label`, for
  assistive tech. Default `NULL`, which falls back to
  `sprintf("Interactive map of access to %ss", provider_noun)`.

- desert_tooltip:

  `character(1)` or `NULL`: tooltip text on the no-access legend swatch.
  Default `NULL`, which falls back to
  `sprintf("purple outline = no %s in range", provider_noun)`.

- coverage_metric_label:

  `character(1)` or `NULL`: label for the "Shade by: coverage" radio
  button, shown only when a geography carries `mm_fill_coverage`.
  Default `NULL`, which falls back to `"Coverage"`.

- centroid_label:

  `character(1)`: heading used for the `centroids_by_geo` toggle and its
  marker popups. Default `"Analysis point"`.

## Value

A `leaflet` htmlwidget.

## A sibling, not a duplicate, of [`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md)

See the section of the same name on
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md)
– this function is the multi-geography extension of that one, not a
third, competing template.

## See also

[`mysterymaps_county_access_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_county_access_map.md),
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md)

Other mapping:
[`mysterymaps_access_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_access_choropleth_map.md),
[`mysterymaps_accessibility_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_accessibility_map.md),
[`mysterymaps_aggregate_values_to_polygons()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_aggregate_values_to_polygons.md),
[`mysterymaps_bivariate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_bivariate_choropleth_map.md),
[`mysterymaps_cartogram_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_cartogram_map.md),
[`mysterymaps_catchment_redundancy_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_catchment_redundancy_map.md),
[`mysterymaps_choropleth_point_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_choropleth_point_map.md),
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_count_points_in_polygons()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_count_points_in_polygons.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_flow_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_flow_map.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_pathway_small_multiples_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pathway_small_multiples_map.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md),
[`mysterymaps_rate_choropleth_map()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_rate_choropleth_map.md),
[`mysterymaps_scale_bar()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_scale_bar.md)
