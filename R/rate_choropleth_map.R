#' Rate choropleth map (numerator per denominator)
#'
#' @description
#' Shades each polygon by a rate -- `numerator_var / denominator_var * per`
#' -- rather than a raw count, so a reader compares areas fairly instead of
#' larger-population areas simply looking darker.
#'
#' @details
#' This function takes `polygons` with both variables already attached and
#' does no joining itself. That is deliberate: in at least one prior use of
#' this pattern (Virginia counties), joining a rate's two halves by the
#' `NAME` column silently merged the wrong rows, because Fairfax, Franklin,
#' Richmond, and Roanoke each name both a county AND a same-named independent
#' city. Push any such join to the caller, and join by a stable identifier
#' (e.g. `GEOID`), never by a place name.
#'
#' The legend title is always built from `numerator_label` and
#' `denominator_label` in full words -- pass `"Urogynecologists"` and
#' `"Women Age 40 and Older"`, not `"Urogyn"` and `"W40+"` -- because this
#' title is the one place in the map an abbreviation would otherwise land by
#' default.
#'
#' @param polygons `sf` polygon layer.
#' @param numerator_var,denominator_var `character(1)`: numeric columns in
#'   `polygons`.
#' @param numerator_label,denominator_label `character(1)`: full-word labels
#'   used to build the legend title.
#' @param per `numeric(1)`: rate denominator scale, e.g. `100000` for "per
#'   100,000". Default `100000`.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param log_scale `logical(1)`: colour on a log1p scale. Default `TRUE`;
#'   rates in this kind of map are typically right-skewed (many near-zero
#'   areas, a few much higher), and a linear scale would wash out all the
#'   low end into one colour.
#' @param viridis_option `character(1)`: passed to
#'   [ggplot2::scale_fill_viridis_c()]'s `option`.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
mysterymaps_rate_choropleth_map <- function(polygons,
                                            numerator_var,
                                            denominator_var,
                                            numerator_label,
                                            denominator_label,
                                            per = 100000,
                                            title = NULL,
                                            subtitle = NULL,
                                            caption = NULL,
                                            log_scale = TRUE,
                                            viridis_option = "viridis",
                                            crs = 5070) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_rate_choropleth_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_string(numerator_var)
  checkmate::assert_string(denominator_var)
  checkmate::assert_string(numerator_label)
  checkmate::assert_string(denominator_label)
  checkmate::assert_subset(c(numerator_var, denominator_var), names(polygons))
  checkmate::assert_number(per, lower = 0)
  checkmate::assert_flag(log_scale)
  if (nrow(polygons) == 0L) {
    stop("mysterymaps_rate_choropleth_map(): `polygons` has zero rows.",
         call. = FALSE)
  }

  denom <- polygons[[denominator_var]]
  rate <- ifelse(denom > 0, polygons[[numerator_var]] / denom * per, NA_real_)
  polygons$.mm_rate <- rate

  polygons_p <- sf::st_transform(polygons, crs = crs)

  per_fmt <- format(per, big.mark = ",", scientific = FALSE)
  legend_title <- sprintf("%s per %s\n%s", numerator_label, per_fmt, denominator_label)

  fill_scale <- if (log_scale) {
    ggplot2::scale_fill_viridis_c(name = legend_title, option = viridis_option,
                                  trans = "log1p", na.value = "grey85",
                                  guide = ggplot2::guide_colorbar(title.position = "top"))
  } else {
    ggplot2::scale_fill_viridis_c(name = legend_title, option = viridis_option,
                                  na.value = "grey85",
                                  guide = ggplot2::guide_colorbar(title.position = "top"))
  }

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = polygons_p, mapping = ggplot2::aes(fill = .data$.mm_rate),
                     color = "white", linewidth = 0.15) +
    fill_scale +
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
