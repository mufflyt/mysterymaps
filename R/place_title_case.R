#' Title-case a place name without wrecking its state code
#'
#' @description
#' Administrative sources store place names in capitals — NPPES practice cities
#' are 100% upper case — and `"EGG HARBOR TOWNSHIP, NJ"` shouted from a map
#' tooltip reads as raw data on screen. Naive title casing fixes the city and
#' ruins the state: `"NJ"` becomes `"Nj"`.
#'
#' This title-cases words, leaves two-letter tokens upper case (state and
#' territory codes), and lower-cases interior connectives so
#' `"LAKE OF THE WOODS"` does not become `"Lake Of The Woods"`.
#'
#' @section Known limitation, stated rather than guessed:
#' Scots and Irish prefixes are not handled. `"MCALLEN"` returns `"Mcallen"`,
#' not `"McAllen"`, and `"O'FALLON"` returns `"O'fallon"`. Fixing that needs a
#' gazetteer, because the rule is not mechanical: `"MCPHERSON"` is McPherson but
#' `"MCLEAN"` is McLean in Virginia and Mclean elsewhere. A helper that guessed
#' would be wrong silently and often; a helper that leaves them alone is wrong
#' visibly and rarely.
#'
#' @param x `character`: place names, typically `"CITY, ST"`.
#' @param small `character`: interior words to lower-case. Defaults to the usual
#'   English connectives.
#' @return `character` the same length as `x`, `NA` preserved.
#' @examples
#' mysterymaps_place_title_case(c("EGG HARBOR TOWNSHIP, NJ", "LAKE OF THE WOODS, MN"))
#' # "Egg Harbor Township, NJ" "Lake of the Woods, MN"
#' @family map-labels
#' @export
mysterymaps_place_title_case <- function(x,
                                         small = c("of", "the", "and", "in",
                                                   "on", "at", "by", "de",
                                                   "del", "la", "las", "los")) {
  x <- as.character(x)
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (!any(keep)) return(out)

  out[keep] <- vapply(x[keep], function(s) {
    # Split on spaces but keep punctuation attached, so "CITY, ST" survives as
    # tokens "CITY," and "ST".
    toks <- unlist(strsplit(s, " ", fixed = TRUE))
    n <- length(toks)
    done <- vapply(seq_along(toks), function(i) {
      tk <- toks[i]
      bare <- gsub("[^A-Za-z]", "", tk)
      # The state/territory code is the TRAILING token, and only there is a
      # two-letter word safe to leave upper case. Keying on "any two-letter
      # all-caps token" instead turned "LAKE OF THE WOODS" into "Lake OF the
      # Woods" -- and simply reordering the rules is not the fix either,
      # because IN, OR, DE and LA are both state codes and English words.
      if (i == n && nchar(bare) == 2L && toupper(bare) == bare) return(toupper(tk))
      low <- tolower(tk)
      lb  <- tolower(bare)
      if (i > 1L && lb %in% small) return(low)
      sub("([A-Za-z])", "\\U\\1", low, perl = TRUE)
    }, character(1))
    paste(done, collapse = " ")
  }, character(1), USE.NAMES = FALSE)

  out
}
