#' Create a Leaflet Base Map
#'
#' This function creates a Leaflet BASE map with specific configurations, including the base tile layer, scale bar,
#' default view settings, and layers control.
#'
#' @return A `leaflet` map object (class `"leaflet"` from the leaflet package)
#'   pre-configured with tile providers, scale bar, and layer controls.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' map <- mysterymaps_map_leaflet()
mysterymaps_map_leaflet <- function() {
  if (!requireNamespace("leaflet", quietly = TRUE)) {
    stop("Package 'leaflet' is required for mysterymaps_map_leaflet()", call. = FALSE)
  }
  # Create a new Leaflet map object
  map <- leaflet::leaflet() %>%
    # Esri, not CARTO: keyless CARTO tiles watermark "API KEY REQUIRED"
    # across the whole map (Sept 2026).
    leaflet::addProviderTiles("Esri.WorldStreetMap", group = "Street Map") %>%
    leaflet::addProviderTiles("Stadia.StamenTonerLite", group = "Toner Lite") %>%
    # Clear any previously set bounds
    leaflet::clearBounds() %>%
    # Clear any previously set markers
    leaflet::clearMarkers() %>%
    # Add a scale bar to the bottom-left corner of the map
    leaflet::addScaleBar(position = "bottomleft") %>%
    # Set the initial view of the map to specific latitude, longitude, and zoom level
    leaflet::setView(lat = 39.8282, lng = -98.5795, zoom = 3) %>%
    # Add a layers control for selecting different base layers
    leaflet::addLayersControl(
      baseGroups = c("Street Map", "Toner Lite"),
      options = leaflet::layersControlOptions(collapsed = FALSE)
    ) %>%
    # Add default map tiles with caching and cross-origin support
    leaflet::addTiles(options = leaflet::tileOptions(useCache = TRUE, crossOrigin = TRUE))

  invisible(map)
}
