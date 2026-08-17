#' Refuse a negative count or rate
#'
#' Shared by the scale constructor and by the `color()` it returns, because the
#' two can be handed different vectors -- a scale built from every county and
#' applied to one state's subset -- and a negative slipping in on the second
#' call is coloured, not classified, which is where it would go unnoticed.
#'
#' @param n `numeric`: the values to check.
#' @param arg `character(1)`: the argument name to blame in the message.
#' @return `invisible(NULL)`; called for the error.
#' @keywords internal
#' @noRd
mm_reject_negative <- function(n, arg = "n") {
  neg <- which(!is.na(n) & n < 0)
  if (!length(neg)) return(invisible(NULL))
  stop(sprintf(paste0(
    "`%s` contains %d negative value%s (minimum %s, first at position%s %s).\n",
    "  A count or a rate cannot be negative, so this is an upstream ",
    "arithmetic error rather than a low value, and no class on this scale ",
    "represents it honestly -- it previously took the zero colour and was ",
    "labelled `0`, which is the conflation the scale exists to prevent.\n",
    "  If you meant to map a change between two periods, this scale is the ",
    "wrong one: zero here is a floor category, not a midpoint. Use a ",
    "diverging scale."),
    arg, length(neg), if (length(neg) == 1L) "" else "s",
    format(min(n[neg])), if (length(neg) == 1L) "" else "s",
    paste(utils::head(neg, 5L), collapse = ", ")),
    call. = FALSE)
}

#' Normalise a coverage vector to "is this row outside every catchment?"
#'
#' Accepts the two shapes `twostep::compute_e2sfca()` emits: the character
#' `coverage_status` and the logical `reached`. An unrecognised character value
#' errors rather than defaulting to "inside" -- defaulting would put a tract the
#' model never reached back into a measured class, which is the whole failure
#' this exists to stop.
#'
#' @param coverage `NULL`, `logical`, or `character`.
#' @param n `integer(1)`: expected length.
#' @param arg `character(1)`: argument name for messages.
#' @return `logical(n)`; all `FALSE` when `coverage` is `NULL`.
#' @keywords internal
#' @noRd
mm_coverage_outside <- function(coverage, n, arg = "coverage") {
  if (is.null(coverage)) return(rep(FALSE, n))
  if (length(coverage) != n) {
    stop(sprintf(paste0("`%s` has %d value%s but the data has %d row%s. ",
                        "Coverage is a property of each geography, so the two ",
                        "must line up; a recycled vector would mislabel rows ",
                        "silently."),
                 arg, length(coverage), if (length(coverage) == 1L) "" else "s",
                 n, if (n == 1L) "" else "s"), call. = FALSE)
  }
  if (is.logical(coverage)) {
    if (anyNA(coverage)) {
      stop(sprintf(paste0("`%s` contains NA. Whether a geography lies inside ",
                          "the modelled catchment is known or the map cannot ",
                          "be drawn honestly; it is not itself a missing ",
                          "value."), arg),
           call. = FALSE)
    }
    return(!coverage)                       # `reached`: FALSE means outside
  }
  if (is.character(coverage) || is.factor(coverage)) {
    v <- as.character(coverage)
    inside <- "within_modeled_catchment"
    outside <- "outside_all_modeled_catchments"
    bad <- setdiff(unique(v[!is.na(v)]), c(inside, outside))
    if (length(bad) || anyNA(v)) {
      stop(sprintf(paste0("`%s` must be `%s` or `%s`%s. Unrecognised: %s. ",
                          "Guessing would put a geography the model never ",
                          "reached back into a measured class."),
                   arg, inside, outside,
                   if (anyNA(v)) ", and must not be NA" else "",
                   paste(utils::head(c(bad, if (anyNA(v)) "NA"), 4),
                         collapse = ", ")), call. = FALSE)
    }
    return(v == outside)
  }
  stop(sprintf("`%s` must be logical (`reached`) or character (`coverage_status`); got %s",
               arg, class(coverage)[1]), call. = FALSE)
}

