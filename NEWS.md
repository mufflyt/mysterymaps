# mysterymaps (development version)

## Bug fixes: `mysterymaps_jenks_zero_scale()`

Three defects found by adversarial tests, all reachable from ordinary county
data:

* **A single county with a nonzero rate aborted the map.** `classInt` errors
  with "single unique value" rather than returning one class, so a study area
  where exactly one county has providers — an ordinary rural result — failed
  instead of rendering. It now returns a single positive class.
* **Rates without `digits` aborted the map.** The count-label branch used
  `sprintf("%d")`, which errors on a fractional double, so passing rates and
  omitting `digits` errored out of the whole map rather than mislabelling one
  class. Labels now format according to the value.
* **Legends could claim impossible values.** When the class count reached the
  number of distinct values — which the function induced on itself — jenks
  returned breaks extrapolated past both ends of the data, producing a first
  class labelled `-1.6–2.2` for a rate with a floor of zero. The outer breaks
  are clamped to the observed range; no value changes class.

`NA` is also dropped before classification rather than being passed through and
omitted by `classInt`, which removes a spurious warning per map.

## Breaking: zero and `NA` are no longer the same colour

A county measured at zero has no providers; a county never measured is
unknown. Both used to render in `zero_col`, so the map could not tell them
apart — the same conflation this scale exists to prevent at the other end of
the ramp.

`NA` and `NaN` now take a new `na_col`, default white, with a `No data` legend
entry added **only when the data actually contains `NA`**, so complete maps
keep a two-part legend. `NaN` counts as unknown: it reaches a rate through a
zero denominator, which is unmeasurable rather than zero.

Two consequences for existing code:

* Published maps that contain `NA` geographies will change appearance. Pass
  `na_col = zero_col` to `mysterymaps_jenks_zero_scale()` to restore the old
  rendering.
* A hand-written `legend_labels` vector sized for the old legend is now one
  entry short whenever the data holds `NA`.
  `mysterymaps_county_access_map()` already errors with both counts rather
  than shifting every label.

## Fixed

* `mysterymaps_jenks_zero_scale()` no longer shades `Inf` as the top class. A
  rate reaches `Inf` by division by a zero denominator -- a county with no
  births, no population -- so it is the emptiest place on the map, not the
  fullest. Non-finite values now take `na_col` and gain the "No data" legend
  entry, alongside `NA` and `NaN`. `Inf` was already excluded from the Jenks
  breaks; only the colour was wrong.

## Breaking: a negative count or rate is refused

`mysterymaps_jenks_zero_scale()` used to absorb a negative value into the zero
class, so a county whose supply arrived as -3 rendered identically to a county
measured at zero and the legend labelled it `0`. That is the conflation the
scale exists to prevent, with an arithmetic error concealed inside it — and it
is the direction that inflates the apparent desert. No class on this scale
represents a negative supply honestly, so the map is no longer built. The error
names the count, the minimum and the first few positions.

Both the constructor and the `color()` it returns check, because they can be
handed different vectors: a scale built from every county and applied to one
state's subset would classify the national data cleanly and then colour a
negative on the second call, which is the harder half to notice.

`-Inf` now errors for the same reason rather than shading as no data. It is
unmeasurable *and* negative, and the negative complaint is the more specific.

If you are mapping a change between two periods, this scale was always the
wrong one — zero here is a distinguished floor category, not a midpoint — and
the error says so. Use a diverging scale.

## Fixed: the honeycomb map deleted Honolulu

`mysterymaps_hrr_maps()` filtered its provider counts with
`dplyr::filter(grid_id > 9546L)`, commented `# Filter out Palmyra Atoll`.
`grid_id` is `dplyr::row_number()` over `sf::st_make_grid()`, whose cells run
in **longitude** order across the bounding box — so the cut removed the 9,546
**westernmost** cells, whatever happened to be in them, and moved whenever
Natural Earth shipped a polygon with a different extent.

Measured against the current polygon (bbox 171.8°W–67.0°W, 18.9°N–71.4°N), the
cut removed **1,223 cells containing US land** — 1,214 in western Alaska, 9 in
Hawaii — among them **Honolulu, Kauai and Nome**. Palmyra Atoll is at 5.9°N,
outside that bounding box altogether, so the filter never once removed the
thing it named.

What it removed was every physician in Honolulu, from a function that calls
`mysterymaps_hrr(remove_HI_AK = FALSE)` two lines earlier to keep Hawaii
deliberately, and that draws a Hawaii inset. The inset rendered empty and read
as a workforce finding.

The exclusion is now geographic (`southern_limit`, default 15°N — below Ka Lae
at 18.9°N and above Palmyra), so it cannot drift with a data release. The
counting step is split into `mm_honeycomb_counts()`, because the figure is a
`gtable`: a cell losing every provider it holds was invisible to any assertion
about the output, which is how this survived. It also forces spherical geometry
off for its own work and restores it — clipping hexagons to a coastline leaves
slivers that s2 rejects, so the count previously worked only because its one
caller had switched s2 off a few lines earlier.

