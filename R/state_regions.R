#' Normalise state region values to lowercase full names for basemap joins
#'
#' Shared implementation for the state choropleths. Every row is normalised
#' independently through the mufflyaccess SSOT -- the previous implementations
#' sampled only the FIRST non-missing row to decide whether the whole column
#' was abbreviations or full names, so mixed input (`"CO"` in one row,
#' `"Texas"` in another) silently dropped whichever half the heuristic did
#' not match, and lowercase abbreviations (`"co"`) never matched at all.
#'
#' Fail loud, never silently filter (package rule): values that cannot be
#' parsed as a US state at all are an error naming the offenders; values that
#' parse fine but the `maps`-package state basemap cannot draw (Puerto Rico,
#' Alaska, Hawaii -- the basemap carries the 48 contiguous states plus DC)
#' are a warning naming them, because national datasets legitimately include
#' them and erroring would force every caller to pre-filter.
#'
#' @param x Character vector of raw state values (names or abbreviations, any
#'   case, mixed formats allowed).
#' @param warn_unmappable Logical scalar; pass `FALSE` when the caller has
#'   already deliberately filtered unmappable regions (e.g. the Alaska/Hawaii
#'   toggle in the geographic map).
#' @return Character vector of lowercase full state names; `NA` where the
#'   input is `NA` or blank.
#' @keywords internal
.mm_state_regions_lower <- function(x, warn_unmappable = TRUE) {
  raw <- as.character(x)
  # Validation keys off the "abbr" output: the "name" output title-cases
  # unrecognised input rather than returning NA, so it cannot detect garbage.
  abbr <- mufflyaccess::standardize_state_name(raw, output = "abbr")
  bad <- !is.na(raw) & nzchar(trimws(raw)) & is.na(abbr)
  full <- mufflyaccess::standardize_state_name(raw, output = "name")
  if (any(bad)) {
    offenders <- unique(raw[bad])
    stop(sprintf(
      "%d region value(s) are not recognisable US states: %s",
      length(offenders),
      paste(utils::head(offenders, 10L), collapse = ", ")
    ), call. = FALSE)
  }
  lower <- tolower(full)
  if (isTRUE(warn_unmappable)) {
    unmappable_regions <- setdiff(unique(lower[!is.na(lower)]),
                                  tolower(unique(ggplot2::map_data("state")$region)))
    if (length(unmappable_regions)) {
      warning(sprintf(
        "region(s) not present in the state basemap and will not be drawn: %s",
        paste(sort(unmappable_regions), collapse = ", ")
      ), call. = FALSE)
    }
  }
  lower
}
