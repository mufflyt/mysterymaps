# =============================================================================
# Coverage surfaces: area layers with no per-geography value
# =============================================================================
# Choropleths answer "what is this county's number?". A dissolved coverage
# surface -- a drive-time isochrone union, a service area, a catchment --
# answers "is this ground covered?", and has no per-geography value to
# classify. The package's choropleth builders cannot express it, so these
# helpers do.
#
# They were written for a midwifery drive-time access map and are deliberately
# free of that study: any named list of polygon layers works.
# =============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' Add dissolved coverage surfaces as mutually exclusive base layers
#'
#' @description
#' Adds one or more area-coverage surfaces (drive-time isochrone unions,
#' service areas, catchments) to a leaflet map as `baseGroups`, each with its
#' own legend. Unlike [mysterymaps_map_leaflet()] and
#' [mysterymaps_map_physicians()], the surfaces carry no per-geography value: a
#' dissolved union answers "is this ground covered?", not "what is this
#' county's number?", so there is nothing to classify or bin.
#'
#' @details
#' - **Pipeline step:** Presentation (map assembly)
#' - **Why base groups:** stacking translucent surfaces over a choropleth
#'   multiplies two colour scales and yields a third that belongs to neither.
#'   Coverage layers are alternative views of the same map, not additions to it.
#' - **Legends:** registered with [mysterymaps_base_legend_switcher()], which is required
#'   because `leaflet::addLegend(group=)` follows overlay groups only.
#'
#' @param map A leaflet map.
#' @param surfaces Named list of `sf` polygon objects; names become group names.
#' @param colors Character vector of fills, recycled to `length(surfaces)`.
#' @param legend_labels Character vector, one legend line per surface.
#' @param legend_titles Character vector of legend titles, recycled.
#' @param fill_opacity Numeric fill opacity. Default 0.55.
#' @param weight Outline weight. Default 0.6.
#' @return The leaflet map, with a `mysterymaps_base_legends` attribute mapping group
#'   names to legend CSS keys, for [mysterymaps_base_legend_switcher()].
#' @examples
#' \dontrun{
#'   m <- mysterymaps_add_coverage_surfaces(
#'     m, list("Within 30 minutes" = u30, "Within 60 minutes" = u60),
#'     colors = c("#08519c", "#3182bd"),
#'     legend_labels = c("within 30 min", "within 60 min"))
#' }
#' @family coverage-surfaces
#' @export
mysterymaps_add_coverage_surfaces <- function(map, surfaces, colors,
                                     legend_labels = names(surfaces),
                                     legend_titles = "Coverage",
                                     fill_opacity = 0.55, weight = 0.6) {
  stopifnot(is.list(surfaces), length(surfaces) > 0, !is.null(names(surfaces)))
  n <- length(surfaces)
  colors        <- rep_len(colors, n)
  legend_labels <- rep_len(legend_labels, n)
  legend_titles <- rep_len(legend_titles, n)
  keys <- paste0("s", seq_len(n))

  for (i in seq_len(n)) {
    map <- leaflet::addPolygons(
      map, data = surfaces[[i]], group = names(surfaces)[i],
      fillColor = colors[i], color = colors[i],
      weight = weight, fillOpacity = fill_opacity)
    map <- leaflet::addLegend(
      map, position = "bottomright", colors = colors[i],
      labels = legend_labels[i], title = legend_titles[i], opacity = 0.9,
      className = paste("info legend mm-lg", paste0("mm-lg-", keys[i])))
  }
  prev <- attr(map, "mysterymaps_base_legends") %||% list()
  attr(map, "mysterymaps_base_legends") <- utils::modifyList(
    prev, stats::setNames(as.list(keys), names(surfaces)))
  map
}

#' Register a legend as belonging to a base group
#'
#' Tags an already-added legend so [mysterymaps_base_legend_switcher()] can show and hide
#' it. Use for legends added outside [mysterymaps_add_coverage_surfaces()], such as a
#' choropleth legend that shares the layer control with coverage surfaces.
#'
#' @param map A leaflet map whose most recent legend should be tagged.
#' @param group Base group name the legend belongs to.
#' @param key Short CSS-safe key. Defaults to a slug of `group`.
#' @return The leaflet map with the mapping recorded.
#' @family coverage-surfaces
#' @export
mysterymaps_register_base_legend <- function(map, group, key = NULL) {
  key <- key %||% tolower(stringr::str_replace_all(group, "[^A-Za-z0-9]", ""))
  prev <- attr(map, "mysterymaps_base_legends") %||% list()
  attr(map, "mysterymaps_base_legends") <- utils::modifyList(
    prev, stats::setNames(list(key), group))
  map
}

