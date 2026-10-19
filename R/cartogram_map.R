#' Drive-time cartogram map
#'
#' @description
#' Redraws each polygon scaled radially around its nearest hub (e.g. a
#' provider or partner site), so areas whose real drive time is far out of
#' proportion to their straight-line distance balloon outward, and
#' well-connected areas pull inward. This is **not a true-area map** -- it
#' deliberately distorts geography to encode travel time instead.
#'
#' @details
#' A straight-line distance near zero (the hub essentially inside the
#' polygon) makes the warp ratio `time / distance` blow up into a
#' meaningless value that has nothing to do with genuine circuitousness --
#' it is purely an artifact of dividing by a near-zero denominator. Per-row
#' scale factors are clipped to `scale_clip` (default `c(0.2, 3)`) for
#' exactly this reason: without the clip, a handful of near-zero-distance
#' polygons would misleadingly read as "the most distorted" on the map.
#'
#' The calibration constant (how much distance one minute of drive time
#' "should" correspond to, in the undistorted/typical-pace case) is derived
#' automatically from the data: `median(straight_distance_var) /
#' median(time_var)` across all rows with both values present. A polygon
#' whose warp ratio is near this median pace is drawn close to its true
#' shape and position; a polygon far slower or faster than that pace is
#' pushed out or pulled in accordingly.
#'
#' A real distance scale bar would misrepresent this map, since distance on
#' it deliberately does not mean distance -- this function draws a "drive
#' time scale" reference line instead, equal to `reference_minutes` of
#' typical-pace travel, rather than calling [mysterymaps_scale_bar()].
#'
#' @param polygons `sf` polygon layer, one row per area to warp.
#' @param hub_id_var `character(1)`: column in `polygons` identifying the
#'   polygon (joined to `hub_lon_var`/`hub_lat_var`/`time_var`/
#'   `straight_distance_var`, all also columns of `polygons`, one value per row).
#' @param hub_lon_var,hub_lat_var `character(1)`: numeric columns in
#'   `polygons` giving each row's hub longitude/latitude (WGS84).
#' @param time_var `character(1)`: numeric column, drive time in minutes
#'   from each polygon to its hub.
#' @param straight_distance_var `character(1)`: numeric column, straight-line
#'   distance from each polygon to its hub, in the unit named by
#'   `distance_unit`.
#' @param distance_unit `character(1)`: unit of `straight_distance_var`, one
#'   of `"miles"` (default) or `"kilometers"`. Only used to label the drive-
#'   time reference line; the warp math itself is unit-agnostic as long as
#'   `straight_distance_var` is consistent.
#' @param scale_clip Length-2 numeric: `c(min, max)` bounds on the per-row
#'   warp scale factor. Default `c(0.2, 3)`.
#' @param hub_points,hub_label Optional `sf` POINT layer of the hubs
#'   themselves (e.g. provider locations), warped the same way and drawn on
#'   top, with its own `hub_time_var`/`hub_straight_distance_var` columns
#'   (minutes/distance from each hub to *itself*, i.e. `0`, OR from each
#'   named target site to its nearest hub -- see examples in package tests).
#'   `NULL` omits.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param reference_minutes `numeric(1)`: length, in minutes of typical-pace
#'   travel, of the drawn reference line. Default `30`.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   id = 1:4,
#'   hub_lon = -97.5, hub_lat = 40.5,
#'   time_min = c(10, 20, 30, 60),
#'   straight_miles = c(9.6, 19.2, 28.8, 57.6),
#'   geometry = sf::st_sfc(lapply(1:4, function(i) {
#'     x <- -100 + i
#'     sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
#'   }), crs = 4326)
#' )
#' mysterymaps_cartogram_map(
#'   counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
#'   time_var = "time_min", straight_distance_var = "straight_miles")
mysterymaps_cartogram_map <- function(polygons,
                                      hub_id_var,
                                      hub_lon_var,
                                      hub_lat_var,
                                      time_var,
                                      straight_distance_var,
                                      distance_unit = "miles",
                                      scale_clip = c(0.2, 3),
                                      hub_points = NULL,
                                      hub_label = "Site",
                                      title = NULL,
                                      subtitle = NULL,
                                      caption = NULL,
                                      reference_minutes = 30) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_cartogram_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(polygons, "sf")
  req_cols <- c(hub_id_var, hub_lon_var, hub_lat_var, time_var, straight_distance_var)
  checkmate::assert_subset(req_cols, names(polygons))
  checkmate::assert_choice(distance_unit, c("miles", "kilometers"))
  checkmate::assert_numeric(scale_clip, len = 2, sorted = TRUE)
  if (nrow(polygons) == 0L) {
    stop("mysterymaps_cartogram_map(): `polygons` has zero rows.", call. = FALSE)
  }

  # A negative time or distance is an upstream arithmetic error, not a fast or
  # close row. Left unchecked, compute_scale_factor() below clips it to
  # scale_clip[1] -- the identical warp given to the single fastest/closest
  # LEGITIMATE row on the map, with nothing distinguishing the two.
  neg_rows <- sort(unique(c(
    which(!is.na(polygons[[time_var]]) & polygons[[time_var]] < 0),
    which(!is.na(polygons[[straight_distance_var]]) & polygons[[straight_distance_var]] < 0))))
  if (length(neg_rows)) {
    stop(sprintf(paste0(
      "mysterymaps_cartogram_map(): `%s` and/or `%s` contain negative value(s) ",
      "(row%s %s). Drive time and straight-line distance cannot be negative; ",
      "left unchecked, a negative value is clipped to `scale_clip[1]`, which ",
      "renders identically to the fastest/closest legitimate row on the map."),
      time_var, straight_distance_var,
      if (length(neg_rows) == 1L) "" else "s",
      paste(utils::head(neg_rows, 5L), collapse = ", ")), call. = FALSE)
  }

  # A longitude/latitude this far outside WGS84 range is almost always the two
  # columns swapped, not a real hub location -- and warping around it fails
  # deep inside the geometry engine (GEOS/s2) with an error naming neither this
  # function, `hub_lon_var`/`hub_lat_var`, nor a swap as the likely cause.
  lon_vals <- polygons[[hub_lon_var]]
  lat_vals <- polygons[[hub_lat_var]]
  bad_ll <- sort(unique(c(
    which(!is.na(lon_vals) & (lon_vals < -180 | lon_vals > 180)),
    which(!is.na(lat_vals) & (lat_vals < -90 | lat_vals > 90)))))
  if (length(bad_ll)) {
    stop(sprintf(paste0(
      "mysterymaps_cartogram_map(): `%s`/`%s` contain value(s) outside valid ",
      "WGS84 longitude/latitude range (row%s %s). This usually means the two ",
      "columns are swapped (latitude passed as longitude, or vice versa) ",
      "rather than a real hub location."),
      hub_lon_var, hub_lat_var,
      if (length(bad_ll) == 1L) "" else "s",
      paste(utils::head(bad_ll, 5L), collapse = ", ")), call. = FALSE)
  }

  PROJ <- 5070
  polygons_p <- sf::st_transform(polygons, PROJ)
  if (!all(sf::st_is_valid(polygons_p))) polygons_p <- sf::st_make_valid(polygons_p)

  time_vals <- polygons_p[[time_var]]
  dist_vals <- polygons_p[[straight_distance_var]]
  complete <- !is.na(time_vals) & !is.na(dist_vals)
  dist_per_min <- stats::median(dist_vals[complete], na.rm = TRUE) /
    stats::median(time_vals[complete], na.rm = TRUE)

  # The ratio below is dimensionless -- it is only valid when both sides are
  # in the SAME unit (whatever `straight_distance_var` is in). Meters are
  # needed only for the geometry warp itself, further down; mixing them in
  # here (an earlier draft multiplied the denominator by metres-per-unit but
  # not the numerator) silently scaled every polygon by ~1609x.
  dist_floor <- ifelse(distance_unit == "miles", 0.3, 0.5)
  compute_scale_factor <- function(time_min, straight_dist) {
    raw <- (time_min * dist_per_min) / pmax(straight_dist, dist_floor)
    pmin(pmax(raw, scale_clip[1]), scale_clip[2])
  }

  unit_m <- ifelse(distance_unit == "miles", 1609.344, 1000)

  warp_one <- function(geom_row, lon, lat, time_min, straight_dist) {
    hub_sf <- sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326) |> sf::st_transform(PROJ)
    hub_xy <- sf::st_coordinates(hub_sf)[1, ]
    sf_scale <- compute_scale_factor(time_min, straight_dist)
    list(geom = (geom_row - hub_xy) * sf_scale + hub_xy, scale_factor = sf_scale)
  }

  warped_rows <- lapply(seq_len(nrow(polygons_p)), function(i) {
    if (!complete[i]) return(NULL)
    g <- sf::st_geometry(polygons_p)[i]
    w <- warp_one(g, polygons_p[[hub_lon_var]][i], polygons_p[[hub_lat_var]][i],
                  time_vals[i], dist_vals[i])
    sf::st_sf(.mm_id = polygons_p[[hub_id_var]][i], .mm_time = time_vals[i],
             .mm_scale_factor = w$scale_factor,
             geometry = sf::st_set_crs(w$geom, PROJ))
  })
  warped <- do.call(rbind, Filter(Negate(is.null), warped_rows))
  warped <- sf::st_make_valid(warped)

  bb <- sf::st_bbox(warped)
  ref_x0 <- bb["xmin"] + 0.03 * (bb["xmax"] - bb["xmin"])
  ref_y0 <- bb["ymin"] + 0.06 * (bb["ymax"] - bb["ymin"])
  ref_len_m <- reference_minutes * dist_per_min * unit_m
  ref_df <- data.frame(x = c(ref_x0, ref_x0 + ref_len_m), y = c(ref_y0, ref_y0))

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = warped, mapping = ggplot2::aes(fill = .data$.mm_time),
                     color = "white", linewidth = 0.15) +
    ggplot2::geom_line(data = ref_df, mapping = ggplot2::aes(x = .data$x, y = .data$y),
                       color = "grey20", linewidth = 1) +
    # Left-justified at the reference line's own start (ref_x0), not centred
    # on the line's midpoint: a centred label extends leftward past ref_x0,
    # which sits only 3% of the panel width from bb$xmin, so it rendered off
    # the left edge of the panel on real (non-square) geography.
    # size = 8 with no size.unit defaults to millimetres (~23pt) -- large
    # enough that the label overflowed past the short reference line and
    # overlapped the warped counties beneath it. 8pt matches this package's
    # other small map annotations (see common_setup.R's rural-area labels).
    ggplot2::annotate("text", x = ref_x0, y = ref_df$y[1], vjust = -0.8, hjust = 0,
                      label = sprintf("Approximately %d-%s drive", reference_minutes, "minute"),
                      size = 8, size.unit = "pt", colour = "grey20") +
    ggplot2::scale_fill_viridis_c(name = "Real Drive Time to Nearest Provider (Minutes)",
                                  option = "inferno", direction = -1,
                                  guide = ggplot2::guide_colorbar(title.position = "top"))

  if (!is.null(hub_points)) {
    checkmate::assert_class(hub_points, "sf")
    hub_p <- sf::st_transform(hub_points, PROJ)
    p <- p + ggplot2::geom_sf(data = hub_p, mapping = ggplot2::aes(shape = hub_label),
                              fill = "#D55E00", color = "#D55E00", size = 3, stroke = 1.2) +
      ggplot2::scale_shape_manual(name = NULL, values = stats::setNames(24, hub_label))
  }

  p +
    ggplot2::coord_sf(datum = NA) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0),
      legend.position = "bottom")
}
