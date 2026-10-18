#' Multi-layer choropleth + point Leaflet map, switchable by base layer
#'
#' @description
#' Generic builder: several toggleable choropleth base groups (radio buttons),
#' a point overlay with name search, a scale bar, a per-layer legend that
#' swaps with the active base layer, and an optional title card and footnote.
#' Each layer is coloured with [mysterymaps_jenks_zero_scale()], so a `0`
#' count always gets its own colour rather than the bottom of a gradient.
#'
#' @details
#' Points render in their own [leaflet::addMapPane()] above the choropleth
#' (`zIndex = 650`) so they stay clickable over a dark fill, without the
#' custom-pane hit-testing hazard documented on
#' [mysterymaps_physician_dot_map()] -- that hazard is for a pane with a
#' dedicated *canvas renderer*; this pane shares the map's default renderer.
#'
#' @param layers Named list of `sf` polygon layers. Each must carry `id`, the
#'   count column (`value_col`), a `label` column (hover HTML) and a `popup`
#'   column (click HTML). The list order sets the radio order; `default_layer`
#'   is shown first.
#' @param points `sf` point layer with `label` and `popup` columns.
#' @param value_col `character(1)`: count column used for colouring each
#'   layer. Default `"n"`.
#' @param point_fill `character(1)`: fill colour for the point markers.
#' @param point_legend Optional `list(colors=, labels=, title=)` for a
#'   separate point legend (top-right).
#' @param legend_title_fmt `sprintf()` template taking the layer name, used
#'   as each choropleth legend's title (may contain HTML).
#' @param title_html Optional HTML for a top-left title card.
#' @param footnote_html Optional HTML rendered as a caption (bottom-left).
#' @param search_group `character(1)`: group name for the searchable point
#'   layer.
#' @param search_placeholder `character(1)`: placeholder text for the search
#'   box.
#' @param default_layer `character(1)`: which layer is shown on load. Default
#'   the first name in `layers`.
#' @param jenks_k `integer(1)`: positive-class count passed to
#'   [mysterymaps_jenks_zero_scale()] for every layer.
#' @param fill_opacity `numeric(1)`: polygon fill alpha. Default `0.90`.
#' @param point_radius `numeric(1)`: circle-marker radius in px. Default `6`.
#' @return A `leaflet` htmlwidget.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   id = 1:2, n = c(0, 4), label = c("A", "B"), popup = c("<b>A</b>", "<b>B</b>"),
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
#'     sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
#'     crs = 4326))
#' points <- sf::st_as_sf(
#'   data.frame(lon = -97, lat = 40, label = "Provider", popup = "<b>Provider</b>"),
#'   coords = c("lon", "lat"), crs = 4326)
#' mysterymaps_choropleth_point_map(list(Count = counties), points, point_fill = "#c2185b")
mysterymaps_choropleth_point_map <- function(layers, points,
                                             value_col = "n",
                                             point_fill,
                                             point_legend = NULL,
                                             legend_title_fmt = "Count per %s",
                                             title_html = NULL,
                                             footnote_html = NULL,
                                             search_group = "Points",
                                             search_placeholder = "Search...",
                                             default_layer = names(layers)[1],
                                             jenks_k = 6,
                                             fill_opacity = 0.90,
                                             point_radius = 6) {
  for (pkg in c("sf", "leaflet", "leaflet.extras", "htmltools", "htmlwidgets")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_choropleth_point_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_list(layers, types = "sf", names = "unique")
  checkmate::assert_class(points, "sf")
  checkmate::assert_string(value_col)
  checkmate::assert_string(point_fill)
  checkmate::assert_string(search_group)
  checkmate::assert_choice(default_layer, names(layers))
  checkmate::assert_int(jenks_k, lower = 1L)
  checkmate::assert_number(fill_opacity, lower = 0, upper = 1)
  checkmate::assert_number(point_radius, lower = 0)

  tok <- function(x) stringr::str_replace_all(x, "[^A-Za-z]", "")
  group_names <- names(layers)

  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron, group = "basemap") |>
    leaflet::setView(lng = -96, lat = 38, zoom = 4) |>
    leaflet::addScaleBar(position = "bottomleft",
                         options = leaflet::scaleBarOptions(imperial = TRUE)) |>
    # Points render + hit-test ABOVE the choropleth so dots stay clickable.
    leaflet::addMapPane("pts", zIndex = 650)

  for (nm in group_names) {
    poly <- layers[[nm]]
    sc   <- mysterymaps_jenks_zero_scale(poly[[value_col]], k = jenks_k)
    m <- m |>
      leaflet::addPolygons(
        data = poly, group = nm,
        fillColor = sc$color(poly[[value_col]]), fillOpacity = fill_opacity,
        color = "#ffffff", weight = 0.4, smoothFactor = 0.5,
        label = lapply(poly$label, htmltools::HTML),
        popup = poly$popup,
        highlightOptions = leaflet::highlightOptions(
          weight = 2, color = "#222", fillOpacity = 0.97, bringToFront = TRUE)
      ) |>
      leaflet::addLegend(
        position = "bottomright", colors = sc$leg_cols, labels = sc$leg_labs,
        title = sprintf(legend_title_fmt, nm), opacity = 0.9,
        className = paste0("info legend leg leg-", tok(nm)))
  }

  m <- m |>
    leaflet::addCircleMarkers(
      data = points, group = search_group,
      radius = point_radius, stroke = TRUE, weight = 1.2, color = "#ffffff",
      fillColor = point_fill, fillOpacity = 1,
      options = leaflet::pathOptions(pane = "pts"),
      label = ~label, popup = ~popup,
      popupOptions = leaflet::popupOptions(maxWidth = 320))

  if (!is.null(point_legend)) {
    m <- m |> leaflet::addLegend(position = "topright",
                                 colors = point_legend$colors,
                                 labels = point_legend$labels,
                                 title = point_legend$title, opacity = 0.9)
  }

  m <- m |>
    leaflet.extras::addSearchFeatures(
      targetGroups = search_group,
      options = leaflet.extras::searchFeaturesOptions(
        zoom = 12, openPopup = TRUE, firstTipSubmit = TRUE,
        autoCollapse = FALSE, hideMarkerOnCollapse = TRUE,
        textPlaceholder = search_placeholder)) |>
    leaflet::addLayersControl(
      baseGroups = group_names, overlayGroups = search_group,
      options = leaflet::layersControlOptions(collapsed = FALSE))

  if (!is.null(title_html)) {
    m <- m |> leaflet::addControl(html = title_html, position = "topleft")
  }
  if (!is.null(footnote_html)) {
    m <- m |> leaflet::addControl(html = footnote_html, position = "bottomleft",
                                  className = "map-footnote")
  }

  # Per-layer legend visibility: show only the active layer's legend.
  toggle_js <- sprintf("
    function(el, x) {
      var map = this;
      function show(name) {
        var t = name.replace(/[^A-Za-z]/g,'');
        el.querySelectorAll('.leg').forEach(function(l){ l.style.display='none'; });
        var e = el.querySelector('.leg-'+t);
        if (e) e.style.display='block';
      }
      map.on('baselayerchange', function(ev){ show(ev.name); });
      show('%s');
    }", tok(default_layer))

  m |>
    htmlwidgets::onRender(toggle_js) |>
    leaflet::hideGroup(setdiff(group_names, default_layer))
}
