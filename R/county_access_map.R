#' County choropleth with drive-time coverage surfaces
#'
#' @description
#' Assembles the map shape this ecosystem keeps rebuilding: a county choropleth
#' of a supply measure, one or more dissolved drive-time surfaces as mutually
#' exclusive alternatives to it, a legend that follows the active layer, and
#' CONUS framing. The midwifery access map and the urogyn county map each
#' hand-built this separately before it lived here.
#'
#' @details
#' What the template owns, so callers stop re-deriving it:
#' \itemize{
#'   \item canvas rendering (`preferCanvas`), which large point layers need;
#'   \item a `"pts"` map pane at `zIndex` 650, so markers added afterwards
#'     hit-test above the choropleth instead of the polygon swallowing clicks;
#'   \item an imperial scale bar bottom-left, leaving bottom-right for legends;
#'   \item [mysterymaps_jenks_zero_scale()], so zero is its own class rather
#'     than the bottom of a gradient;
#'   \item a single always-on county mesh under the coverage layers — binding
#'     one copy per group triples the geometry in the HTML;
#'   \item base-group legends via [mysterymaps_add_coverage_surfaces()] and
#'     [mysterymaps_base_legend_switcher()], because
#'     `leaflet::addLegend(group=)` silently does nothing for `baseGroups`;
#'   \item label tiles drawn last, so place names sit above the fills.
#' }
#'
#' The caller supplies data and vocabulary. Anything map-specific — a notes
#' panel, per-point popups, zoom-gated labels — is added to the returned widget
#' afterwards.
#'
#' @param counties `sf`: polygons carrying the value, label and popup columns.
#' @param value_col `character(1)`: numeric column driving the choropleth.
#' @param label_col,popup_col `character(1)`: character columns of pre-rendered
#'   HTML for hover and click. `NULL` to omit either.
#' @param coverage Named `list` of `sf` coverage surfaces; names become layer
#'   names. `NULL` for a choropleth-only map.
#' @param coverage_colors,coverage_labels,coverage_titles `character`: passed
#'   through to [mysterymaps_add_coverage_surfaces()].
#' @param points `sf`/`data.frame` or `NULL`: markers to add inside the
#'   template. Usually `NULL` — add them afterwards when they need their own
#'   popups.
#' @param point_group `character(1)`: group name used when `points` is given.
#' @param legend_title `character(1)`: choropleth legend title; may contain HTML.
#' @param value_group `character(1)`: layer name for the choropleth. Defaults to
#'   `legend_title` with tags stripped.
#' @param search,notes Reserved for callers that pass them; `NULL` skips.
#' @param bounds `numeric(4)`: `c(lat_min, lng_min, lat_max, lng_max)`.
#' @param jenks_k `integer(1)`: classes for the positive values. Default 6.
#' @param zero_label `character(1)`: legend text for the zero class.
#' @return A leaflet widget.
#' @family map-templates
#' @export
mysterymaps_county_access_map <- function(counties,
                                          value_col,
                                          label_col = NULL,
                                          popup_col = NULL,
                                          coverage = NULL,
                                          coverage_colors = NULL,
                                          coverage_labels = NULL,
                                          coverage_titles = "Coverage",
                                          points = NULL,
                                          point_group = "Points",
                                          legend_title = value_col,
                                          value_group = NULL,
                                          search = NULL,
                                          notes = NULL,
                                          bounds = c(24.5, -125, 49.4, -66.9),
                                          jenks_k = 6,
                                          zero_label = "none") {
  if (!inherits(counties, "sf"))
    stop("`counties` must be an sf object.", call. = FALSE)
  if (!value_col %in% names(counties))
    stop("`value_col` '", value_col, "' is not a column of `counties`.",
         call. = FALSE)

  value_group <- value_group %||% trimws(gsub("<[^>]+>", " ", legend_title))
  vals <- counties[[value_col]]

  sc <- mysterymaps_jenks_zero_scale(vals, k = jenks_k, digits = 1)
  if (!is.null(zero_label)) sc$leg_labs[1] <- zero_label

  m <- leaflet::leaflet(options = leaflet::leafletOptions(
    minZoom = 3, maxZoom = 14, zoomControl = TRUE, preferCanvas = TRUE)) |>
    leaflet::addProviderTiles("CartoDB.PositronNoLabels", group = "base") |>
    leaflet::addScaleBar(position = "bottomleft",
                         options = leaflet::scaleBarOptions(imperial = TRUE)) |>
    leaflet::addMapPane("pts", zIndex = 650)

  m <- leaflet::addPolygons(
    m, data = counties, fillColor = sc$color(vals), fillOpacity = 0.85,
    color = "#ffffff", weight = 0.4, smoothFactor = 0.5,
    label = if (!is.null(label_col))
      lapply(counties[[label_col]], htmltools::HTML) else NULL,
    popup = if (!is.null(popup_col)) counties[[popup_col]] else NULL,
    popupOptions = leaflet::popupOptions(maxWidth = 360),
    highlightOptions = leaflet::highlightOptions(
      weight = 2, color = "#111", fillOpacity = 0.95, bringToFront = TRUE),
    group = value_group)

  # One mesh, no group: leaflet keeps it under every base group. Adding a copy
  # per group is the obvious approach and triples the county geometry in the
  # output file.
  m <- leaflet::addPolygons(m, data = sf::st_geometry(counties), fill = FALSE,
                            color = "#c0c0c0", weight = 0.3)

  m <- leaflet::addLegend(
    m, position = "bottomright", colors = sc$leg_cols, labels = sc$leg_labs,
    title = legend_title, opacity = 0.9,
    className = "info legend mm-lg mm-lg-value")
  m <- mysterymaps_register_base_legend(m, value_group, key = "value")

  if (!is.null(coverage) && length(coverage)) {
    m <- mysterymaps_add_coverage_surfaces(
      m, surfaces = coverage, colors = coverage_colors,
      legend_labels = coverage_labels %||% names(coverage),
      legend_titles = coverage_titles)
  }

  if (!is.null(points)) {
    m <- leaflet::addCircleMarkers(
      m, data = points, radius = 4, stroke = TRUE, weight = 1,
      color = "#ffffff", fillColor = "#c2185b", fillOpacity = 0.9,
      options = leaflet::pathOptions(pane = "pts"), group = point_group)
  }

  # Labels last so place names sit above the fills.
  m <- leaflet::addProviderTiles(m, "CartoDB.PositronOnlyLabels", group = "base")

  base_groups <- c(value_group, names(coverage))
  m <- leaflet::addLayersControl(
    m, baseGroups = base_groups,
    overlayGroups = if (!is.null(points)) point_group else NULL,
    options = leaflet::layersControlOptions(collapsed = FALSE))

  m <- mysterymaps_base_legend_switcher(m, default = value_group)
  m <- leaflet::fitBounds(m, bounds[2], bounds[1], bounds[4], bounds[3])
  m
}
