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
  pos  <- n[n > 0]
  upos <- sort(unique(pos))
  if (length(upos) == 0)
    return(list(color = function(x) rep(zero_col, length(x)),
                leg_cols = zero_col, leg_labs = "0"))
  k    <- min(k, length(upos))
  brks <- unique(classInt::classIntervals(pos, n = k, style = "jenks")$brks)
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
    if (!length(v)) return(sprintf("%d\u2013%d", ceiling(brks[i]), floor(brks[i + 1L])))
    if (min(v) == max(v)) as.character(min(v)) else sprintf("%d\u2013%d", min(v), max(v))
  }, character(1))
  color <- function(x) {
    out <- cols[findInterval(x, brks, rightmost.closed = TRUE, all.inside = TRUE)]
    out[is.na(x) | x <= 0] <- zero_col
    out
  }
  zlab <- if (is.null(digits)) "0" else formatC(0, format = "f", digits = digits)
  list(color = color, leg_cols = c(zero_col, cols), leg_labs = c(zlab, labs))
}
