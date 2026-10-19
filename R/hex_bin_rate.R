#' Hex-bin a rate (point count per areal-interpolated denominator)
#'
#' @description
#' Builds a hexagonal grid over `boundary_sf`, counts `points_sf` per cell
#' (the numerator), area-weight interpolates `denominator_sf[[denominator_col]]`
#' onto the same grid (the denominator -- e.g. population), and returns both
#' plus the resulting rate. This is the exact composition
#' [mysterymaps_hex_bin_counts()] was deliberately left out of (a raw point
#' count has no denominator to divide by): a rate needs a second,
#' spatially-different data source, and getting that second source onto the
#' same grid as the first is areal interpolation, not point-counting.
#'
#' @details
#' Unlike [mysterymaps_hex_bin_counts()], which drops cells below
#' `min_count` entirely, this function returns every cell in the grid,
#' including zero-count and zero-denominator ones -- a rate map needs the
#' full grid to tell "no people live here" (denominator near zero, rate
#' correctly `NA`) apart from "people live here and nothing was counted"
#' (denominator present, count zero, rate correctly `0`) apart from "people
#' live here and some things were counted" (a positive rate). Collapsing any
#' of those three into either of the others is the error
#' [mysterymaps_jenks_zero_scale()] exists to prevent, and this function's
#' output is built to feed that scale directly.
#'
#' Denominator interpolation assumes the denominator is uniformly distributed
#' within each `denominator_sf` polygon -- the standard areal-interpolation
#' assumption ([sf::st_interpolate_aw()], `extensive = TRUE`, appropriate
#' because a population count is additive: a hex covering half a tract is
#' assumed to hold half that tract's people). It is weakest where the
#' denominator is not actually uniform within a polygon, which it rarely is
#' exactly -- the same caveat as any choropleth built on areal units coarser
#' than the thing being counted.
#'
#' A point that lands exactly on a shared edge between two hex cells is
#' counted in both -- an inherent property of intersecting points against a
#' `sf::st_make_grid()` lattice, shared with [mysterymaps_hex_bin_counts()]
#' and [mm_honeycomb_counts()]. Negligible for real geocoded coordinates
#' (probability zero in practice); a hazard only for hand-constructed or
#' deliberately round test/example coordinates.
#'
#' @param boundary_sf `sf`: polygon(s) defining the study area the grid is
#'   built over and clipped to.
#' @param points_sf `sf`: point data to count per hex cell (the numerator).
#' @param denominator_sf `sf`: polygon layer carrying the denominator (e.g.
#'   census tracts with a population column). Does not need to share
#'   `boundary_sf`'s or `points_sf`'s CRS; transformed automatically.
#' @param denominator_col `character(1)`: numeric column in `denominator_sf`
#'   to interpolate (e.g. `"female_pop"`).
#' @param per `numeric(1)`: rate denominator scale, e.g. `100000` for "per
#'   100,000". Default `1` (a plain proportion).
#' @param cellsize `numeric(1)`: hexagon size in the units of `boundary_sf`'s
#'   CRS (degrees, if left in EPSG:4326). Default `0.3`.
#' @param min_denominator `numeric(1)`: cells whose interpolated denominator
#'   falls below this are reported with `rate = NA` rather than a rate --
#'   a cell with a handful of interpolated residents produces a wild,
#'   near-meaningless rate (one point in a 40-person cell reads as
#'   2,500-per-100k). Default `0` (no suppression; set this per study, the
#'   way [mysterymaps_accessibility_map()]'s caller would set a population
#'   floor).
#' @param value_col `character(1)`: name of the output rate column. Default
#'   `"rate"`.
#'
#' @return An `sf` of every hex cell in the grid, carrying `count` (integer,
#'   numerator), `denominator` (numeric, interpolated), and `value_col`
#'   (numeric, `NA` where `denominator < min_denominator`).
#' @seealso [mysterymaps_hex_bin_counts()] for a plain count with no
#'   denominator; [mysterymaps_jenks_zero_scale()] to colour the result.
#' @family geospatial
#' @export
#' @examplesIf interactive()
#' boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
#'   sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
#'   crs = 4326))
#' points_sf <- sf::st_as_sf(
#'   data.frame(lon = c(-99.1, -98.4, -97.7), lat = c(40.1, 40.3, 41.2)),
#'   coords = c("lon", "lat"), crs = 4326)
#' denominator_sf <- sf::st_sf(
#'   population = c(5000, 8000),
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(cbind(c(-100, -98.5, -98.5, -100, -100), c(39, 39, 42, 42, 39)))),
#'     sf::st_polygon(list(cbind(c(-98.5, -97, -97, -98.5, -98.5), c(39, 39, 42, 42, 39)))),
#'     crs = 4326))
#' mysterymaps_hex_bin_rate(boundary_sf, points_sf, denominator_sf, "population",
#'                          per = 1000, cellsize = 0.5)
mysterymaps_hex_bin_rate <- function(boundary_sf,
                                     points_sf,
                                     denominator_sf,
                                     denominator_col,
                                     per = 1,
                                     cellsize = 0.3,
                                     min_denominator = 0,
                                     value_col = "rate") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("mysterymaps_hex_bin_rate() needs the 'sf' package, which is a ",
         "Suggests dependency. Install it to use this function.", call. = FALSE)
  }
  checkmate::assert_class(boundary_sf, "sf")
  checkmate::assert_class(points_sf, "sf")
  checkmate::assert_class(denominator_sf, "sf")
  checkmate::assert_string(denominator_col)
  checkmate::assert_subset(denominator_col, names(denominator_sf))
  checkmate::assert_number(per, lower = 0)
  checkmate::assert_number(cellsize, lower = 0, finite = TRUE)
  if (cellsize == 0) {
    stop("mysterymaps_hex_bin_rate(): `cellsize` must be strictly positive. ",
         "0 asks sf::st_make_grid() for a grid of zero-size hexagons, which it ",
         "rejects with an unrelated, cryptic error (\"invalid '(to - from)/by'\") ",
         "rather than naming the real cause.", call. = FALSE)
  }
  checkmate::assert_number(min_denominator, lower = 0, finite = TRUE)
  checkmate::assert_string(value_col)
  if (nrow(boundary_sf) == 0L) {
    stop("mysterymaps_hex_bin_rate(): `boundary_sf` has zero rows.", call. = FALSE)
  }

  crs <- sf::st_crs(boundary_sf)
  if (is.na(crs)) {
    stop("mysterymaps_hex_bin_rate(): `boundary_sf` must have a defined CRS.",
         call. = FALSE)
  }

  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))

  boundary_sf <- sf::st_make_valid(boundary_sf)
  points_sf <- sf::st_transform(points_sf, crs)
  denominator_sf <- sf::st_make_valid(sf::st_transform(denominator_sf, crs))

  # The full grid -- every cell, not just ones a point landed in -- is what
  # lets a downstream zero-aware scale tell "zero count, real population"
  # apart from "no population to measure" apart from "not counted at all".
  grid <- sf::st_make_grid(boundary_sf, c(cellsize, cellsize), what = "polygons",
                           square = FALSE) %>%
    sf::st_sf() %>%
    dplyr::mutate(grid_id = dplyr::row_number()) %>%
    sf::st_intersection(sf::st_union(boundary_sf))

  counts <- sf::st_intersection(grid, points_sf) %>%
    dplyr::group_by(.data$grid_id) %>%
    dplyr::summarize(count = dplyr::n(), .groups = "drop")

  denom_interp <- suppressWarnings(
    sf::st_interpolate_aw(denominator_sf[, denominator_col], grid, extensive = TRUE))

  # SPATIAL joins, not attribute joins on grid_id: st_intersection(grid,
  # boundary_sf) can fragment one hex into several polygon pieces along an
  # irregular boundary, all sharing the SAME grid_id -- an attribute join
  # fans count/population out across every sibling fragment instead of
  # matching the one fragment that's actually theirs. counts' geometry
  # (summarized points, grouped but not dropped) spatially intersects only
  # its own fragment; st_interpolate_aw() returns geometry copied directly
  # from grid's own rows (just a possibly-shorter subset, dropping cells with
  # no source overlap), so an exact st_equals match reattaches each
  # interpolated value to precisely the fragment it was computed for,
  # ambiguity-free regardless of duplicate grid_id.
  out <- grid[, "grid_id"] %>%
    sf::st_join(counts[, "count"]) %>%
    sf::st_join(denom_interp, join = sf::st_equals) %>%
    dplyr::mutate(
      count = dplyr::coalesce(.data$count, 0L),
      denominator = dplyr::coalesce(.data[[denominator_col]], 0))

  # A zero denominator makes the rate 0/0 -- undefined, not "below the
  # reporting floor" -- regardless of min_denominator, the same distinction
  # mysterymaps_rate_choropleth_map() makes for a zero-population polygon.
  out[[value_col]] <- ifelse(
    out$denominator > 0 & out$denominator >= min_denominator,
    out$count / out$denominator * per,
    NA_real_)

  out[, c("grid_id", "count", "denominator", value_col)]
}
