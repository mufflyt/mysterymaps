# mysterymaps (development version)

## New: `mysterymaps_hex_bin_rate()`

Hex-bins a *rate* -- a point count over an areal-interpolated denominator --
productizing what building a Virginia urogynecologist-access map required
hand-rolling with `sf::st_interpolate_aw()` outside the package.
[`mysterymaps_hex_bin_counts()`](#new-mysterymaps_hex_bin_counts) was
deliberately left without this: a raw point count has no denominator to
divide by, and getting a second, spatially-different data source (e.g. tract
population) onto the same grid as the first is areal interpolation, not
point-counting.

Returns the full grid, including zero-count and zero-denominator cells, built
to feed `mysterymaps_jenks_zero_scale()` directly: a cell with real population
and zero points counted is a measured zero (`rate = 0`); a cell with no
interpolated population returns `rate = NA` -- 0/0 is undefined, not "below a
reporting floor" -- even when `min_denominator` is left at its default `0`.

## Compatible fix: `zero_aware` on `mysterymaps_geographic_map()` and `mysterymaps_map_acceptance_rate()`

Both functions shaded a per-state rate with a plain continuous
`scale_fill_viridis_c()`, which puts a state measured at zero at the same dark
end of the gradient as a merely-low rate -- the mistake
`mysterymaps_jenks_zero_scale()` exists to prevent, present in this package's
two *original* static-map functions, not only its new ones.

`mysterymaps_geographic_map()` has a confirmed real downstream caller
(`mufflyt/midwifery`'s `manuscript/midwife_persistence.qmd`, replayed by the
downstream-consumer nightly CI below), so the default could not simply change:
both functions gain an opt-in `zero_aware` argument, default `FALSE`, which
keeps every existing call byte-for-byte unchanged (verified by running the
actual downstream smoke-test scenarios against the modified package, not just
this package's own suite). Pass `zero_aware = TRUE` for a state measured at
zero to get `zero_color` instead of the gradient's dark end; `labels`
(`mysterymaps_geographic_map()`) and `limits` (`mysterymaps_map_acceptance_rate()`)
are ignored in that mode and warn if passed explicitly. The shared validation
for `zero_aware`/`k`/`digits`/`zero_color` moved to an internal, unexported
`mm_validate_zero_aware_args()` so the two functions' error messages cannot
drift the way this ecosystem's duplicated functions have drifted before.

## New: `mysterymaps_accessibility_map()`

One-call map for a `twostep::compute_e2sfca()` result: joins its `$access`
tibble onto tract geometry and keeps the three states that tibble already
distinguishes -- a measured zero (reached, weighted supply nil), outside every
modelled catchment (a real finding an access study usually exists to report,
not missing data), and genuinely missing -- instead of a plain continuous
scale that collapses them into two. Fixes a real edge case found while
building it: a `tracts_sf` polygon whose `GEOID` matches nothing in `$access`
produces `coverage_status = NA` from the join, which
`mysterymaps_jenks_zero_scale()` correctly refuses to guess at; such a polygon
is recoded to route through the ordinary missing-value path instead of being
silently dropped from the map. Does not depend on the `twostep` package --
only consumes the list shape its documentation describes returning.

## Bug fix: a zero rate or zero redundancy coloured as "low", not as zero

`mysterymaps_rate_choropleth_map()` and `mysterymaps_catchment_redundancy_map()`
shipped (below) with a plain continuous `scale_fill_viridis_c()` --
`log_scale`-transformed for the rate map, with a hand-written integer-breaks
helper for the redundancy map -- the same mistake
`mysterymaps_jenks_zero_scale()` was built to prevent, reintroduced in two
brand-new functions rather than an old one. A county with zero providers per
capita, or zero overlapping catchments -- "no option at all", the finding a
redundancy map exists to surface -- rendered at the dark end of the same
gradient as a merely-low rate or a single-provider catchment.

Both now classify with `mysterymaps_jenks_zero_scale()` instead.
`mysterymaps_rate_choropleth_map()` gains `k`, `digits`, `zero_color` and
`na_color`, and loses `log_scale`: natural-breaks classification already
handles the right-skew a log transform was compensating for, so the two no
longer need to coexist. `mysterymaps_catchment_redundancy_map()` gains `k`,
`zero_color` and `na_color` and drops its hand-written `integer_breaks()`
helper in favour of the scale's own whole-number labelling
(`digits = NULL`).

## Documentation

* 11 exported functions and constants -- the six new map-template functions
  below, `mysterymaps_hex_bin_counts()`, `mysterymaps_scale_bar()`,
  `mysterymaps_jitter_points()`, and two constants
  (`MYSTERYMAPS_BIVARIATE_PALETTE`, `MYSTERYMAPS_ISOCHRONE_BANDS_MINUTES`) --
  were documented but absent from `_pkgdown.yml`'s reference index, invisible
  on the package website. All added; `mysterymaps_hex_bin_counts()` (and now
  `mysterymaps_hex_bin_rate()`) get a new "Geospatial aggregation" section,
  since they fit no existing one honestly.
* 14 public functions had zero `@examples`. Added `@examplesIf interactive()`
  to each and executed all 14 against the built package -- not just read the
  code -- to confirm none are silently broken.
* The static-map and isochrones/overlap tables in the README were updated to
  mention all of the above.

## New: bivariate, cartogram, catchment-redundancy, flow, rate-choropleth, and pathway small-multiples maps; scale-bar and jitter helpers

Rounds out the map-construction toolkit beyond the county/HRR/physician-dot
templates:

* `mysterymaps_bivariate_choropleth_map()` -- joint tercile class of two
  variables (e.g. population need vs. provider scarcity) in one map, with a
  3x3 legend grid rendered as an inset.
* `mysterymaps_cartogram_map()` -- polygons warped radially around a hub by
  drive time instead of true area; deliberately not a true-area map.
* `mysterymaps_catchment_redundancy_map()` -- how many providers' drive-time
  catchments overlap each area, not just whether one does; the complement of
  a simple access map.
* `mysterymaps_flow_map()` -- pre-routed drive-time paths coloured by travel
  time, drawn over a basemap. Renders only; does not call a routing API.
* `mysterymaps_rate_choropleth_map()` -- a numerator/denominator rate
  choropleth, rather than a raw count that makes larger-population areas
  simply look darker.
* `mysterymaps_pathway_small_multiples_map()` -- facets a physician dot map
  by certification/training pathway, one panel each, plus an optional
  combined panel.
* `mysterymaps_scale_bar()` / `mysterymaps_jitter_points()` -- an
  imperial-unit scale bar (`ggspatial::annotation_scale()` defaults to
  kilometers, silently, through `...`-forwarding with no error either way)
  and deterministic, real-ground-distance point jitter. Both are shared
  furniture: `mysterymaps_physician_dot_map()` gains `jitter_miles`,
  `jitter_seed` and `outline` parameters built on the jitter helper so
  physicians stacked on the same building separate visually without
  run-to-run instability, and the small-multiples map above uses the same
  helper so a physician's dot sits at the same jittered position in every
  panel it appears in.

## New: `mysterymaps_hex_bin_counts()`

Exports the honeycomb-counting logic inside `mysterymaps_hrr_maps()` as a
standalone function usable on any boundary and any point dataset, not just
the HRR/physician workforce case -- the "bin points into hexagons, shade by
count" map. Defaults differ deliberately from the internal
`mm_honeycomb_counts()` it wraps: `min_count = 1` (no suppression) and
`southern_limit = -90` (no clipping), since those HRR-specific defaults would
silently drop single points or most of the Southern Hemisphere on a boundary
that is not the continental United States.

## New: downstream-consumer nightly CI

R-CMD-check, coverage, and Scientific Nightly all test this package against
itself; none of them could have caught `mysterymaps_geographic_map()`
shipping for months without the `labels` argument documented above, because
every existing test used the default percent formatter. A new nightly
workflow (`.github/workflows/downstream-consumer.yml`) installs the package
fresh from the commit under test and replays real call patterns lifted from
actual consumer code (`.github/scripts/downstream-smoke.R`), starting with
the two `mysterymaps_geographic_map()` calls from
`mufflyt/midwifery`'s `manuscript/midwife_persistence.qmd`. Verified against
the pre-`labels` commit: fails with the original "unused argument" error;
passes clean against the fix.

## New: `labels` parameter on `mysterymaps_geographic_map()`

The fill legend always used `scales::percent_format()`, correct only when
`outcome_col` is a proportion on `[0, 1]` -- an acceptance *rate*, which is
what the function was built for. A caller mapping a rate *per* something
(midwives per 1,000 births, cases per 100,000) got a legend that rendered
10.79 as `"1 000%"`. `labels` now takes a formatter function, passed straight
through to `ggplot2::scale_fill_viridis_c(labels = )`, defaulting to the
previous `scales::percent_format(accuracy = 1)` so existing callers are
unaffected.

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

## New: outside the modelled catchment is its own map class

`twostep::compute_e2sfca()` now distinguishes a tract inside a catchment whose
supply works out to zero from a tract no isochrone reaches, and emits a
`coverage_status` column saying which. `mysterymaps_jenks_zero_scale()` and
`mysterymaps_county_access_map()` can now consume it.

Three states arrive at the scale and all three are different:

* **measured zero** — inside a catchment, supply reaching it is zero. Takes
  `zero_col`, labelled `0`.
* **outside every catchment** — the model ran and no provider is reachable
  within the modelled drive time. Also a measurement, and usually the finding
  the map exists to report. Takes the new `outside_col`, labelled
  *No provider within the modelled drive time*.
* **missing** — the value is unknown: a suppressed denominator, a failed join.
  Takes `na_col`, labelled *No data*.

Pass `coverage` to the scale, or `coverage_col` to the template, as either the
character `coverage_status` or the logical `reached`. Without it the second and
third states collapse, because both arrive as `NA` — better than the older
behaviour, where the second arrived as `0` and was indistinguishable from the
first, but it still files a finding under "unknown".

On the Colorado subspecialty surface that second state is **190 of 1,447
tracts, 13% of the state**, and every one of them used to be shaded in the zero
class under a legend reading `0`.

Coverage cannot be inferred from the value — an outside geography and an
unmeasured one are both `NA` — so it has to travel as its own column. The scale
refuses to guess: an unrecognised status errors, a length mismatch errors, and
`color()` on a differently-sized vector errors rather than silently dropping the
class.

Nothing changes for callers who pass no coverage.

### Measured, on the frozen Colorado surface

Removing the 190 false zeros did **not** move the Jenks breaks: the six positive
classes are byte-identical and all 1,257 reached tracts keep exactly the fills
they had. The scale already excluded zeros from classification, so the false
zeros never entered the break computation — they only occupied the zero class.
Class membership changed; class boundaries did not.

One visible consequence: the legend still leads with a `0` entry that now
describes no tract at all, because the zero class is unconditional while the
no-data class is added only when needed. Left as-is here rather than widened
into an unrelated legend change.

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
