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
#' @section Zero is a category, not the bottom of a gradient:
#' An earlier version of this function coloured the rate with a plain
#' continuous `scale_fill_viridis_c()` (optionally log1p-transformed for
#' skew). That repeats, on a brand-new function, the exact mistake
#' [mysterymaps_jenks_zero_scale()] exists to prevent: a polygon with a
#' **measured rate of zero** (real population, no provider) rendered
#' identically to one just barely above zero, both near the dark end of the
#' gradient -- on a prior national map this put over half the counties in the
#' country into one indistinguishable "low" class when the honest answer for
#' most of them was "none". This function now classifies `.mm_rate` with
#' [mysterymaps_jenks_zero_scale()] instead: zero gets its own colour and
#' legend entry, positive rates are Jenks-classified (which is also why there
#' is no `log_scale` argument any more -- natural breaks already handle the
#' right-skewed distribution a log transform was compensating for), and a
#' polygon with a zero *denominator* (`.mm_rate` is `NA`, an undefined rate,
#' not a measured one) gets `na_color` rather than being folded into the zero
#' class.
#'
#' @param polygons `sf` polygon layer.
#' @param numerator_var,denominator_var `character(1)`: numeric columns in
#'   `polygons`.
#' @param numerator_label,denominator_label `character(1)`: full-word labels
#'   used to build the legend title.
#' @param per `numeric(1)`: rate denominator scale, e.g. `100000` for "per
#'   100,000". Default `100000`.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param k `integer(1)`: target number of Jenks classes for the positive
#'   rates, passed to [mysterymaps_jenks_zero_scale()]. Default `6`.
#' @param digits `integer(1)`: decimal places in the legend's rate labels.
#'   Default `1`; pass `0` when the rate reads more naturally as a whole
#'   number (e.g. "per 1,000" counts that are rarely fractional in practice).
#' @param zero_color,na_color Colours for a measured-zero rate and for an
#'   undefined (zero-denominator) rate, respectively. Defaults match
#'   [mysterymaps_jenks_zero_scale()]'s own.
#' @param viridis_option `character(1)`: passed to the `option` argument of
#'   the `viridisLite::viridis()` palette used for the positive classes.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   n_providers = c(1, 2, 0, 4),
#'   population = c(10000, 100000, 50000, 200000),
#'   geometry = sf::st_sfc(lapply(1:4, function(i) {
#'     x <- -100 + i
#'     sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
#'   }), crs = 4326)
#' )
#' mysterymaps_rate_choropleth_map(
#'   counties, numerator_var = "n_providers", denominator_var = "population",
#'   numerator_label = "Urogynecologists", denominator_label = "Women Age 40 and Older")
mysterymaps_rate_choropleth_map <- function(polygons,
                                            numerator_var,
                                            denominator_var,
                                            numerator_label,
                                            denominator_label,
                                            per = 100000,
                                            title = NULL,
                                            subtitle = NULL,
                                            caption = NULL,
                                            k = 6,
                                            digits = 1,
                                            zero_color = "#e0e0e0",
                                            na_color = "#ffffff",
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
  checkmate::assert_int(k, lower = 1L)
  checkmate::assert_int(digits, lower = 0L)
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

  sc <- mysterymaps_jenks_zero_scale(
    polygons_p$.mm_rate, k = k, digits = digits,
    zero_col = zero_color, na_col = na_color,
    palette = function(kk) viridisLite::viridis(kk, option = viridis_option))
  polygons_p$.mm_fill_color <- sc$color(polygons_p$.mm_rate)

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = polygons_p, mapping = ggplot2::aes(fill = .data$.mm_fill_color),
                     color = "white", linewidth = 0.15) +
    ggplot2::scale_fill_identity(name = legend_title, guide = "legend",
                                 breaks = sc$leg_cols, labels = sc$leg_labs) +
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
