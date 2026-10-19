#' Aggregate polygon-level values up to a different, arbitrary polygon layer
#'
#' @description
#' Used when a target geography is not the same as the source geography (e.g.
#' rolling county-level values up to Hospital Referral Regions, which do not
#' nest inside standard Census geographies). Each source polygon is reduced to
#' an interior point ([sf::st_point_on_surface()]) and assigned to whichever
#' target polygon contains it; values are then summed per target.
#'
#' @details
#' This is an approximation for a source polygon that straddles a target
#' boundary: it is assigned whole to one target rather than split
#' proportionally by area, so a source value near a target boundary can land
#' on either side depending on where its interior point happens to fall.
#'
#' @param source_poly `sf` polygons with an `id` column (e.g. counties).
#' @param source_values `data.frame` with columns `id` and `value_col`.
#' @param target_poly `sf` polygons with an `id` column (e.g. HRRs).
#' @param value_col `character(1)`: name of the value column to sum. Default
#'   `"n"`.
#' @return A tibble with columns `id` (the target id) and `value_col` (summed).
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   id = 1:2,
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
#'     sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
#'     crs = 4326))
#' regions <- sf::st_sf(
#'   id = "R1",
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-101, -95, -95, -101, -101), c(38, 38, 42, 42, 38)))),
#'     crs = 4326))
#' mysterymaps_aggregate_values_to_polygons(
#'   counties, data.frame(id = 1:2, n = c(3, 4)), regions, value_col = "n")
mysterymaps_aggregate_values_to_polygons <- function(source_poly, source_values,
                                                      target_poly, value_col = "n") {
  checkmate::assert_class(source_poly, "sf")
  checkmate::assert_data_frame(source_values)
  checkmate::assert_class(target_poly, "sf")
  checkmate::assert_string(value_col)
  checkmate::assert_subset("id", names(source_poly))
  checkmate::assert_subset("id", names(target_poly))
  checkmate::assert_subset(c("id", value_col), names(source_values))
  # A duplicate id in source_poly becomes two independent interior points,
  # each pulling the SAME value via match() -- the value is then summed
  # twice into the target. Measured: county id 1 duplicated turned a 15 total
  # into 25. The @param doc already implies one row per id; this enforces it.
  dupe <- unique(source_poly$id[duplicated(source_poly$id)])
  if (length(dupe)) {
    stop("mysterymaps_aggregate_values_to_polygons(): `source_poly$id` has duplicate ",
         "value(s): ", paste(utils::head(dupe, 10L), collapse = ", "),
         if (length(dupe) > 10L) sprintf(" (and %d more)", length(dupe) - 10L) else "",
         ". `id` must be unique -- a duplicate id is counted as two independent source ",
         "polygons, each contributing the same value, so the target's sum is inflated.",
         call. = FALSE)
  }
  # Two target polygons sharing an id are indistinguishable once this result is
  # joined back onto target_poly: both receive the identical summed value, even
  # though they are physically different areas that may draw from entirely
  # different source polygons.
  dupe_target <- unique(target_poly$id[duplicated(target_poly$id)])
  if (length(dupe_target)) {
    stop("mysterymaps_aggregate_values_to_polygons(): `target_poly$id` has duplicate ",
         "value(s): ", paste(utils::head(dupe_target, 10L), collapse = ", "),
         if (length(dupe_target) > 10L) sprintf(" (and %d more)", length(dupe_target) - 10L) else "",
         ". `id` must be unique -- two target polygons sharing an id both receive the ",
         "identical summed value when this result is joined back, even if they are ",
         "physically different areas.", call. = FALSE)
  }

  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))

  src <- suppressWarnings(sf::st_point_on_surface(sf::st_transform(source_poly, 4326)))["id"]
  src[[value_col]] <- source_values[[value_col]][match(src$id, source_values$id)]
  hit <- sf::st_join(src[value_col], sf::st_transform(target_poly, 4326)["id"],
                     join = sf::st_within)
  hit <- sf::st_drop_geometry(hit)
  hit <- hit[!is.na(hit$id), , drop = FALSE]
  out <- stats::aggregate(hit[[value_col]], by = list(id = hit$id), FUN = sum, na.rm = TRUE)
  stats::setNames(dplyr::as_tibble(out), c("id", value_col))
}
