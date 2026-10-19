#' Format a vector's duplicated values for an error message
#'
#' Shared by every `mm_id`-uniqueness guard in the access-choropleth family,
#' so the "list the first 10, then say how many more" formatting cannot
#' drift between them.
#'
#' @param x Vector to check.
#' @param limit `integer(1)`: maximum duplicate values to list verbatim.
#' @return `NULL` if `x` has no duplicates, else a formatted `character(1)`.
#' @keywords internal
#' @noRd
mm_format_duplicates <- function(x, limit = 10L) {
  dupe <- unique(x[duplicated(x)])
  if (!length(dupe)) return(NULL)
  paste0(paste(utils::head(dupe, limit), collapse = ", "),
         if (length(dupe) > limit) sprintf(" (and %d more)", length(dupe) - limit) else "")
}

#' Error if `providers$mm_id` has duplicates
#'
#' `mm_id` is used verbatim as each provider marker's leaflet layerId; a
#' duplicate silently makes `map.layerManager.getLayer('marker', id)`
#' resolve to an ambiguous marker, so clicking a geography can light up the
#' wrong physician, or the right one twice, with no error anywhere.
#'
#' @param providers `sf` POINTs with an `mm_id` column.
#' @param fn_name `character(1)`: caller's name, for the error message.
#' @return `invisible(NULL)`; called for its error.
#' @keywords internal
#' @noRd
mm_assert_unique_provider_ids <- function(providers, fn_name) {
  dupe_txt <- mm_format_duplicates(providers$mm_id)
  if (!is.null(dupe_txt)) {
    stop(fn_name, "(): `providers$mm_id` has duplicate value(s): ", dupe_txt,
         ". `mm_id` is used verbatim as each marker's layerId, so a duplicate makes ",
         "click-to-highlight resolve to the wrong marker.", call. = FALSE)
  }
  invisible(NULL)
}

#' Error if any `geos[[.]]$sf$mm_id` collides, within or across geographies
#'
#' Every polygon's layerId -- `mm_id`, used verbatim as the time layer's
#' layerId and as the suffix of every other layer's (`S_`/`C_<mm_id>`) --
#' lives in ONE leaflet layer registry for the whole map, not one scoped
#' per geography. Two geographies that happen to share an id value would
#' silently cross-wire click-to-highlight; checked across every geography
#' at once, not per-geography, because the hazard is cross-geography.
#'
#' @param geos Named list; each element a list with an `sf` component
#'   carrying `mm_id`.
#' @param fn_name `character(1)`: caller's name, for the error message.
#' @return `invisible(NULL)`; called for its error.
#' @keywords internal
#' @noRd
mm_assert_unique_geo_ids <- function(geos, fn_name) {
  all_mm_ids <- unlist(lapply(geos, function(g) as.character(g$sf[["mm_id"]])), use.names = FALSE)
  dupe_txt <- mm_format_duplicates(all_mm_ids)
  if (!is.null(dupe_txt)) {
    stop(fn_name, "(): `mm_id` must be unique across EVERY geography in `geos`, not just ",
         "within one -- every polygon's layerId shares one leaflet layer registry for the ",
         "whole map, and a collision silently cross-wires which geography's providers light ",
         "up on click. Duplicated id(s): ", dupe_txt, ".", call. = FALSE)
  }
  invisible(NULL)
}

#' Error if a geography carries `mm_fill_coverage` with no palette to match
#'
#' A geography can carry the column `mm_fill_coverage` (precomputed fill
#' colours) without the `coverage_pal`/`coverage_values` its legend is built
#' from; `leaflet::addLegend(pal = NULL)` then fails with "argument is of
#' length zero", naming neither the geography nor the actual problem.
#'
#' @param geos Named list; each element a list with an `sf` component and
#'   optional `coverage_pal`/`coverage_values`.
#' @param fn_name `character(1)`: caller's name, for the error message.
#' @return `invisible(NULL)`; called for its error.
#' @keywords internal
#' @noRd
mm_assert_coverage_pal <- function(geos, fn_name) {
  for (gname in names(geos)) {
    g <- geos[[gname]]
    if ("mm_fill_coverage" %in% names(g$sf) &&
        (is.null(g$coverage_pal) || is.null(g$coverage_values))) {
      stop(fn_name, "(): geo '", gname, "' has an `mm_fill_coverage` column but no ",
           "`coverage_pal`/`coverage_values` to build its legend from.", call. = FALSE)
    }
  }
  invisible(NULL)
}