#' Show only the active base layer's legend
#'
#' @description
#' `leaflet::addLegend(group=)` hides and shows a legend with its **overlay**
#' group; it does nothing for `baseGroups`. A map with several base layers, each
#' with a legend, therefore renders every legend at once, stacked down the
#' edge. This attaches a `baselayerchange` handler that displays only the legend
#' belonging to the active base layer.
#'
#' @details
#' Legends must carry class `mm-lg` plus `mm-lg-<key>`;
#' [mysterymaps_add_coverage_surfaces()] and [mysterymaps_register_base_legend()] do that. The
#' handler is defensive: a base group with no registered legend simply leaves
#' the legends hidden rather than erroring.
#'
#' @param map A leaflet map carrying an `mysterymaps_base_legends` attribute.
#' @param default Base group whose legend shows on load. Defaults to the first
#'   registered group.
#' @return The leaflet map with the handler attached.
#' @family coverage-surfaces
#' @export
mysterymaps_base_legend_switcher <- function(map, default = NULL) {
  reg <- attr(map, "mysterymaps_base_legends")
  if (is.null(reg) || !length(reg)) return(map)
  default <- default %||% names(reg)[1]
  js <- sprintf('
function(el, x) {
  var map = this, REG = %s, DEF = %s;
  function show(k) {
    el.querySelectorAll(".mm-lg").forEach(function(n){ n.style.display = "none"; });
    if (k == null) return;
    var t = el.querySelector(".mm-lg-" + k);
    if (t) t.style.display = "";
  }
  show(REG[DEF]);
  map.on("baselayerchange", function(e) { show(REG[e.name]); });
}',
    jsonlite::toJSON(reg, auto_unbox = TRUE),
    jsonlite::toJSON(default, auto_unbox = TRUE))
  htmlwidgets::onRender(map, js)
}

#' Show point labels only where they are legible
#'
#' @description
#' Permanent tooltips on a large point layer are unreadable at national zoom and
#' essential at street zoom. This opens tooltips only for markers currently in
#' view, only at or above `min_zoom`, and only up to `max_labels` of them.
#'
#' @details
#' Marker clustering is the usual answer to a crowded point layer and is a poor
#' one: it replaces the data with a count and forces repeated zooming before the
#' reader learns anything. Drawing every point on a canvas renderer and gating
#' the *labels* keeps the distribution visible at every zoom.
#'
#' @param map A leaflet map.
#' @param group Name of the marker group to label.
#' @param min_zoom Zoom at which labels appear. Default 9.
#' @param max_labels Cap on simultaneous labels. Default 400.
#' @return The leaflet map with the handler attached.
#' @family coverage-surfaces
#' @export
mysterymaps_zoom_gated_labels <- function(map, group, min_zoom = 9, max_labels = 400) {
  js <- sprintf('
function(el, x) {
  var map = this, GRP = %s, MINZ = %d, CAP = %d, shown = [];
  function refresh() {
    var g;
    try { g = map.layerManager.getLayerGroup(GRP); } catch (err) { return; }
    if (!g) return;
    shown.forEach(function(l){ try { l.closeTooltip(); } catch (e) {} });
    shown = [];
    if (map.getZoom() < MINZ) return;
    var b = map.getBounds(), n = 0;
    g.eachLayer(function(l) {
      if (n >= CAP || !l.getLatLng) return;
      if (b.contains(l.getLatLng())) {
        try { l.openTooltip(); shown.push(l); n++; } catch (e) {}
      }
    });
  }
  map.on("zoomend moveend layeradd", refresh);
  refresh();
}', jsonlite::toJSON(group, auto_unbox = TRUE), as.integer(min_zoom),
    as.integer(max_labels))
  htmlwidgets::onRender(map, js)
}

