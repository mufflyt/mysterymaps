#' Dot map of physician practice locations
#'
#' @description
#' Plots one point per physician over a state basemap. Ported from the
#' `isochrones` project's `THE_ONE_physician_dot_map()` after that function was
#' found to render maps with **no dots at all**, and the three traps behind that
#' failure are handled here rather than left for the next caller.
#'
#' @details
#' **Trap 1: a bare `if` inside a ggplot `+` chain swallows the rest of the
#' chain.** The original built its point layer as an inline
#' `... + if (cond) A else B + coord_sf(...) + theme(...)`. R parses `if` as
#' extending as far right as possible, so the tail of the chain became part of
#' the else branch and the layer never joined the plot. Measured on a real call:
#' 601 points reached the plotting code, the assembled plot carried three layers
#' (states, north arrow, scale bar), and the PNG contained zero coloured pixels,
#' while the caption confidently reported the physician count. Here the layer is
#' built into an object first and added as a plain term.
#'
#' **Trap 2: basemap polygons are frequently invalid.** `maps::map()` output
#' breaks `sf::st_union()` with a TopologyException. Repair is attempted, and
#' measurably must happen in PLANAR mode: `st_make_valid()` under spherical
#' geometry repaired only 44 of 49 state polygons, against all 49 with s2
#' disabled. The s2 setting is saved and restored.
#'
#' **Trap 3: an empty result is reported as an empty cohort.** Filtering a
#' subspecialty by a label the data does not use (`MIGS` where the artifact says
#' `MIG`) yields zero rows, and the original stopped with "no physicians found",
#' which reads as a real absence rather than a label mismatch. This function
#' refuses a zero-row input with a message that says so.
#'
#' @param physicians `sf` POINT layer, one row per physician.
#' @param basemap `sf` polygon layer to draw beneath the points.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param point_color Fill colour when `color_var` is `NULL`.
#' @param point_size,point_alpha Point aesthetics.
#' @param color_var Optional column in `physicians` to colour by.
#' @param palette Optional named/unnamed colour vector for `color_var`. When
#'   `NULL` a hue scale is used; passing `NULL` to `scale_color_manual()` raises
#'   "Insufficient values in manual scale", which is what the original did.
#' @param crs Projection for display. Default EPSG:5070, Albers Equal Area,
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @export
mysterymaps_physician_dot_map <- function(physicians,
                                          basemap,
                                          title = NULL,
                                          subtitle = NULL,
                                          caption = NULL,
                                          point_color = "#e74c3c",
                                          point_size = 1.4,
                                          point_alpha = 0.75,
                                          color_var = NULL,
                                          palette = NULL,
                                          crs = 5070) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_physician_dot_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use this ",
           "function.", call. = FALSE)
    }
  }
  checkmate::assert_class(physicians, "sf")
  checkmate::assert_class(basemap, "sf")
  checkmate::assert_number(point_size, lower = 0)
  checkmate::assert_number(point_alpha, lower = 0, upper = 1)

  # Trap 3. Zero rows is almost always a label mismatch upstream, not an empty
  # population, and saying "no physicians found" invites the wrong conclusion.
  if (nrow(physicians) == 0L) {
    stop("mysterymaps_physician_dot_map(): `physicians` has zero rows. This is ",
         "usually an upstream FILTER MISMATCH rather than an empty population: ",
         "check that the subspecialty or group label you filtered on is the one ",
         "the data actually uses.", call. = FALSE)
  }

  # Trap 2. Repair in planar mode, then restore the caller's s2 setting.
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))
  if (!all(sf::st_is_valid(basemap))) basemap <- sf::st_make_valid(basemap)
  if (!all(sf::st_is_valid(physicians))) physicians <- sf::st_make_valid(physicians)

  basemap_p <- sf::st_transform(basemap, crs = crs)
  points_p  <- sf::st_transform(physicians, crs = crs)

  use_color <- !is.null(color_var) && nzchar(color_var) &&
    color_var %in% names(points_p)

  # Trap 1. Build the layer FIRST. Never inline a bare `if` into a `+` chain.
  point_layer <- if (use_color) {
    ggplot2::geom_sf(
      data = points_p,
      mapping = ggplot2::aes(color = .data[[color_var]]),
      size = point_size, alpha = point_alpha, shape = 16, stroke = 0.2)
  } else {
    ggplot2::geom_sf(
      data = points_p, color = point_color,
      size = point_size, alpha = point_alpha, shape = 16, stroke = 0.2)
  }

  scale_layer <- if (!use_color) {
    NULL
  } else if (is.null(palette) || length(palette) == 0L) {
    ggplot2::scale_color_hue(name = color_var, na.value = "grey50")
  } else {
    ggplot2::scale_color_manual(values = palette, name = color_var,
                                na.value = "grey50")
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = basemap_p, fill = "#f8f9fa", color = "gray40",
                     linewidth = 0.25) +
    point_layer +
    ggplot2::coord_sf(crs = sf::st_crs(crs), datum = NA) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0),
      legend.position = if (use_color) "right" else "none")

  if (!is.null(scale_layer)) p <- p + scale_layer
  p
}
