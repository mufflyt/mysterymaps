#' One-call E2SFCA accessibility map
#'
#' @description
#' Joins a `twostep::compute_e2sfca()` result onto its tract geometry and
#' renders it with the three-way zero/outside/missing distinction the result
#' already carries -- in one call, instead of each caller re-deriving the join
#' and the colour classification by hand.
#'
#' @details
#' `compute_e2sfca()`'s `$access` tibble distinguishes three states that a plain
#' continuous choropleth collapses into two:
#'
#' \describe{
#'   \item{a measured zero}{`coverage_status == "within_modeled_catchment"` and
#'     the accessibility score is `0` -- the tract is reached, and the weighted
#'     supply reaching it is genuinely nil. Takes `zero_color`.}
#'   \item{outside every catchment}{`coverage_status ==
#'     "outside_all_modeled_catchments"` -- no isochrone reaches this tract at
#'     all. This is the finding an access study usually exists to report, and
#'     is emphatically not missing data. Takes `outside_color`.}
#'   \item{missing}{`value_col` is `NA` for a reached tract, or the tract's
#'     `GEOID` has no match in `tracts_sf`. Takes `na_color`.}
#' }
#'
#' Before this distinction existed in `twostep`, outside-catchment tracts were
#' zero-filled and became indistinguishable from a measured zero -- 190 of
#' 1,447 Colorado tracts, 13% of the state, each reported as "zero
#' accessibility" when the honest answer was "the model never reached here".
#' [mysterymaps_jenks_zero_scale()]'s `coverage` argument exists specifically
#' for this shape, via `coverage_status`; this function is the one-call
#' assembler for it, the same role [mysterymaps_county_access_map()] plays for
#' a plain leaflet supply choropleth.
#'
#' This function does not call `twostep::compute_e2sfca()` itself and does not
#' depend on the `twostep` package -- it only consumes the list shape that
#' function documents returning, so a caller can pass in anything with the
#' same shape.
#'
#' @param e2sfca_result `list`: the object `twostep::compute_e2sfca()` returns.
#'   Must contain an `access` element: a data frame with columns `GEOID`,
#'   `coverage_status`, and `value_col`.
#' @param tracts_sf `sf` polygon layer with a `GEOID` column to join
#'   `e2sfca_result$access` onto.
#' @param value_col `character(1)`: column in `e2sfca_result$access` to map.
#'   Default `"access_scaled"` -- the per-capita-scaled score (e.g. "per
#'   100,000 women"), which `compute_e2sfca()`'s own documentation names as
#'   the scientific value a reader, table or map should consume. Pass
#'   `"access"` for the unscaled score.
#' @param legend_title `character(1)`: legend heading. Default `"Modeled
#'   Accessibility"`.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param k `integer(1)`: target number of Jenks classes for the positive
#'   scores, passed to [mysterymaps_jenks_zero_scale()]. Default `6`.
#' @param digits `integer(1)`: decimal places in the legend's score labels.
#'   Default `1`.
#' @param zero_color,na_color,outside_color Colours for a measured zero, a
#'   missing value, and a tract outside every modelled catchment,
#'   respectively. Defaults match [mysterymaps_jenks_zero_scale()]'s own.
#' @param viridis_option `character(1)`: passed to the `option` argument of
#'   the `viridisLite::viridis()` palette used for the positive classes.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' # The shape compute_e2sfca() returns -- see twostep::compute_e2sfca()'s own
#' # examples for how `access` is actually produced from provider isochrones.
#' e2sfca_result <- list(access = data.frame(
#'   GEOID = c("T1", "T2", "T3", "T4"),
#'   access_scaled = c(0, 4.2, NA, 7.8),
#'   coverage_status = c("within_modeled_catchment", "within_modeled_catchment",
#'                       "outside_all_modeled_catchments", "within_modeled_catchment")
#' ))
#' tracts_sf <- sf::st_sf(
#'   GEOID = c("T1", "T2", "T3", "T4"),
#'   geometry = sf::st_sfc(lapply(1:4, function(i) {
#'     x <- -100 + i
#'     sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
#'   }), crs = 4326)
#' )
#' mysterymaps_accessibility_map(e2sfca_result, tracts_sf)
mysterymaps_accessibility_map <- function(e2sfca_result,
                                          tracts_sf,
                                          value_col = "access_scaled",
                                          legend_title = "Modeled Accessibility",
                                          title = NULL,
                                          subtitle = NULL,
                                          caption = NULL,
                                          k = 6,
                                          digits = 1,
                                          zero_color = "#e0e0e0",
                                          na_color = "#ffffff",
                                          outside_color = "#efe7d5",
                                          viridis_option = "viridis",
                                          crs = 5070) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_accessibility_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_list(e2sfca_result)
  if (!"access" %in% names(e2sfca_result)) {
    stop("mysterymaps_accessibility_map(): `e2sfca_result` has no `access` ",
         "element. Pass the list twostep::compute_e2sfca() returns, not just ",
         "its `$access` tibble.", call. = FALSE)
  }
  access <- e2sfca_result$access
  checkmate::assert_data_frame(access)
  checkmate::assert_string(value_col)
  checkmate::assert_subset(c("GEOID", "coverage_status", value_col), names(access))
  checkmate::assert_class(tracts_sf, "sf")
  checkmate::assert_subset("GEOID", names(tracts_sf))
  checkmate::assert_int(k, lower = 1L)
  checkmate::assert_int(digits, lower = 0L)
  if (nrow(tracts_sf) == 0L) {
    stop("mysterymaps_accessibility_map(): `tracts_sf` has zero rows.", call. = FALSE)
  }

  # A left join from the geometry side, not the access side: a GEOID in
  # `access` with no matching polygon has nothing to draw and is silently
  # dropped either way, but a polygon with no matching GEOID in `access` must
  # surface as "missing", not vanish from the map entirely.
  joined <- dplyr::left_join(
    tracts_sf, access[, c("GEOID", "coverage_status", value_col)], by = "GEOID")

  joined_p <- sf::st_transform(joined, crs = crs)

  # A polygon whose GEOID matched nothing in `access` carries coverage_status
  # == NA from the join -- which is correctly NOT "outside every catchment"
  # (that is a specific, known finding; this is the absence of one) and
  # mysterymaps_jenks_zero_scale() refuses to guess at a bare NA, by design.
  # Recode it to "within" so the classification falls through to the ordinary
  # missing-value path instead: value_col is NA for the same unmatched row, so
  # it still lands on na_color, just via the right route.
  coverage_vec <- joined_p$coverage_status
  coverage_vec[is.na(coverage_vec)] <- "within_modeled_catchment"

  sc <- mysterymaps_jenks_zero_scale(
    joined_p[[value_col]], k = k, digits = digits,
    zero_col = zero_color, na_col = na_color,
    coverage = coverage_vec, outside_col = outside_color,
    palette = function(kk) viridisLite::viridis(kk, option = viridis_option))
  joined_p$.mm_fill_color <- sc$color(joined_p[[value_col]], coverage = coverage_vec)

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = joined_p, mapping = ggplot2::aes(fill = .data$.mm_fill_color),
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
