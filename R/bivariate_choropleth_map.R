#' Default bivariate choropleth palette (3x3 classes)
#'
#' @description
#' Teal/magenta/blue palette (after Joshua Stevens' widely-used bivariate
#' scheme) for [mysterymaps_bivariate_choropleth_map()]. Keys are
#' `"<x_class>-<y_class>"`, each `1` (low) to `3` (high).
#'
#' @format A named character vector of 9 hex colours.
#' @export
MYSTERYMAPS_BIVARIATE_PALETTE <- c(
  "1-1" = "#e8e8e8", "2-1" = "#ace4e4", "3-1" = "#5ac8c8",
  "1-2" = "#dfb0d6", "2-2" = "#a5add3", "3-2" = "#5698b9",
  "1-3" = "#be64ac", "2-3" = "#8c62aa", "3-3" = "#3b4994"
)

#' Two-variable (bivariate) choropleth map
#'
#' @description
#' Shades each polygon by the joint tercile class of two numeric variables
#' at once -- e.g. population need versus provider scarcity -- so a reader
#' sees where the two overlap without needing two separate maps. Includes a
#' 3x3 legend grid rendered as an inset, not a separate figure.
#'
#' @details
#' The legend inset is built with [ggplot2::annotation_custom()] around a
#' small second `ggplot`, not `cowplot::draw_plot()`. This package does not
#' depend on `cowplot`, and `annotation_custom()` does the same job -- drawing
#' one grob inside another plot's panel -- without adding a dependency for it.
#'
#' Each variable is split into terciles independently with
#' [classInt::classIntervals()] (`style = "quantile"`), so the bivariate class
#' reflects each variable's own distribution rather than a shared arbitrary
#' cutoff. A polygon with `NA` in either variable gets `NA` for the joint
#' class and is drawn in `na_color`.
#'
#' @param polygons `sf` polygon layer.
#' @param x_var,y_var `character(1)`: numeric columns in `polygons`.
#' @param x_label,y_label `character(1)`: full-word axis labels for the legend
#'   grid (e.g. `"Women Age 40 and Older"`, not `"Women 40+"`).
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param palette Named length-9 colour vector, keys `"1-1"` .. `"3-3"`
#'   (x class first, y class second). Default [MYSTERYMAPS_BIVARIATE_PALETTE].
#' @param na_color Colour for polygons missing `x_var` or `y_var`.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#' @param legend_position `character(1)`: corner for the legend inset, one of
#'   `"br"`, `"bl"`, `"tr"`, `"tl"`. Default `"br"`, which leaves the
#'   bottom-left corner free for [mysterymaps_scale_bar()].
#' @param legend_size `numeric(1)`: the inset's width and height, as a
#'   fraction of `polygons`' bounding-box width and height respectively.
#'   Default `0.16`. A bounding-box CORNER is usually the part of an
#'   irregular shape (a coastline, a state outline) farthest from the shape
#'   itself, so a small inset tucked flush into one, as this is by default,
#'   generally lands in blank space rather than over the mapped area; shrink
#'   `legend_size` further for a shape where that isn't true, or pick a
#'   different `legend_position`.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   rate = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
#'   need = c(9, 8, 7, 6, 5, 4, 3, 2, 1),
#'   geometry = sf::st_sfc(lapply(1:9, function(i) {
#'     x <- -100 + i
#'     sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
#'   }), crs = 4326)
#' )
#' mysterymaps_bivariate_choropleth_map(
#'   counties, x_var = "rate", y_var = "need",
#'   x_label = "Providers per Capita", y_label = "Population Need")
mysterymaps_bivariate_choropleth_map <- function(polygons,
                                                  x_var,
                                                  y_var,
                                                  x_label,
                                                  y_label,
                                                  title = NULL,
                                                  subtitle = NULL,
                                                  caption = NULL,
                                                  palette = MYSTERYMAPS_BIVARIATE_PALETTE,
                                                  na_color = "grey85",
                                                  crs = 5070,
                                                  legend_position = "br",
                                                  legend_size = 0.16) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_bivariate_choropleth_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_string(x_var)
  checkmate::assert_string(y_var)
  checkmate::assert_string(x_label)
  checkmate::assert_string(y_label)
  checkmate::assert_subset(c(x_var, y_var), names(polygons))
  checkmate::assert_choice(legend_position, c("br", "bl", "tr", "tl"))
  checkmate::assert_number(legend_size, lower = 0, upper = 1)
  if (nrow(polygons) == 0L) {
    stop("mysterymaps_bivariate_choropleth_map(): `polygons` has zero rows.",
         call. = FALSE)
  }

  tercile_class <- function(x) {
    x_complete <- x[!is.na(x)]
    cls <- rep(NA_integer_, length(x))
    rank_based_fallback <- function() {
      # Too few distinct values for three quantile classes, OR enough
      # distinct values but a skewed enough distribution that the quantile
      # breaks themselves collapse to duplicates (classInt::classIntervals
      # can do this with >=3 distinct values present overall -- e.g. a third
      # or more of the values tied at the same minimum, which a sparse,
      # areally-interpolated denominator like hex-cell population routinely
      # produces).
      #
      # REGRESSION: rank(x, ties.method = "first") breaks ties by each
      # value's position in x, not by anything about the data -- on a
      # nationwide hex map where 86% of cells had count == 0 (physicians),
      # that scattered the SAME tied value across all three classes purely
      # by st_make_grid()'s row order, which sweeps geographically. The
      # result was three near-perfect vertical bands at mean longitudes
      # -113.9/-97.5/-81.7 for cells that were all, in fact, zero -- a map
      # artifact with zero informational content, read (correctly) as "that
      # can't be correct." Classing the DISTINCT values into terciles and
      # looking each observation up by its value, instead of ranking raw
      # observations, guarantees every tied value lands in one class
      # together -- here, nearly all of class 1, honestly.
      distinct_vals <- sort(unique(x_complete))
      value_class <- pmin(ceiling(3 * seq_along(distinct_vals) / length(distinct_vals)), 3L)
      unname(value_class[match(x_complete, distinct_vals)])
    }
    if (length(unique(x_complete)) < 3L) {
      cls[!is.na(x)] <- pmin(rank_based_fallback(), 3L)
      return(cls)
    }
    breaks <- classInt::classIntervals(x_complete, n = 3, style = "quantile")$brks
    if (length(unique(breaks)) < length(breaks)) {
      cls[!is.na(x)] <- pmin(rank_based_fallback(), 3L)
      return(cls)
    }
    breaks[1] <- -Inf; breaks[length(breaks)] <- Inf
    cls[!is.na(x)] <- as.integer(cut(x_complete, breaks = breaks, labels = FALSE))
    cls
  }

  x_class <- tercile_class(polygons[[x_var]])
  y_class <- tercile_class(polygons[[y_var]])
  bivar_key <- ifelse(is.na(x_class) | is.na(y_class), NA_character_,
                      paste0(x_class, "-", y_class))
  polygons$.mm_bivar_key <- bivar_key

  polygons_p <- sf::st_transform(polygons, crs = crs)

  # The legend lives in a margin OUTSIDE the mapped area, not a notch tucked
  # inside one of its bounding-box corners. A corner of a shape's bounding
  # box is not reliably empty space for an irregular coastline -- Florida
  # reaches close enough to the CONUS bbox's bottom-right corner that an
  # inset legend there clipped straight into the state. Reserving a strip
  # beyond xlim/ylim and placing the legend there is correct for any shape.
  bb <- sf::st_bbox(polygons_p)
  xr <- bb["xmax"] - bb["xmin"]; yr <- bb["ymax"] - bb["ymin"]
  gap <- 0.02
  legend_w <- legend_size * xr
  legend_h <- legend_size * yr
  margin <- (2 * gap + legend_size) * yr
  below <- legend_position %in% c("br", "bl")
  xlim <- c(bb["xmin"], bb["xmax"])
  ylim <- if (below) c(bb["ymin"] - margin, bb["ymax"]) else c(bb["ymin"], bb["ymax"] + margin)

  p_main <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = polygons_p, mapping = ggplot2::aes(fill = .data$.mm_bivar_key),
                     color = "white", linewidth = 0.15) +
    ggplot2::scale_fill_manual(values = palette, na.value = na_color, guide = "none") +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::coord_sf(crs = sf::st_crs(crs), datum = NA,
                      xlim = xlim, ylim = ylim, expand = FALSE) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0))

  legend_df <- data.frame(
    x = as.integer(sub("-.*", "", names(palette))),
    y = as.integer(sub(".*-", "", names(palette))),
    fill = unname(palette))
  p_legend <- ggplot2::ggplot(legend_df, ggplot2::aes(x = .data$x, y = .data$y,
                                                      fill = .data$fill)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_identity() +
    ggplot2::labs(x = paste("Higher", x_label, "->"),
                 y = paste("Higher", y_label, "->")) +
    ggplot2::theme_void(base_size = 7) +
    ggplot2::theme(
      axis.title.x = ggplot2::element_text(size = ggplot2::rel(1)),
      axis.title.y = ggplot2::element_text(size = ggplot2::rel(1), angle = 90),
      plot.background = ggplot2::element_rect(fill = "white", colour = "grey60"))

  right <- legend_position %in% c("br", "tr")
  inset_x <- if (right) c(bb["xmax"] - legend_w, bb["xmax"]) else c(bb["xmin"], bb["xmin"] + legend_w)
  inset_y <- if (below) c(bb["ymin"] - margin + gap * yr, bb["ymin"] - margin + gap * yr + legend_h) else
    c(bb["ymax"] + margin - gap * yr - legend_h, bb["ymax"] + margin - gap * yr)
  inset <- list(xmin = inset_x[1], xmax = inset_x[2], ymin = inset_y[1], ymax = inset_y[2])

  p_main + ggplot2::annotation_custom(
    ggplot2::ggplotGrob(p_legend),
    xmin = inset$xmin, xmax = inset$xmax, ymin = inset$ymin, ymax = inset$ymax)
}
