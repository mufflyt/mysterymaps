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
#' @param palette Palette function taking `k`. Default `viridisLite::viridis`.
#' @param digits Decimal places for continuous labels; `NULL` gives integer
#'   count labels.
#' @return A list with `color` (a function mapping values to colours),
#'   `leg_cols` and `leg_labs` for `leaflet::addLegend()`.
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
                                palette = viridisLite::viridis, digits = NULL) {
  if (!is.numeric(n)) stop("`n` is not numeric; got ", class(n)[1], call. = FALSE)
  mm_reject_negative(n, "n")

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
  has_na <- !all(is.finite(n))
  with_na <- function(cols, labs) {
    if (!has_na) return(list(leg_cols = cols, leg_labs = labs))
    list(leg_cols = c(cols, na_col), leg_labs = c(labs, na_label))
  }

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
    return(c(list(color = function(x) {
               mm_reject_negative(x, "x")
               out <- rep(zero_col, length(x))
               out[!is.finite(x)] <- na_col
               out
             }),
             with_na(zero_col, zlab)))

  # classInt aborts on a single unique value rather than returning one class.
  # One county with a nonzero rate is an ordinary rural result, not an error.
  if (length(upos) == 1L) {
    col1 <- palette(1)
    return(c(list(
      color = function(x) {
        mm_reject_negative(x, "x")
        out <- rep(col1, length(x))
        out[is.finite(x) & x <= 0] <- zero_col
        out[!is.finite(x)] <- na_col
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
  color <- function(x) {
    mm_reject_negative(x, "x")
    out <- cols[findInterval(x, brks, rightmost.closed = TRUE, all.inside = TRUE)]
    # Order matters: zero first, then NA over the top. findInterval() returns
    # NA for an NA input, so both would otherwise fall through to the same
    # branch -- which is exactly how they came to share a colour.
    out[is.finite(x) & x <= 0] <- zero_col
    out[!is.finite(x)] <- na_col
    out
  }
  c(list(color = color), with_na(c(zero_col, cols), c(zlab, labs)))
}
