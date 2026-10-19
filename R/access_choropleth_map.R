#' Single-geography "closest provider" access choropleth, time vs. supply toggle
#'
#' @description
#' Renders one geography shaded two ways as switchable base layers -- drive
#' time to the nearest provider, or provider supply per capita -- plus a
#' hover-labelled access-desert overlay, click-to-highlight provider markers
#' (clicking a geography lights up the providers nearest it), a combined
#' place/provider name search, and a legend that swaps with the active base
#' layer.
#'
#' @section A sibling, not a duplicate, of `mysterymaps_county_access_map()`:
#' [mysterymaps_county_access_map()] is the template for a *single* shading
#' (one `value_col`) plus dissolved drive-time **coverage-surface** base
#' layers (e.g. "within 30 minutes" as its own polygon). This function is for
#' the different, complementary case of *one* geography shaded two
#' *different ways* that a reader toggles between, with click-to-highlight
#' tied to provider identity rather than a dissolved surface. Read both
#' docs before adding a third variant.
#'
#' @section Multi-geography sibling:
#' [mysterymaps_access_choropleth_map_multi()] is this same idea extended to
#' several geographies (e.g. county AND congressional district) switchable
#' in one map.
#'
#' @param geo `sf` polygons, one row per geography, with columns: `mm_id`
#'   (unique id), `mm_label` (hover HTML), `mm_popup` (click HTML),
#'   `mm_fill_time`, `mm_fill_supply` (precomputed fill colours) and
#'   `mm_no_access` (logical; `TRUE` feeds the desert overlay).
#' @param providers `sf` POINTs with `mm_id` (matches the values in
#'   `highlight_lookup`), `mm_label` and `mm_popup`.
#' @param highlight_lookup Named list: geography `mm_id` -> character vector
#'   of provider `mm_id`s to light up when that geography is clicked.
#' @param supply_pal,supply_values Leaflet palette function and the values it
#'   was built on, for the supply legend.
#' @param band_colors,band_labels Drive-time legend colours and labels.
#' @param title_html HTML for the top-left title control.
#' @param labels Named list overriding group labels: `time`, `supply`,
#'   `desert`, `providers`.
#' @param text Named list overriding legend/desert wording: `time_legend`,
#'   `supply_legend`, `desert`.
#' @param base_tiles `character(1)`: provider-tile name. Default
#'   `"CartoDB.Positron"`.
#' @return A `leaflet` htmlwidget.
#' @family mapping
#' @seealso [mysterymaps_county_access_map()], [mysterymaps_access_choropleth_map_multi()]
#' @export
#' @examplesIf interactive()
#' geo <- sf::st_sf(
#'   mm_id = c("A", "B"), mm_label = c("A", "B"), mm_popup = c("<b>A</b>", "<b>B</b>"),
#'   mm_fill_time = c("#2166ac", "#67a9cf"), mm_fill_supply = c("#67a9cf", "#2166ac"),
#'   mm_no_access = c(TRUE, FALSE),
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
#'     sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
#'     crs = 4326))
#' providers <- sf::st_as_sf(
#'   data.frame(mm_id = "P1", mm_label = "P1", mm_popup = "<b>P1</b>", lon = -97, lat = 40),
#'   coords = c("lon", "lat"), crs = 4326)
#' mysterymaps_access_choropleth_map(
#'   geo, providers, highlight_lookup = list(A = "P1"),
#'   supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
#'   band_colors = c("#2166ac", "#67a9cf"), band_labels = c("<=30 min", ">30 min"),
#'   title_html = "<b>Example</b>")
mysterymaps_access_choropleth_map <- function(geo, providers, highlight_lookup,
                                              supply_pal, supply_values,
                                              band_colors, band_labels, title_html,
                                              labels = list(), text = list(),
                                              base_tiles = "CartoDB.Positron") {
  for (pkg in c("sf", "leaflet", "leaflet.extras", "htmltools", "htmlwidgets")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_access_choropleth_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(geo, "sf")
  checkmate::assert_class(providers, "sf")
  checkmate::assert_list(highlight_lookup, names = "unique")
  checkmate::assert_string(title_html)

  need <- c("mm_id", "mm_label", "mm_popup", "mm_fill_time", "mm_fill_supply", "mm_no_access")
  miss <- setdiff(need, names(geo))
  if (length(miss)) {
    stop("mysterymaps_access_choropleth_map(): `geo` is missing columns: ",
         paste(miss, collapse = ", "), call. = FALSE)
  }
  mm_assert_unique_provider_ids(providers, "mysterymaps_access_choropleth_map")
  # leaflet expects WGS84 lon/lat and will plot whatever numbers a non-4326
  # CRS hands it with no correction -- a provider in, say, Web Mercator
  # meters (the sf layer this warns about, not errors on) renders at
  # coordinates like (4865942, -11020630): nowhere near the real location,
  # with only an sf-level warning, not a mysterymaps one, saying so.
  # mysterymaps_count_points_in_polygons() already transforms its `points`
  # argument for the same reason; this matches that convention.
  geo <- sf::st_transform(geo, 4326)
  providers <- sf::st_transform(providers, 4326)
  lab <- utils::modifyList(list(time = "Drive time to closest", supply = "Supply per capita",
                                desert = "No access", providers = "Providers"), labels)
  txt <- utils::modifyList(list(time_legend = "Drive time to<br>closest provider",
                                supply_legend = "Providers per<br>100k (in range)",
                                desert = "no provider in range"), text)

  # Invisible geography centroids so places are searchable by name (s2 off to
  # keep point-on-surface robust for lon/lat polygons).
  old_s2 <- sf::sf_use_s2(); sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(old_s2), add = TRUE)
  geo_pts <- suppressWarnings(sf::st_point_on_surface(geo))
  deserts <- geo[which(as.logical(geo$mm_no_access)), ]

  # Click a geography -> light up its nearest providers (keyed by mm_id).
  hl_js <- r"---(
function(el, x, data) {
  var map = this;
  var lookup = data.lookup || {};
  var lit = [];
  function reset() {
    lit.forEach(function(mk){
      mk.setRadius(3).setStyle({
        fillColor: mk._origFill || mk.options.fillColor,
        fillOpacity: 0.9, stroke: true, color: '#ffffff', weight: 1
      });
    });
    lit = [];
  }
  function light(ids) {
    reset();
    if (ids == null) ids = [];
    if (!Array.isArray(ids)) ids = [ids];
    ids.forEach(function(id){
      var mk = map.layerManager.getLayer('marker', String(id));
      if (mk) {
        if (!mk._origFill) mk._origFill = mk.options.fillColor;
        mk.setRadius(8).setStyle({fillColor:'#e6194B', fillOpacity:1, stroke:true, color:'#ffffff', weight:2});
        mk.bringToFront();
        lit.push(mk);
      }
    });
  }
  Object.keys(lookup).forEach(function(g){
    ['', 'S_'].forEach(function(pfx){
      var poly = map.layerManager.getLayer('shape', pfx + g);
      if (poly) { poly.on('click', function(){ light(lookup[g]); }); }
    });
  });
}
)---"

  m <- leaflet::leaflet(geo) |>
    leaflet::addProviderTiles(base_tiles) |>
    leaflet::addPolygons(fillColor = ~mm_fill_time, fillOpacity = 0.7, color = "#888",
                         weight = 0.4, popup = ~mm_popup, group = lab$time, layerId = ~mm_id,
                         highlightOptions = leaflet::highlightOptions(weight = 2, color = "#000",
                                                                      bringToFront = TRUE)) |>
    leaflet::addPolygons(fillColor = ~mm_fill_supply, fillOpacity = 0.7, color = "#888",
                         weight = 0.4, popup = ~mm_popup, group = lab$supply,
                         layerId = ~paste0("S_", mm_id),
                         highlightOptions = leaflet::highlightOptions(weight = 2, color = "#000",
                                                                      bringToFront = TRUE)) |>
    leaflet::addCircleMarkers(data = providers, radius = 2, color = "#3b0a45", stroke = FALSE,
                              fillOpacity = 0.7, group = lab$providers, layerId = ~mm_id,
                              label = ~mm_label, popup = ~mm_popup) |>
    leaflet::addCircleMarkers(data = geo_pts, radius = 0.1, stroke = FALSE, fillOpacity = 0,
                              group = "geo-search", label = ~mm_label) |>
    # className carries the base-legend-switcher's hook (mm-lg / mm-lg-<key>),
    # NOT `group=`: leaflet's own group-based legend show/hide only ever
    # follows OVERLAY groups, and lab$time/lab$supply are BASE groups, so
    # `group=` here would be silently inert -- both legends would render at
    # once. mysterymaps_base_legend_switcher() below is the actual fix.
    leaflet::addLegend(position = "bottomright",
                       colors = band_colors, labels = band_labels, title = txt$time_legend,
                       className = "info legend mm-lg mm-lg-time") |>
    leaflet::addLegend(position = "bottomright", pal = supply_pal,
                       values = supply_values, title = txt$supply_legend, na.label = "0 / no data",
                       className = "info legend mm-lg mm-lg-supply") |>
    leaflet::addControl(html = title_html, position = "topleft")

  # Access-desert overlay only when there is at least one desert; adding a
  # zero-row polygon layer errors in leaflet's bbox expansion (the same
  # hazard mysterymaps_access_choropleth_map_multi() already guards against
  # -- every area having access is a normal, good outcome, not one that
  # should break the map).
  overlay_groups <- lab$providers
  if (nrow(deserts) > 0) {
    m <- m |> leaflet::addPolygons(
      data = deserts, fill = FALSE, color = "#7a0177", weight = 1.4, group = lab$desert,
      label = ~lapply(sprintf("<b>%s</b> &mdash; %s", mm_label, txt$desert), htmltools::HTML),
      highlightOptions = leaflet::highlightOptions(weight = 3, color = "#49006a", bringToFront = TRUE))
    overlay_groups <- c(overlay_groups, lab$desert)
  }

  m <- m |>
    leaflet::addLayersControl(baseGroups = c(lab$time, lab$supply),
                              overlayGroups = overlay_groups,
                              options = leaflet::layersControlOptions(collapsed = FALSE))
  if (nrow(deserts) > 0) m <- leaflet::hideGroup(m, lab$desert)
  m <- m |>
    leaflet.extras::addSearchFeatures(
      targetGroups = c("geo-search", lab$providers),
      options = leaflet.extras::searchFeaturesOptions(
        zoom = 9, openPopup = TRUE, firstTipSubmit = TRUE, autoCollapse = TRUE,
        hideMarkerOnCollapse = TRUE, textPlaceholder = "Search a place or provider...")) |>
    htmlwidgets::onRender(hl_js, data = list(lookup = highlight_lookup))

  m <- mysterymaps_register_base_legend(m, lab$time, key = "time")
  m <- mysterymaps_register_base_legend(m, lab$supply, key = "supply")
  mysterymaps_base_legend_switcher(m, default = lab$time)
}
