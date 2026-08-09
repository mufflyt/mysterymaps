#' Reject a water mask that is really a state outline
#'
#' A land clip subtracts water from a coverage surface. If the "water" polygon is
#' actually the state boundary, the clip subtracts the state — silently, because
#' removing too much geometry does not error, does not warn, and leaves no hole a
#' reader would recognise as a defect.
#'
#' @details
#' Five states once carried a single-feature mask covering 102–104% of their own
#' land area. `st_difference()` erased every isochrone in Missouri, Iowa, Kansas,
#' West Virginia and Arkansas, and the map reported the rural interior as having
#' no provider access at all. The upstream cause was a downloader that logged
#' "Empty response, assuming complete": those states never received a
#' high-resolution mask, and a fallback wrote the state boundary in its place.
#'
#' @section Why census water area is the denominator:
#' The obvious test — mask area as a share of the state's LAND area — flags
#' Michigan at 68% and would exclude it. Michigan's boundary contains the Great
#' Lakes, so a mask that size is correct there, and dropping it lets the surface
#' run across Lake Michigan: the exact failure the clip exists to prevent.
#'
#' Measured against census `AWATER` the cases separate cleanly — Michigan is
#' 0.95x its mapped water, while the inverted masks are 45x to 162x. Choose the
#' denominator that distinguishes the failure from the legitimate extreme, not
#' the one that is easiest to reach.
#'
#' @param masks [named list of sf/sfc]: water masks, named by state abbreviation.
#' @param census_water_km2 [named numeric]: census `AWATER` per state, in km².
#'   Supply from `tigris::states()$AWATER / 1e6`.
#' @param max_ratio [numeric(1)]: a mask larger than this multiple of the state's
#'   mapped water is not water. Defaults to 5.
#' @param action `"exclude"` (default) drops the offenders and returns the rest;
#'   `"error"` aborts. Excluding is usually right: a surface carrying some open
#'   water beats one that erases whole states, and masks generally cannot be
#'   regenerated at the point of use.
#' @return The masks, minus any judged inverted. The `"inverted"` attribute
#'   records which were dropped and their ratios.
#'
#' @examples
#' \dontrun{
#' st <- tigris::states(cb = TRUE, year = 2023)
#' aw <- setNames(as.numeric(st$AWATER) / 1e6, st$STUSPS)
#' masks <- mysterymaps_guard_water_masks(masks, aw)
#' }
#' @family county-access-template
#' @export
mysterymaps_guard_water_masks <- function(masks, census_water_km2,
                                          max_ratio = 5,
                                          action = c("exclude", "error")) {
  action <- match.arg(action)
  stopifnot(is.list(masks), !is.null(names(masks)), is.numeric(census_water_km2))

  ratio <- vapply(names(masks), function(st) {
    g <- masks[[st]]
    if (is.null(g)) return(NA_real_)
    a <- sum(as.numeric(sf::st_area(sf::st_make_valid(
      if (inherits(g, "sf")) sf::st_geometry(g) else g)))) / 1e6
    # `[[` on an absent name ERRORS rather than returning NULL, which would
    # abort an entire build over one state missing from the lookup. An absent
    # denominator means unknown, not guilty.
    if (!st %in% names(census_water_km2)) return(NA_real_)
    w <- census_water_km2[[st]]
    if (is.na(w) || w <= 0) NA_real_ else a / w
  }, numeric(1))

  bad <- names(masks)[!is.na(ratio) & ratio > max_ratio]
  if (!length(bad)) {
    message(sprintf("water masks: all %d plausible (max %.1fx census water area).",
                    length(masks), suppressWarnings(max(ratio, na.rm = TRUE))))
    return(masks)
  }

  msg <- sprintf(paste0("%d water mask(s) exceed %gx their state's census water area ",
                        "and are state outlines, not water:\n  %s\n",
                        "  Subtracting these erases every polygon in those states."),
                 length(bad), max_ratio,
                 paste(sprintf("%s (%.0fx)", bad, ratio[bad]), collapse = ", "))
  if (identical(action, "error")) stop(msg, call. = FALSE)
  warning(msg, call. = FALSE)

  out <- masks[setdiff(names(masks), bad)]
  attr(out, "inverted") <- ratio[bad]
  out
}