#' Resolve the coverage a `color()` call should use
#'
#' `color()` takes a vector, but coverage is per-row metadata that cannot be
#' derived from the value -- an outside geography and an unmeasured one are both
#' `NA`. So the scale remembers the coverage it was built with and reuses it
#' when `color()` is handed a vector of the same length.
#'
#' When the lengths differ it ERRORS rather than dropping the class: colouring a
#' subset with a scale built from the nation is a legitimate thing to do, and
#' silently losing the outside category there would produce exactly the map this
#' work exists to prevent, on a subset nobody re-checked.
#'
#' @param coverage coverage passed to `color()`, or `NULL`.
#' @param built logical vector captured at construction.
#' @param n length of the vector being coloured.
#' @return `logical(n)`.
#' @keywords internal
#' @noRd
mm_resolve_coverage <- function(coverage, built, n) {
  if (!is.null(coverage)) return(mm_coverage_outside(coverage, n, "coverage"))
  if (!any(built)) return(rep(FALSE, n))
  if (length(built) == n) return(built)
  stop(sprintf(paste0("this scale was built with coverage for %d geograph%s ",
                      "but color() was given %d. Pass `coverage` to color() ",
                      "as well -- without it the outside-catchment class would ",
                      "be dropped and those geographies would take the ",
                      "no-data colour instead."),
               length(built), if (length(built) == 1L) "y" else "ies", n),
       call. = FALSE)
}

