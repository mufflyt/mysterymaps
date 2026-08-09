#' Format a count with a noun that agrees with it
#'
#' @description
#' Returns "1 midwife", "3 midwives", "1,980 births" — a count formatted with
#' thousands separators and a noun in the number that matches it. Written for
#' map tooltips and popups, where a count and its noun sit inches from the
#' reader's eye and "1 midwives" reads as carelessness about the underlying
#' data.
#'
#' @details
#' - **Vectorised** over `n`, so it drops straight into an `sprintf()` building
#'   labels for a whole layer.
#' - **`NA` is not zero.** A missing count returns `na_text` (an em dash by
#'   default) with no noun, because "NA midwives" and "0 midwives" mean
#'   different things and a map that conflates them is making a claim the data
#'   does not support.
#' - Counts are rounded before formatting: three-year averages and
#'   area-weighted allocations arrive fractional, and "1,980.3 births" in a
#'   tooltip invites a precision the estimate does not have.
#'
#' @param n `numeric`: counts.
#' @param singular `character(1)`: noun for exactly one.
#' @param plural `character(1)`: noun for any other count. Defaults to
#'   `paste0(singular, "s")`, which is wrong often enough ("midwife",
#'   "OB/GYN") that it is worth passing explicitly.
#' @param na_text `character(1)`: returned when `n` is `NA`. Default `"—"`.
#' @return `character` the same length as `n`.
#' @examples
#' mysterymaps_pluralize(c(0, 1, 3, NA), "midwife", "midwives")
#' # "0 midwives" "1 midwife" "3 midwives" "—"
#'
#' mysterymaps_pluralize(1980, "birth")
#' # "1,980 births"
#' @family map-labels
#' @export
mysterymaps_pluralize <- function(n, singular, plural = paste0(singular, "s"),
                                  na_text = "—") {
  if (!is.character(singular) || length(singular) != 1L)
    stop("`singular` must be a single string.", call. = FALSE)
  if (!is.character(plural) || length(plural) != 1L)
    stop("`plural` must be a single string.", call. = FALSE)

  n_round <- round(suppressWarnings(as.numeric(n)))
  noun <- ifelse(!is.na(n_round) & n_round == 1, singular, plural)
  out <- paste0(format(n_round, big.mark = ",", trim = TRUE, scientific = FALSE),
                " ", noun)
  out[is.na(n_round)] <- na_text
  out
}