`min_count` is now a named argument rather than a bare `> 1`. The behaviour is
unchanged: a cell holding one provider is dropped and drawn exactly like a cell
holding none, which is a small-cell suppression decision and now says so.

## Fixed: areas were measured in whatever CRS the caller happened to use

`mysterymaps_guard_water_masks()` and the coverage-surface popups computed area
as `sf::st_area(x) / 1e6`, which is square kilometres only when the geometry's
CRS is in metres. Two independent failures followed, both producing a plausible
number:

* **The unit.** Several US state plane systems are in US survey feet. In
  EPSG:2232 (NAD83 / Colorado Central) a polygon of 147,582 km² measures
  1,588,550 — a factor of 10.76, with no warning, because the arithmetic is
  valid and only the unit is wrong.
* **The projection.** A conformal CRS preserves shape, not area. In EPSG:3857 —
  the default of every slippy map — the same polygon measures roughly 1.8× its
  true size, in metres, from a metre-declaring CRS. No unit conversion can
  detect that.

In the water-mask guard either one inverts the verdict. The guard divides a
mask's area by the state's census water area and excludes anything above
`max_ratio`; inflate the numerator and Michigan's legitimate Great Lakes mask
crosses the threshold, is excluded, the water clip never runs, and the coverage
surface spreads across the lakes — the failure the guard exists to prevent,
produced by the guard.

Both now measure geodesically on EPSG:4326 rather than in the caller's CRS, so
the answer is the same from lon/lat, Albers, Web Mercator, UTM and survey feet,
and is valid outside CONUS (the guard is handed Alaska and Hawaii). Spherical
geometry is forced on for the measurement and restored afterwards: with it off,
`sf` routes geodetic area through `lwgeom`, a Suggests absent on a bare runner,
so the measurement would have errored on exactly the machines with nothing
installed. Geometry carrying no CRS is refused by name instead of being assumed
to be in metres.

No user-facing behaviour changes for masks already supplied in lon/lat or in an
equal-area CRS in metres, which is every documented path.

# mysterymaps 0.2.0 (2026-08-09)

## New: the county access map template

* `mysterymaps_county_access_map()` assembles the map this ecosystem kept
  rebuilding — a supply choropleth, drive-time coverage surfaces as mutually
  exclusive base layers, a legend that follows the active layer, CONUS framing.
  Two studies had hand-built it separately, and the differences were bugs.
* `mysterymaps_notes_panel()` renders the collapsible caveat panel with a data
  vintage list, once, rather than repeating caveats in every popup.

## New: layers and controls

* `mysterymaps_add_coverage_surfaces()` adds any named list of polygon layers as
  base groups with their own legends. Coverage surfaces have no per-geography
  value, so the choropleth builders could not express them.
* `mysterymaps_base_legend_switcher()` and `mysterymaps_register_base_legend()`
  show only the active base layer's legend. **This fixes a real defect:**
  `leaflet::addLegend(group=)` follows *overlay* groups only and silently does
  nothing for `baseGroups`, so a map with four base layers rendered all four
  legends at once.
* `mysterymaps_zoom_gated_labels()` opens point tooltips only where they are
  legible — in view, above a zoom threshold, up to a cap. The alternative,
  marker clustering, replaces the data with a count.
* `mysterymaps_name_search()` now bundles the Leaflet-search plugin through
  `leaflet.extras` instead of loading it from a CDN. A saved self-contained
  widget previously had a search box that silently did nothing offline.
* `mysterymaps_gate_provider_coverage()` fails loudly when providers fall
  outside a coverage surface.

## New: scales and labels

* `mysterymaps_jenks_zero_scale()` moved here from the isochrones staging file
  and is now exported. Zero gets its own colour class; positive values get Jenks
  natural breaks, which suits right-skewed provider rates. An equal-interval
  bottom bin had rendered 1,619 of 3,109 counties as "low" when the truth was
  "none".
* `mysterymaps_pluralize()`, `mysterymaps_format_credentials()` and
  `mysterymaps_place_title_case()` for map labels. The credential helper formats
  and deliberately does not classify.

## Documentation

* First README, with figures generated by `data-raw/make_readme_figures.R` from
  the North Carolina counties shipped inside `sf` — no API key, no network, no
  private data. The leaflet figure is a screenshot of a real widget.
* `vignette("canonical-functions")` maps hand-rolled code to the canonical call
  that already exists across `mufflyaccess`, `twostep`, `mysterymaps` and
  `cliff`.
* `CITATION.cff`, `CITATION.bib` and `inst/CITATION` added so `citation()`,
  GitHub and reference managers agree.

## Fixes

* Removed five duplicate function definitions created when two sessions wrote
  the same helpers in parallel. Which one ran depended on the alphabetical order
  R sources `R/` in.
* Repaired `NAMESPACE`, which had silently stopped being roxygen-managed after a
  stray blank line displaced the generated-by marker from line 1.

# mysterymaps 0.1.0

* Initial release: isochrone generation via the HERE Routing API, state and HRR
  choropleths, ACOG district overlays, leaflet base maps, physician dot maps,
  and census block-group overlap.
