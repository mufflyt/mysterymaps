#' Routed drive-time flow map
#'
#' @description
#' Draws a set of pre-computed routed paths (e.g. shortest road routes from
#' each target site to its nearest provider) coloured by travel time, over a
#' basemap. This function only renders; it does not call a routing API --
#' build `routes` once with whatever routing engine is available (Valhalla,
#' HERE, OSRM) and pass the result in as an `sf` LINESTRING layer.
#'
#' @details
#' A straight-line ("as the crow flies") distance map can badly overstate
#' real access where the road network is constrained -- a 60-mile straight
#' radius around a site cut off by a single bridge or mountain pass can
#' overstate the population actually reachable in that time by several-fold.
#' Routing each path on the real road network and drawing it here, rather
#' than drawing straight lines, is what keeps a flow map honest in that case.
#'
#' @param routes `sf` LINESTRING (or MULTILINESTRING) layer, one row per routed path.
#' @param basemap `sf` polygon layer to draw beneath the routes.
#' @param time_var `character(1)`: numeric column in `routes` giving travel
#'   time, used to colour each route.
#' @param time_label `character(1)`: full-word legend title for `time_var`.
#'   Default `"Driving Time in Minutes"`.
#' @param origin_points,destination_points Optional `sf` POINT layers drawn
#'   on top of the routes (e.g. the target sites and the nearest providers).
#'   `NULL` omits either.
#' @param origin_label,destination_label `character(1)`: full-word shape
#'   legend labels for `origin_points` / `destination_points`.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param viridis_option `character(1)`: passed to
#'   [ggplot2::scale_color_viridis_c()]'s `option`. Default `"inferno"`.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
mysterymaps_flow_map <- function(routes,
                                 basemap,
                                 time_var,
                                 time_label = "Driving Time in Minutes",
                                 origin_points = NULL,
                                 destination_points = NULL,
                                 origin_label = "Origin Site",
                                 destination_label = "Destination Provider",
                                 title = NULL,
                                 subtitle = NULL,
                                 caption = NULL,
                                 viridis_option = "inferno",
                                 crs = 5070) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_flow_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(routes, "sf")
  checkmate::assert_class(basemap, "sf")
  checkmate::assert_string(time_var)
  checkmate::assert_subset(time_var, names(routes))
  if (nrow(routes) == 0L) {
    stop("mysterymaps_flow_map(): `routes` has zero rows.", call. = FALSE)
  }

  basemap_p <- sf::st_transform(basemap, crs = crs)
  routes_p <- sf::st_transform(routes, crs = crs)

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = basemap_p, fill = "#f8f9fa", color = "gray40",
                     linewidth = 0.25) +
    ggplot2::geom_sf(data = routes_p, mapping = ggplot2::aes(color = .data[[time_var]]),
                     linewidth = 0.9, alpha = 0.85) +
    ggplot2::scale_color_viridis_c(name = time_label, option = viridis_option,
                                   guide = ggplot2::guide_colorbar(title.position = "top"))

  shape_values <- c(); shape_fill <- c(); shape_color <- c()
  if (!is.null(origin_points)) {
    checkmate::assert_class(origin_points, "sf")
    origin_p <- sf::st_transform(origin_points, crs = crs)
    p <- p + ggplot2::geom_sf(data = origin_p, mapping = ggplot2::aes(shape = origin_label),
                              fill = "#D55E00", color = "#D55E00", size = 3, stroke = 1.1)
    shape_values[origin_label] <- 24; shape_fill[origin_label] <- "#D55E00"
    shape_color[origin_label] <- "#D55E00"
  }
  if (!is.null(destination_points)) {
    checkmate::assert_class(destination_points, "sf")
    dest_p <- sf::st_transform(destination_points, crs = crs)
    p <- p + ggplot2::geom_sf(data = dest_p, mapping = ggplot2::aes(shape = destination_label),
                              fill = "white", color = "black", size = 1.8, stroke = 0.5)
    shape_values[destination_label] <- 21; shape_fill[destination_label] <- "white"
    shape_color[destination_label] <- "black"
  }
  if (length(shape_values)) {
    p <- p + ggplot2::scale_shape_manual(
      name = NULL, values = shape_values,
      guide = ggplot2::guide_legend(override.aes = list(
        fill = unname(shape_fill), color = unname(shape_color))))
  }

  p +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::coord_sf(crs = sf::st_crs(crs), datum = NA) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0),
      legend.position = "bottom")
}