#' Zero-aware Jenks natural-breaks colour scale
#'
#' @description
#' Classifies POSITIVE values with Jenks natural breaks and gives zero its own
#' colour and legend entry. Zero is a category, not the low end of a scale: a
#' county with no provider is categorically different from one with a low rate,
#' and binning them together hides exactly the finding a workforce map exists to
#' show. A first draft of a midwifery access map used an equal-interval bottom
#' bin of 0.0-0.5 and so coloured 1,619 of 3,109 counties -- over half the map --
#' as "low" when the truth was "none".
#'
#' @details
#' Jenks rather than equal intervals because provider rates are heavily
#' right-skewed; equal intervals put almost every county in the first bin.
#'
#' @section Outside the model is not missing data:
#' Three states reach this scale and all three are different:
#'
#' \describe{
#'   \item{measured zero}{The geography is inside somebody's catchment and the
#'     supply reaching it works out to zero. A measurement. Takes `zero_col`.}
#'   \item{outside every catchment}{The model ran and no provider is reachable
#'     within the modelled drive time. Also a measurement -- usually the finding
#'     the map exists to report -- and emphatically not a gap in the data.
#'     Takes `outside_col`, when `coverage` is supplied.}
#'   \item{missing}{The value is unknown: a suppressed denominator, a failed
#'     join. Takes `na_col`.}
#' }
#'
#' Without `coverage` the second and third collapse, because both arrive as
#' `NA`. That is better than the older behaviour, in which the second arrived as
#' `0` and was indistinguishable from the first -- 190 of 1,447 Colorado tracts
#' on one subspecialty surface, 13% of the state, every one shaded in the zero
#' class under a legend reading `0`. But it still files a finding under
#' "unknown", so pass `coverage` whenever the producer supplies it.
#'
#' Coverage cannot be inferred from the value: an outside geography and an
#' unmeasured one are both `NA`, which is precisely why it has to travel
#' alongside as its own column.
#'
#' @section Negative values:
#' A negative count or rate is rejected rather than coloured. It used to take
#' `zero_col`, so a county whose supply arrived as -3 rendered identically to a
#' county measured at zero and the legend labelled it `0` -- the same conflation
#' this scale exists to prevent at the other end of the ramp, with an
#' arithmetic error concealed inside it. No class represents a negative supply
#' honestly, so the map is not built.
#'
#' If the intent is to map a *change* between two periods, this scale is the
#' wrong one: zero here is a distinguished floor category, not a midpoint, and
#' a diverging scale is what a difference needs.
#'
#' @param n Numeric vector of non-negative values (counts or rates). A negative
#'   value is an upstream arithmetic error rather than a low value and is
#'   rejected; see the `Negative values` section.
#' @param k Target number of classes for the positive values. Default 6.
#' @param zero_col Colour for zero. Default light grey.
#' @param na_col Colour for `NA` and `NaN`, which mean unmeasured rather than
#'   none. Default white. Pass `zero_col` to restore the pre-0.2.1 behaviour of
#'   shading unmeasured geographies as if they were zero.
#' @param na_label Legend entry for `na_col`. The entry is added only when the
#'   data actually contains `NA`, so legends do not gain an empty category.
#' @param coverage Optional per-geography coverage state, parallel to `n`.
#'   Accepts either shape `twostep::compute_e2sfca()` emits: the character
#'   `coverage_status` (`"within_modeled_catchment"` /
#'   `"outside_all_modeled_catchments"`) or the logical `reached`. When
#'   supplied, geographies outside every catchment get `outside_col` and their
#'   own legend entry instead of falling into the no-data class.
#' @param outside_col Colour for geographies outside every modelled catchment.
#' @param outside_label Legend entry for `outside_col`, added only when some
#'   geography is actually outside.
#' @param palette Palette function taking `k`. Default `viridisLite::viridis`.
#' @param digits Decimal places for continuous labels; `NULL` gives integer
#'   count labels.
#' @return A list with `color` (a function `color(x, coverage = NULL)` mapping
#'   values to colours; the coverage given at construction is reused when `x`
#'   is the same length), `leg_cols` and `leg_labs` for
#'   `leaflet::addLegend()`.
#' @examples
#' \dontrun{
#'   sc <- mysterymaps_jenks_zero_scale(counties$rate, k = 6, digits = 1)
#'   leaflet::addPolygons(map, fillColor = sc$color(counties$rate))
#'   leaflet::addLegend(map, colors = sc$leg_cols, labels = sc$leg_labs)
#' }
#' @family coverage-surfaces
#' @export
mysterymaps_jenks_zero_scale <- function(n, k = 6, zero_col = "#e0e0e0",
                                na_col = "#ffffff", na_label = "No data",
                                coverage = NULL,
                                outside_col = "#efe7d5",
                                outside_label = "No provider within the modelled drive time",
                                palette = viridisLite::viridis, digits = NULL) {
  if (!is.numeric(n)) stop("`n` is not numeric; got ", class(n)[1], call. = FALSE)
  mm_reject_negative(n, "n")

  is_outside <- mm_coverage_outside(coverage, length(n), "coverage")
  has_outside <- any(is_outside)

  # A county measured at zero and a county never measured are categorically
  # different, and shading them alike is the error this scale exists to
  # prevent at the other end. The legend gains the entry only when some value
  # is actually missing, so a complete map keeps a two-part legend.
  # Non-finite is not a measurement, and that includes Inf. A rate reaches Inf
  # by division by a zero denominator -- a county with no births, no
  # population -- so it is the emptiest place on the map, not the fullest.
  #
  # Inf was already kept out of the BREAKS by the is.finite() filter below, but
  # color() still handed it the top class: findInterval(Inf, brks, all.inside =
  # TRUE) returns the last interval. The county with no denominator therefore
  # rendered as the best-supplied in the country, with no legend entry saying
  # otherwise. Treat every non-finite value as the caller's `na_col`.
  #
  # A tract outside every modelled catchment is a THIRD state again, and the
  # one an access study usually exists to report. It is not a measured zero --
  # nothing was measured -- and it is not missing data either: the model ran and
  # the answer is that no provider is reachable. Collapsing it into `na_col`
  # would file the headline finding under "unknown". It therefore gets its own
  # colour and legend entry, added only when some row is actually outside.
  has_na <- !all(is.finite(n[!is_outside]))
  with_na <- function(cols, labs) {
    if (has_outside) { cols <- c(cols, outside_col); labs <- c(labs, outside_label) }
    if (!has_na) return(list(leg_cols = cols, leg_labs = labs))
    list(leg_cols = c(cols, na_col), leg_labs = c(labs, na_label))
  }

  # Values on outside rows are excluded from classification. With the corrected
  # twostep contract they are NA and would drop out anyway, but a caller mapping
  # the algebraic column would otherwise hand a pile of structural zeros to the
  # zero class -- the very conflation upstream just stopped making.
  n <- ifelse(is_outside, NA_real_, n)

  # Drop NA before comparing: n[n > 0] keeps an NA element for every NA in n,
  # which classInt then warns about and omits. Filtering here is the same
  # classification with one fewer spurious warning per map.
  pos  <- n[!is.na(n) & n > 0]
  pos  <- pos[is.finite(pos)]
  upos <- sort(unique(pos))

  zlab <- if (is.null(digits)) "0" else formatC(0, format = "f", digits = digits)

  # A label for one value, honouring `digits` when set. Without `digits` the
  # labels are meant to be integer counts, but sprintf("%d") aborts on a
  # fractional double -- so passing rates without `digits` used to error out
  # of the whole map rather than mislabel one class.
  fmt <- function(v) {
    if (!is.null(digits)) return(formatC(v, format = "f", digits = digits))
    if (isTRUE(all.equal(v, round(v)))) return(sprintf("%d", as.integer(round(v))))
    formatC(v, format = "g", digits = 3)
  }

  if (length(upos) == 0)
    return(c(list(color = function(x, coverage = NULL) {
               mm_reject_negative(x, "x")
               out <- rep(zero_col, length(x))
               out[!is.finite(x)] <- na_col
               out[mm_resolve_coverage(coverage, is_outside, length(x))] <- outside_col
               out
             }),
             with_na(zero_col, zlab)))

  # classInt aborts on a single unique value rather than returning one class.
  # One county with a nonzero rate is an ordinary rural result, not an error.
  if (length(upos) == 1L) {
    col1 <- palette(1)
    return(c(list(
      color = function(x, coverage = NULL) {
        mm_reject_negative(x, "x")
        out <- rep(col1, length(x))
        out[is.finite(x) & x <= 0] <- zero_col
        out[!is.finite(x)] <- na_col
        out[mm_resolve_coverage(coverage, is_outside, length(x))] <- outside_col
        out
      }),
      with_na(c(zero_col, col1), c(zlab, fmt(upos)))))
  }

  k    <- min(k, length(upos))
  brks <- unique(classInt::classIntervals(pos, n = k, style = "jenks")$brks)
  # When the class count reaches the number of distinct values, jenks returns
  # breaks extrapolated past both ends of the data -- and this function induces
  # exactly that case with the min() above. A first class labelled "-1.6-2.2"
  # asserts a negative rate; clamping the outer breaks to the observed range
  # fixes the labels without moving any value between classes.
  brks[1] <- min(pos)
  brks[length(brks)] <- max(pos)
  brks <- unique(brks)
  k    <- length(brks) - 1L
  cols <- palette(k)
  idxp <- findInterval(pos, brks, rightmost.closed = TRUE, all.inside = TRUE)
  labs <- vapply(seq_len(k), function(i) {
    if (!is.null(digits)) {                       # continuous (e.g. rate) labels
      lo <- formatC(brks[i],     format = "f", digits = digits)
      hi <- formatC(brks[i + 1L], format = "f", digits = digits)
      return(paste0(lo, "\u2013", hi))
    }
    v <- pos[idxp == i]                           # integer (count) labels
    if (!length(v)) return(paste0(fmt(ceiling(brks[i])), "\u2013",
                                  fmt(floor(brks[i + 1L]))))
    if (min(v) == max(v)) fmt(min(v)) else paste0(fmt(min(v)), "\u2013", fmt(max(v)))
  }, character(1))
  color <- function(x, coverage = NULL) {
    mm_reject_negative(x, "x")
    out <- cols[findInterval(x, brks, rightmost.closed = TRUE, all.inside = TRUE)]
    # Order matters: zero first, then NA over the top. findInterval() returns
    # NA for an NA input, so both would otherwise fall through to the same
    # branch -- which is exactly how they came to share a colour.
    out[is.finite(x) & x <= 0] <- zero_col
    out[!is.finite(x)] <- na_col
    # Outside last: it is the most specific statement about the row, and it
    # must win over the NA it necessarily also is.
    out[mm_resolve_coverage(coverage, is_outside, length(x))] <- outside_col
    out
  }
  c(list(color = color), with_na(c(zero_col, cols), c(zlab, labs)))
}
