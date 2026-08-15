#' Assert every provider falls inside the coverage surface built from them
#'
#' A drive-time surface is dissolved from per-provider isochrones, so every
#' provider must lie inside it: a provider is always within 30 minutes of
#' themselves. Any who do not are providers whose isochrone is missing, and the
#' surface understates access by exactly that much.
#'
#' @details
#' This fails quietly without a gate. A missing isochrone does not error, does
#' not warn, and does not leave a hole you would notice -- it simply removes
#' shading that should have been there, and the map still looks plausible. On
#' the midwifery access map 490 of 11,792 midwives sat outside their own
#' 30-minute surface, concentrated in Missouri (117), Iowa (112) and Kansas
#' (79). Clustered like that, the loss is not random: it biases the coverage
#' gap toward exactly the regions the map exists to describe.
#'
#' @param providers `sf`: provider points.
#' @param surface `sf|sfc`: the dissolved coverage polygon(s).
#' @param label `character(1)`: band name for the message, e.g. "30-minute".
#' @param max_missing_pct `numeric(1)`: tolerated share outside, as a
#'   percentage. Defaults to 0 -- a provider outside their own isochrone is a
#'   defect, not a rounding error.
#' @param group_col `character(1)|NULL`: column to break the report down by
#'   (a state column makes a clustered failure obvious immediately).
#' @param on_fail `"error"` (default) or `"warn"`.
#' @return Invisibly a list with `n`, `n_outside`, `pct_outside` and, when
#'   `group_col` is given, `by_group`.
#' @family county-access-template
#' @export
mysterymaps_gate_provider_coverage <- function(providers, surface,
                                               label = "coverage",
                                               max_missing_pct = 0,
                                               group_col = NULL,
                                               on_fail = c("error", "warn")) {
  on_fail <- match.arg(on_fail)
  stopifnot(inherits(providers, "sf"))

  g <- if (inherits(surface, "sf")) sf::st_geometry(surface) else surface
  g <- sf::st_make_valid(g)

  old <- sf::sf_use_s2(); sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(old), add = TRUE)
  inside <- lengths(suppressMessages(sf::st_intersects(providers, g))) > 0

  n <- length(inside); n_out <- sum(!inside)
  pct <- if (n) 100 * n_out / n else 0

  by_group <- NULL
  if (!is.null(group_col) && group_col %in% names(providers) && n_out) {
    by_group <- sort(table(providers[[group_col]][!inside]), decreasing = TRUE)
  }

  if (pct > max_missing_pct) {
    msg <- sprintf(paste0("%s: %s of %s providers (%.1f%%) fall OUTSIDE the surface ",
                          "dissolved from their own isochrones.\n",
                          "  A provider is within any drive time of themselves, so each one ",
                          "outside is an isochrone that was never generated, and the surface ",
                          "understates access by that much."),
                   label, format(n_out, big.mark = ","), format(n, big.mark = ","), pct)
    if (!is.null(by_group)) {
      top <- utils::head(by_group, 8)
      msg <- paste0(msg, "\n  Concentrated in: ",
                    paste(sprintf("%s (%d)", names(top), as.integer(top)), collapse = ", "),
                    "\n  A clustered failure is a batch that did not run, not random dropout.")
    }
    if (identical(on_fail, "error")) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  } else {
    message(sprintf("%s: all %s providers inside their own surface.",
                    label, format(n, big.mark = ",")))
  }
  invisible(list(n = n, n_outside = n_out, pct_outside = pct, by_group = by_group))
}
