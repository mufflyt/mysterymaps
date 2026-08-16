`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' Add a name-search box over a point layer
#'
#' Wraps \href{https://github.com/stefanocudini/leaflet-search}{Leaflet.Control.Search}
#' so a reader can find one provider among thousands instead of hunting dots.
#'
#' @details
#' The plugin ships with `leaflet.extras` as a local HTML dependency, so a
#' self-contained widget stays self-contained. An earlier version loaded it from
#' a CDN to save a few hundred kilobytes in a 15-20 MB file; the cost was that
#' the search box was inert for anyone opening the saved map offline, and a
#' control that silently does nothing is worse than an absent one. The size
#' argument was real but small, and it was buying the wrong thing.
#'
#' @section Which layers are searched:
#' `group = NULL` reads the marker groups already added to the map. leaflet
#' stores the group name positionally in the widget call list -- argument 5 for
#' `addCircleMarkers` -- which is undocumented, so the extraction is validated
#' and the control is skipped with a warning rather than attached to nothing.
#' Pass `group` explicitly to be certain, and to restrict the search.
#'
#' Markers must carry a `label`; that is the text searched.
#'
#' @param map a leaflet map.
#' @param group [character] or NULL: marker groups to search. NULL detects them.
#' @param placeholder `character(1)`: text shown in the empty box.
#' @param zoom `integer(1)`: zoom level to fly to on a hit.
#' @param position `character(1)`: leaflet control position.
#' @return the map, with the control attached.
#' @family county-access-template
#' @export
mysterymaps_name_search <- function(map, group = NULL,
                                    placeholder = "Search name...",
                                    zoom = 11L, position = "topleft") {
  if (!requireNamespace("leaflet.extras", quietly = TRUE)) {
    warning("leaflet.extras is not installed; no search control added.",
            call. = FALSE)
    return(map)
  }

  if (is.null(group)) {
    marker_methods <- c("addCircleMarkers", "addMarkers", "addAwesomeMarkers")
    calls <- map$x$calls %||% list()
    group <- unlist(lapply(calls, function(cl) {
      if (!isTRUE(cl$method %in% marker_methods)) return(NULL)
      # leaflet::invokeMethod passes (lat, lng, radius, layerId, group, ...).
      g <- tryCatch(cl$args[[5]], error = function(e) NULL)
      if (is.character(g) && length(g) == 1L && nzchar(g)) g else NULL
    }))
    group <- unique(group)
    if (!length(group)) {
      warning("mysterymaps_name_search: no marker groups found; ",
              "pass `group` explicitly. No control added.", call. = FALSE)
      return(map)
    }
  }

  leaflet.extras::addSearchFeatures(
    map, targetGroups = group,
    options = leaflet.extras::searchFeaturesOptions(
      zoom = as.integer(zoom), openPopup = TRUE, firstTipSubmit = TRUE,
      autoCollapse = FALSE, hideMarkerOnCollapse = TRUE,
      position = position, textPlaceholder = placeholder))
}

#' Build a collapsible notes panel with a data-vintage list
#'
#' Every access map needs the same footnote furniture: what the shading means,
#' what a blank county means, and when each source was current. This renders it
#' as one collapsed panel rather than repeating caveats in every popup.
#'
#' @details
#' A caveat repeated per feature is a caveat the reader stops seeing. On the
#' midwifery map the sentence "which reflects roster, linkage and geocoding
#' coverage as much as who practises here" fired on 1,801 county popups, so the
#' map spent its ink telling the reader not to trust it. It belongs here, once.
#'
#' `vintages` is deliberately required rather than optional. A map whose sources
#' span 2013 to 2026 and says only "2026" is asserting a currency it does not
#' have, and the year in the title is always the freshest input, never the
#' oldest.
#'
#' @param map a leaflet map.
#' @param title `character(1)`: panel heading; the year belongs here.
#' @param sections `named list`: heading -> HTML paragraph.
#' @param vintages `data.frame`: columns `source` and `vintage`; optional `url`
#'   renders the source name as a link.
#' @param as_of `character(1)`: the "Data as of" line, e.g. the roster year.
#' @param max_height `character(1)`: CSS max-height so the panel never covers
#'   the map.
#' @param bottom `character(1)`: CSS offset; the default clears a bottom-left
#'   scale bar, which otherwise draws underneath the panel.
#' @return the map, with the panel attached.
#' @family county-access-template
#' @export
mysterymaps_notes_panel <- function(map, title, sections, vintages,
                                    as_of = NULL, max_height = "44vh",
                                    bottom = "52px") {
  stopifnot(is.list(sections), is.data.frame(vintages),
            all(c("source", "vintage") %in% names(vintages)))

  body <- paste(vapply(names(sections), function(h) {
    sprintf('<p style="margin:.2em 0 .7em"><b>%s</b> %s</p>', h, sections[[h]])
  }, character(1)), collapse = "\n")

  src <- if ("url" %in% names(vintages)) {
    ifelse(is.na(vintages$url) | !nzchar(vintages$url), vintages$source,
           sprintf('<a href="%s" target="_blank" rel="noopener">%s</a>',
                   vintages$url, vintages$source))
  } else vintages$source

  rows <- paste(sprintf('<li>%s &mdash; %s</li>', src, vintages$vintage),
                collapse = "\n")
  asof <- if (is.null(as_of)) "" else
    sprintf('<p style="margin:.2em 0 .7em"><b>Data as of %s.</b> Sources carry their own vintages:</p>', as_of)

  html <- sprintf('
<style>
 #mmnote{position:fixed;bottom:%s;left:14px;z-index:1000;max-width:340px;
  background:rgba(255,255,255,.96);border:1px solid #c8c8c8;border-radius:6px;
  font:12px/1.5 system-ui,-apple-system,sans-serif;box-shadow:0 1px 6px rgba(0,0,0,.18)}
 #mmnote summary{cursor:pointer;padding:8px 11px;font-weight:600;list-style:none}
 #mmnote summary::-webkit-details-marker{display:none}
 #mmnote summary:after{content:" \\25BE";color:#888}
 #mmnote[open] summary:after{content:" \\25B4"}
 #mmnote .bd{padding:0 11px 11px;max-height:%s;overflow-y:auto;color:#333}
 #mmnote ul{margin:.2em 0 .7em;padding-left:1.1em}
</style>
<details id="mmnote"><summary>%s</summary><div class="bd">%s%s<ul>%s</ul></div></details>',
    bottom, max_height, title, body, asof, rows)

  leaflet::addControl(map, htmltools::HTML(html), position = "bottomleft",
                      className = "mm-notes-wrap")
}

#' County access map: choropleth, drive-time coverage, provider dots
#'
#' The template behind the urogynecology and midwifery access maps. Composes the
#' pieces this package already provides -- a zero-aware Jenks scale, dissolved
#' coverage surfaces, base-group legends, zoom-gated point labels -- and adds the
#' furniture every such map needs: a name search and a notes panel with source
#' vintages.
#'
#' @section Why a single canvas renderer:
#' `preferCanvas = TRUE` is set on the map and NO custom pane is used for the
#' points. Giving markers their own high-zIndex pane creates a second canvas
#' element covering the whole map, and that element swallows every click --
#' including clicks on empty ground where no marker is drawn. On the midwifery
#' map this silently disabled all 3,109 county popups: they existed in the HTML
#' and never opened. Sharing one renderer lets leaflet hit-test markers and
#' polygons together.
#'
#' @section Zero is a class, not a low value:
#' Shading runs through [mysterymaps_jenks_zero_scale()], which gives zero its
#' own colour. Folding "no provider" into the bottom bin of a continuous ramp
#' reads as "few" and is the single most misleading thing an access map can do.
#'
#' @param counties `sf`: county polygons.
#' @param value_col `character(1)`: column in `counties` to shade.
#' @param label_col,popup_col `character(1)`: columns holding hover and click HTML.
#' @param coverage `named list of sf`: dissolved drive-time bands, e.g.
#'   `list("Within 30 minutes" = iso30, "Within 60 minutes" = iso60)`.
#' @param coverage_colors,coverage_labels,coverage_titles passed through to
#'   [mysterymaps_add_coverage_surfaces()]. Real maps carry a "beyond" band whose
#'   legend title differs from the "within" bands ("Coverage gap" rather than
#'   "Drive-time coverage"), so these are exposed rather than fixed.
#' @param overlay_group `character(1)|NULL`: name of the point overlay in the
#'   layers control. Defaults to "Provider locations". Passing `NULL` when the
#'   caller adds its own point layer afterwards used to emit an overlay literally
#'   labelled "null" in the control.
#' @param coverage_area_units `"km"` (default) or `"mi"`. Square miles for a US
#'   audience; the popup and the unit label change together so they cannot
#'   disagree.
#' @param coverage_popups `logical(1)`: attach a popup to each coverage band
#'   naming the band, its area and how many origins were dissolved into it.
#' @param mesh `logical(1)`: draw an unfilled county outline that stays visible
#'   under every base group. It carries no `group` deliberately: three
#'   group-bound copies triple the county geometry in the output file.
#' @param points `sf|NULL`: provider locations.
#' @param point_label_col,point_popup_col `character(1)`: columns on `points`.
#' @param legend_title `character(1)`: choropleth legend heading.
#' @param jenks_k `integer(1)`: positive-class count for the scale.
#' @param jenks_digits `integer(1)`: decimals in the legend breaks. Use 0 when
#'   the quantity is a count of people: "0.2-2.6 midwives per 1,000 births"
#'   invites a reader to picture a fifth of a person.
#' @param legend_labels `character|NULL`: replace the computed break labels
#'   outright. Wording such as "none" for the zero class, or "under 5" where
#'   rounding would otherwise render the first positive class as "0-5" and make
#'   it look like the zero class, is a caller decision.
#' @param point_fill,point_alpha point styling. The default alpha is 0.55
#'   because thousands of opaque dots read as a solid mass over metros and hide
#'   the choropleth beneath them.
#' @param search placeholder text for the name box, or `NULL` to omit it.
#' @param notes a list of arguments for [mysterymaps_notes_panel()], or `NULL`.
#' @param bounds numeric length-4 `c(lat_min, lng_min, lat_max, lng_max)`.
#' @return a leaflet map.
#'
#' @examples
#' \dontrun{
#' mysterymaps_county_access_map(
#'   counties = cty, value_col = "midwives_per_1k_births",
#'   label_col = "tooltip", popup_col = "profile",
#'   coverage = list("Within 30 minutes" = u30, "Within 60 minutes" = u60),
#'   points = mw, point_label_col = "full_name", point_popup_col = "popup",
#'   legend_title = "Midwives per<br/>1,000 births",
#'   notes = list(title = "Access to midwives, 2026 - notes",
#'                sections = list("County shading" = "is providers per 1,000 births."),
#'                vintages = data.frame(source = "AMCB roster", vintage = "2026"),
#'                as_of = "2026"))
#' }
#' @family county-access-template
#' @export
mysterymaps_county_access_map <- function(counties, value_col,
                                          label_col, popup_col,
                                          coverage = list(), points = NULL,
                                          point_label_col = NULL,
                                          point_popup_col = NULL,
                                          coverage_colors = NULL,
                                          coverage_labels = NULL,
                                          coverage_titles = NULL,
                                          overlay_group = "Provider locations",
                                          coverage_area_units = c("km", "mi"),
                                          coverage_popups = TRUE,
                                          mesh = TRUE,
                                          legend_title = "Rate",
                                          jenks_k = 6L,
                                          jenks_digits = 1L,
                                          legend_labels = NULL,
                                          point_fill = "#c2185b",
                                          point_alpha = 0.55,
                                          search = "Search name...",
                                          notes = NULL,
                                          bounds = c(24.5, -125, 49.4, -66.9)) {
  coverage_area_units <- match.arg(coverage_area_units)
  stopifnot(inherits(counties, "sf"))
  for (nm in c(value_col, label_col, popup_col)) {
    if (!nm %in% names(counties))
      stop("mysterymaps_county_access_map: `counties` has no column '", nm, "'.",
           call. = FALSE)
  }

  sc <- mysterymaps_jenks_zero_scale(counties[[value_col]], k = jenks_k,
                                     digits = jenks_digits)
  if (!is.null(legend_labels)) {
    if (length(legend_labels) != length(sc$leg_labs)) {
      stop(sprintf(paste0("mysterymaps_county_access_map: legend_labels has %d entries ",
                          "but the scale produced %d classes. A mismatch would ",
                          "silently mislabel colours."),
                   length(legend_labels), length(sc$leg_labs)), call. = FALSE)
    }
    sc$leg_labs <- legend_labels
  }
  rate_group <- legend_title

  m <- leaflet::leaflet(options = leaflet::leafletOptions(
        minZoom = 3, maxZoom = 14, preferCanvas = TRUE)) |>
    leaflet::addProviderTiles("CartoDB.PositronNoLabels", group = "base") |>
    leaflet::addScaleBar(position = "bottomleft",
                         options = leaflet::scaleBarOptions(imperial = TRUE)) |>
    leaflet::addPolygons(
      data = counties, fillColor = sc$color(counties[[value_col]]),
      fillOpacity = 0.85, color = "#ffffff", weight = 0.4, smoothFactor = 0.5,
      label = lapply(counties[[label_col]], htmltools::HTML),
      popup = lapply(counties[[popup_col]], htmltools::HTML),
      popupOptions = leaflet::popupOptions(maxWidth = 360),
      highlightOptions = leaflet::highlightOptions(weight = 2, color = "#111",
                                                   fillOpacity = 0.95),
      group = rate_group)

  if (isTRUE(mesh)) {
    # No `group`: leaflet then keeps it visible under every base group. Three
    # group-bound copies tripled the county geometry in the HTML.
    m <- leaflet::addPolygons(m, data = sf::st_geometry(counties), fill = FALSE,
                              color = "#c0c0c0", weight = 0.3)
  }
  m <- leaflet::addProviderTiles(m, "CartoDB.PositronOnlyLabels", group = "base")

  m <- leaflet::addLegend(m, position = "bottomright", colors = sc$leg_cols,
                          labels = sc$leg_labs, title = legend_title,
                          opacity = 0.9,
                          className = "info legend mm-lg mm-lg-rate")
  m <- mysterymaps_register_base_legend(m, rate_group, key = "rate")

  if (length(coverage)) {
    args <- list(map = m, surfaces = coverage)
    if (!is.null(coverage_colors)) args$colors        <- coverage_colors
    if (!is.null(coverage_labels)) args$legend_labels <- coverage_labels
    if (!is.null(coverage_titles)) args$legend_titles <- coverage_titles
    if (isTRUE(coverage_popups)) {
      # Built here and handed to add_coverage_surfaces so the popup rides on the
      # surface polygon rather than a duplicate copy of its geometry.
      args$popups <- vapply(names(coverage), function(nm) {
        sfc  <- coverage[[nm]]
        # The popup states an area to the reader, so it is a claim like any
        # other. A hard-coded /1e6 is right only for a CRS that is both in
        # metres and equal-area: a surface on a state plane grid in US survey
        # feet printed 10.76x its real size, and one straight off a Web
        # Mercator tile pipeline about 1.8x. mm_area_in() measures geodesically
        # instead. A surface with no CRS cannot be measured at all, and the
        # popup says so rather than printing a number.
        want <- if (identical(coverage_area_units, "mi")) "mi^2" else "km^2"
        area <- tryCatch(mm_area_in(sf::st_geometry(sfc), want),
                         error = function(e) NA_real_)
        unit <- if (identical(coverage_area_units, "mi")) "sq mi" else "km&sup2;"
        n_or <- if (is.list(sfc) && !is.null(sfc$n_origins_dissolved))
                  sfc$n_origins_dissolved else attr(sfc, "n_origins_dissolved")
        sprintf("<div style='font:13px/1.6 system-ui,sans-serif'><b>%s</b><br/>%s %s%s</div>",
                nm,
                if (is.na(area)) "area unavailable" else format(round(area), big.mark = ","),
                unit,
                if (!is.null(n_or) && !is.na(n_or))
                  sprintf("<br/>dissolved from %s provider isochrones",
                          format(n_or, big.mark = ",")) else "")
      }, character(1))
    }
    m <- do.call(mysterymaps_add_coverage_surfaces, args)
  }

  m <- leaflet::addLayersControl(
    m, baseGroups = c(rate_group, names(coverage)),
    # NEVER pass NULL here: leaflet renders it as an overlay literally labelled
    # "null" in the control.
    overlayGroups = overlay_group,
    options = leaflet::layersControlOptions(collapsed = FALSE))

  if (!is.null(points) && nrow(points)) {
    m <- leaflet::addCircleMarkers(
      m, data = points, radius = 4, stroke = TRUE, weight = 0.8,
      color = "#ffffff", fillColor = point_fill,
      fillOpacity = point_alpha, opacity = 0.7,
      popup = if (!is.null(point_popup_col)) points[[point_popup_col]],
      label = if (!is.null(point_label_col)) points[[point_label_col]],
      labelOptions = leaflet::labelOptions(direction = "right",
                                           offset = c(6, 0), textsize = "11px",
                                           opacity = 0.95),
      # No custom pane: see the note on canvas renderers above.
      group = overlay_group)
    m <- mysterymaps_zoom_gated_labels(m, group = overlay_group,
                                       min_zoom = 9, max_labels = 400)
    if (!is.null(search)) m <- mysterymaps_name_search(m, placeholder = search)
  }

  m <- mysterymaps_base_legend_switcher(m, default = rate_group)

  if (!is.null(notes)) m <- do.call(mysterymaps_notes_panel, c(list(map = m), notes))

  leaflet::fitBounds(m, bounds[2], bounds[1], bounds[4], bounds[3])
}
