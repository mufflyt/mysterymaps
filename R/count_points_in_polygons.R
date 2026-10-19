#' Count points falling within each polygon of a layer
#'
#' @description
#' Point-in-polygon count via an intersects spatial join. Polygons with no
#' points get `0`, not `NA`, so the count is safe to colour or bin directly
#' without a separate `coalesce()` step at every call site.
#'
#' @param polygons `sf` polygon layer carrying a unique `id` column.
#' @param points `sf` point layer (any CRS; transformed to match `polygons`
#'   automatically).
#' @param count_col `character(1)`: name of the integer output column.
#'   Default `"n"`.
#' @return `polygons` with an added integer count column named `count_col`.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   id = 1:2,
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
#'     sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
#'     crs = 4326))
#' points <- sf::st_as_sf(data.frame(lon = c(-99, -97, -97), lat = c(40, 40, 40.2)),
#'                        coords = c("lon", "lat"), crs = 4326)
#' mysterymaps_count_points_in_polygons(counties, points)
mysterymaps_count_points_in_polygons <- function(polygons, points, count_col = "n") {
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_class(points, "sf")
  checkmate::assert_string(count_col)
  checkmate::assert_subset("id", names(polygons))
  # A duplicate id makes the join below fan out: every point touching either
  # duplicate-id polygon gets counted into BOTH rows, silently inflating the
  # total (measured: 2 real points became 4 "counted" across a duplicated
  # id). The doc above already promises a unique id; this enforces it.
  dupe <- unique(polygons$id[duplicated(polygons$id)])
  if (length(dupe)) {
    stop("mysterymaps_count_points_in_polygons(): `polygons$id` has duplicate value(s): ",
         paste(utils::head(dupe, 10L), collapse = ", "),
         if (length(dupe) > 10L) sprintf(" (and %d more)", length(dupe) - 10L) else "",
         ". `id` must be unique -- a duplicate id makes the point-in-polygon join fan ",
         "out, double-counting every point that touches either copy.", call. = FALSE)
  }

  pts <- sf::st_transform(points, sf::st_crs(polygons))
  pts$.one <- 1L
  hit <- sf::st_join(pts[".one"], polygons["id"], join = sf::st_intersects, left = FALSE)
  tab <- dplyr::count(sf::st_drop_geometry(hit), .data$id, name = count_col)
  out <- dplyr::left_join(polygons, tab, by = "id")
  out[[count_col]] <- dplyr::coalesce(out[[count_col]], 0L)
  out
}
