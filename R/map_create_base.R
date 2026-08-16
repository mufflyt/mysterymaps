#' Create a Configurable Leaflet Base Map
#'
#' Build a Leaflet base map with sensible defaults for the mysterycall mapping
#' helpers. The map includes multiple tile providers, a scale bar, optional
#' title control, and centers on the continental United States by default.
#'
#' @param title Optional HTML string used for a title control in the upper
#'   left corner of the map. Supply `NULL` or an empty string to omit the
#'   control.
#' @param lat,lng Numeric latitude and longitude used to center the initial
#'   view. Defaults position the map over the continental United States.
#' @param zoom Numeric zoom level passed to [leaflet::setView()].
#'
#' @return A [leaflet::leaflet()] map object pre-configured with controls and
#'   basemap layers.
#'
#' @family mapping
#' @export
#' @examplesIf interactive()
#' mysterymaps_map_base()
#' mysterymaps_map_base("<strong>Custom title</strong>")
mysterymaps_map_base <- function(title = NULL, lat = 39.8282, lng = -98.5795, zoom = 4) {
  if (!requireNamespace("leaflet", quietly = TRUE)) {
    stop("Package 'leaflet' is required for mysterymaps_map_base()", call. = FALSE)
  }
  map <- leaflet::leaflet(options = leaflet::leafletOptions(zoomControl = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Voyager", group = "CartoDB Voyager") %>%
    leaflet::addProviderTiles("Stadia.StamenTonerLite", group = "Toner Lite") %>%
    leaflet::addScaleBar(position = "bottomleft") %>%
    leaflet::addLayersControl(
      baseGroups = c("CartoDB Voyager", "Toner Lite"),
      options = leaflet::layersControlOptions(collapsed = FALSE)
    ) %>%
    leaflet::setView(lat = lat, lng = lng, zoom = zoom) %>%
    leaflet::addTiles(options = leaflet::tileOptions(useCache = TRUE, crossOrigin = TRUE))

  if (!is.null(title) && nzchar(title)) {
    if (!requireNamespace("htmltools", quietly = TRUE)) {
      stop("Package 'htmltools' is required for this function", call. = FALSE)
    }
    map <- leaflet::addControl(
      map,
      html = htmltools::tags$div(
        class = "mysterycall-map-title",
        htmltools::HTML(title)
      ),
      position = "topleft"
    )
  }

  map
}

#' Create and Save a Leaflet Dot Map of Physicians
#'
#' This function creates a Leaflet dot map of physicians using their longitude
#' and latitude coordinates. It also adds ACOG district boundaries to the map
#' and saves it as an HTML file with an accompanying PNG screenshot.
#'
#' @param physician_data An sf object containing physician data with `"long"`
#'   and `"lat"` columns.
#' @param jitter_range The range for adding jitter to latitude and longitude
#'   coordinates.
#' @param color_palette The color palette for ACOG district colors.
#' @param popup_var The variable to use for popup text.
#' @param output_dir Directory where the HTML map and PNG screenshot are saved.
#'   Defaults to a session-specific temporary folder.
#' @param seed Integer or `NULL`. Seed for the coordinate jitter, so a published
#'   dot map can be regenerated exactly. `NULL` (default) leaves the caller's
#'   random stream alone and produces a different jitter each run.
#' @return Invisibly returns the Leaflet map object, with a `mysterymaps_seed`
#'   attribute recording the seed actually used.
#'
#' @section Reproducibility:
#' The jitter moves every point by up to `jitter_range` degrees. That is a real
#' displacement on a published figure, so it has to be replayable: pass `seed`
#' and the same map comes back. The seed is applied locally -- the caller's
#' `.Random.seed` is saved and restored -- so seeding a map does not silently
#' reseed the rest of a script.
#'
#' @importFrom dplyr mutate
#' @importFrom stats runif as.formula
#'
#' @examplesIf interactive()
#' # Load required libraries
#' library(viridis)
#' library(leaflet)
#'
#' # Generate physician data (replace with your own data)
#' physician_data <- data.frame(
#'   long = c(-95.363271, -97.743061, -98.493628, -96.900115, -95.369803),
#'   lat = c(29.763283, 30.267153, 29.424349, 32.779167, 29.751808),
#'   name = c("Physician 1", "Physician 2", "Physician 3", "Physician 4", "Physician 5"),
#'   ACOG_District = c("District I", "District II", "District III", "District IV", "District V")
#' )
#'
#' # Create and save the dot map
#' mysterymaps_map_physicians(physician_data)
#'
#' @family mapping
#' @export
mysterymaps_map_physicians <- function(physician_data, jitter_range = 0.05, color_palette = "magma", popup_var = "name", output_dir = NULL, seed = NULL) {
  if (!requireNamespace("leaflet", quietly = TRUE)) {
    stop("Package 'leaflet' is required for mysterymaps_map_physicians()", call. = FALSE)
  }
  if (!requireNamespace("webshot", quietly = TRUE)) {
    stop("Package 'webshot' is required for mysterymaps_map_physicians()", call. = FALSE)
  }
  if (!requireNamespace("viridis", quietly = TRUE)) {
    stop("Package 'viridis' is required for this function", call. = FALSE)
  }
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    stop("Package 'htmlwidgets' is required for this function", call. = FALSE)
  }
  if (is.null(output_dir)) {
    output_dir <- file.path(tempdir(), "physician_maps")
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  } else {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  # Seed locally, then put the caller's stream back exactly as it was. Calling
  # set.seed() without restoring would make this function reseed every
  # downstream simulation in a script that happened to draw a map first.
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
      stop("`seed` must be a single number or NULL.", call. = FALSE)
    }
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) {
      prev_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
      on.exit(assign(".Random.seed", prev_seed, envir = globalenv()), add = TRUE)
    } else {
      on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
    }
    set.seed(seed)
  }

  jittered_physician_data <- dplyr::mutate(
    physician_data,
    lat = lat + runif(n()) * jitter_range,
    long = long + runif(n()) * jitter_range
  )

  message("Setting up the base map...")
  base_map <- mysterymaps_map_base("Physician Dot Map")
  message("Map setup complete.")

  message("Generating the ACOG district boundaries...")
  acog_districts <- mysterymaps_map_acog_districts()
  message("ACOG district boundaries generated.")

  num_acog_districts <- dplyr::n_distinct(acog_districts$ACOG_District)
  district_colors <- viridis::viridis(num_acog_districts, option = color_palette)

  jittered_physician_data <- dplyr::mutate(
    jittered_physician_data,
    ACOG_District = factor(
      ACOG_District,
      levels = sort(unique(acog_districts$ACOG_District))
    )
  )

  dot_map <- leaflet::addCircleMarkers(
    base_map,
    data = jittered_physician_data,
    lng = ~long,
    lat = ~lat,
    radius = 3,
    stroke = TRUE,
    weight = 1,
    color = district_colors[as.numeric(jittered_physician_data$ACOG_District)],
    fillOpacity = 0.8,
    popup = as.formula(paste0("~", popup_var))
  ) %>%
    leaflet::addPolygons(
      data = acog_districts,
      color = "red",
      weight = 2,
      fill = FALSE,
      opacity = 0.8,
      popup = ~ACOG_District
    ) %>%
    leaflet::addLegend(
      position = "bottomright",
      colors = district_colors,
      labels = levels(jittered_physician_data$ACOG_District),
      title = "ACOG Districts"
    )

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  html_file <- file.path(output_dir, paste0("dot_map_", timestamp, ".html"))
  png_file <- file.path(output_dir, paste0("dot_map_", timestamp, ".png"))

  htmlwidgets::saveWidget(widget = dot_map, file = html_file, selfcontained = TRUE)
  message("Leaflet map saved as HTML: ", html_file)

  webshot::webshot(html_file, file = png_file)
  message("Screenshot saved as PNG: ", png_file)

  # Record what was actually used, so the artifact can say how it was made.
  attr(dot_map, "mysterymaps_seed") <- seed
  invisible(dot_map)
}
