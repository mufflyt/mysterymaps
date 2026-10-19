#' Default isochrone drive-time bands, in minutes
#'
#' @description
#' The four bands this package's isochrone-consuming map functions default
#' to: 30, 60, 120, and 180 minutes. Centralized so every function that takes
#' a `bands_minutes` argument shares one default instead of each re-typing
#' (and risking drift on) its own copy.
#'
#' @format An integer vector, length 4.
#' @export
MYSTERYMAPS_ISOCHRONE_BANDS_MINUTES <- c(30L, 60L, 120L, 180L)

#' Add an imperial-unit scale bar to a ggplot map
#'
#' @description
#' Thin wrapper around [ggspatial::annotation_scale()] that defaults to miles
#' instead of kilometers.
#'
#' @details
#' `unit_category = "imperial"` is accepted by `annotation_scale()` only
#' through its `...` forwarding -- it does not appear in the function's own
#' formal arguments (`args(ggspatial::annotation_scale)` omits it). A caller
#' who does not already know that can reasonably assume the function has no
#' imperial option and ship a kilometer bar on a United States map, silently:
#' there is no error or warning either way. This wrapper exists so every
#' static map in this package picks up miles by default without each caller
#' having to rediscover the `...`-forwarding behaviour.
#'
#' @param location `character(1)`: corner to place the bar in -- one of
#'   `"bl"`, `"br"`, `"tl"`, `"tr"`.
#' @param width_hint `numeric(1)`: target width as a fraction of the plot panel.
#' @param unit_category `character(1)`: passed through to
#'   [ggspatial::annotation_scale()]. Default `"imperial"`; pass `"metric"`
#'   or `"SI"` to override.
#' @param ... Additional arguments forwarded to
#'   [ggspatial::annotation_scale()] (e.g. `bar_cols`, `text_cex`, `pad_x`).
#'
#' @return A ggplot2 layer, addable to a plot with `+`.
#' @family mapping
#' @export
#' @examplesIf interactive() && requireNamespace("ggspatial", quietly = TRUE)
#' library(ggplot2)
#' ggplot() + mysterymaps_scale_bar()
mysterymaps_scale_bar <- function(location = "bl", width_hint = 0.25,
                                  unit_category = "imperial", ...) {
  if (!requireNamespace("ggspatial", quietly = TRUE)) {
    stop("mysterymaps_scale_bar() needs the 'ggspatial' package, which is a ",
         "Suggests dependency. Install it to use this function.", call. = FALSE)
  }
  checkmate::assert_choice(location, c("bl", "br", "tl", "tr"))
  checkmate::assert_number(width_hint, lower = 0, upper = 1)
  ggspatial::annotation_scale(location = location, width_hint = width_hint,
                              unit_category = unit_category, ...)
}

#' Jitter sf points by a fixed real-world radius, deterministically
#'
#' @description
#' Displaces each point in a random direction by up to `miles`, measured as a
#' real ground distance (via EPSG:5070, meters) rather than a degree offset,
#' so the same `miles` value means the same thing at every latitude. Jitter is
#' deterministic by default: the same input and the same `seed` always
#' produce the same output, which matters for a map that gets published and
#' later needs to be regenerated identically.
#'
#' @details
#' Dot maps with physicians stacked on the same building or city block read as
#' a single dot and understate the count there. A fixed, reproducible nudge
#' pulls them apart without introducing run-to-run noise into a published
#' figure. The seed is applied locally -- the caller's `.Random.seed` is saved
#' and restored on exit -- so jittering one map does not reseed any later
#' simulation in the same script.
#'
#' @param points `sf` POINT layer.
#' @param miles `numeric(1)`: maximum jitter radius, in miles. `0` returns
#'   `points` unchanged.
#' @param seed `numeric(1)` or `NULL`: seed for the jitter. Default `42`, so
#'   jitter is reproducible out of the box; pass `NULL` to use the caller's
#'   current random stream instead (a different jitter each run).
#'
#' @return `points`, with jittered geometry, in its original CRS.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' pts <- sf::st_as_sf(
#'   data.frame(lon = rep(-99.5, 3), lat = rep(40.2, 3)),
#'   coords = c("lon", "lat"), crs = 4326)
#' mysterymaps_jitter_points(pts, miles = 1.5, seed = 42)
mysterymaps_jitter_points <- function(points, miles = 1.5, seed = 42) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("mysterymaps_jitter_points() needs the 'sf' package, which is a ",
         "Suggests dependency. Install it to use this function.", call. = FALSE)
  }
  checkmate::assert_class(points, "sf")
  # finite = TRUE: checkmate::assert_number()'s default allows Inf. miles =
  # Inf silently passed validation, then radius_m became Inf, stats::runif()
  # with max = Inf returned NaN for every point with only a non-fatal "NAs
  # produced" warning -- easy to miss in a batch script -- and the jittered
  # output was every physician's location replaced by NaN/NaN, a map that
  # LOOKS like it built successfully but has lost all its geometry.
  checkmate::assert_number(miles, lower = 0, finite = TRUE)
  checkmate::assert_number(seed, null.ok = TRUE, finite = TRUE)

  if (miles == 0 || nrow(points) == 0L) return(points)

  orig_crs <- sf::st_crs(points)
  proj <- sf::st_transform(points, 5070)
  xy <- sf::st_coordinates(proj)
  n <- nrow(xy)
  radius_m <- miles * 1609.344

  if (!is.null(seed)) {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) {
      prev_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
      on.exit(assign(".Random.seed", prev_seed, envir = globalenv()), add = TRUE)
    } else {
      on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
    }
    set.seed(seed)
  }

  angle <- stats::runif(n, 0, 2 * pi)
  dist  <- stats::runif(n, 0, radius_m)
  jittered_xy <- xy + cbind(cos(angle) * dist, sin(angle) * dist)

  jittered_geom <- sf::st_sfc(
    lapply(seq_len(n), function(i) sf::st_point(jittered_xy[i, ])),
    crs = 5070)
  out <- sf::st_set_geometry(proj, jittered_geom)
  sf::st_transform(out, orig_crs)
}
