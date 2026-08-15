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
#' @param n Numeric vector of values (counts or rates).
#' @param k Target number of classes for the positive values. Default 6.
#' @param zero_col Colour for zero and `NA`. Default light grey.
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
                                palette = viridisLite::viridis, digits = NULL) {
  if (!is.numeric(n)) stop("`n` is not numeric; got ", class(n)[1], call. = FALSE)

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
    return(list(color = function(x) rep(zero_col, length(x)),
                leg_cols = zero_col, leg_labs = zlab))

  # classInt aborts on a single unique value rather than returning one class.
  # One county with a nonzero rate is an ordinary rural result, not an error.
  if (length(upos) == 1L) {
    col1 <- palette(1)
    return(list(
      color = function(x) {
        out <- rep(col1, length(x))
        out[is.na(x) | x <= 0] <- zero_col
        out
      },
      leg_cols = c(zero_col, col1), leg_labs = c(zlab, fmt(upos))))
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
    out <- cols[findInterval(x, brks, rightmost.closed = TRUE, all.inside = TRUE)]
    out[is.na(x) | x <= 0] <- zero_col
    out
  }
  list(color = color, leg_cols = c(zero_col, cols), leg_labs = c(zlab, labs))
}
