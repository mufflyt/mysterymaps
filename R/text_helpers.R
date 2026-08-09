#' Agree a noun with its count
#'
#' Returns a count and noun that agree in number: `1 midwife`, `13 midwives`.
#'
#' @details
#' Written because map labels built with `sprintf("%d midwives", n)` render
#' "1 midwives" whenever a county holds exactly one provider — visible on every
#' single-provider county of a national choropleth, which is most of the rural
#' ones.
#'
#' English plurals are irregular often enough that appending `"s"` is only a
#' default, never an assumption: pass `plural` for anything that does not take
#' it. `0` takes the plural ("0 midwives"), which is what English does.
#'
#' @param n [numeric]: the count. `NA` returns `NA_character_`.
#' @param singular [character(1)]: noun in its singular form.
#' @param plural [character(1)|NULL]: plural form. Defaults to `paste0(singular, "s")`.
#' @param big_mark [logical(1)]: comma-group counts of 1,000 or more.
#' @param include_n [logical(1)]: when `FALSE`, return only the agreed noun.
#'
#' @return [character] the same length as `n`.
#'
#' @examples
#' mysterymaps_pluralize(1, "midwife", "midwives")   # "1 midwife"
#' mysterymaps_pluralize(13, "midwife", "midwives")  # "13 midwives"
#' mysterymaps_pluralize(0, "midwife", "midwives")   # "0 midwives"
#' mysterymaps_pluralize(2400, "birth")              # "2,400 births"
#' mysterymaps_pluralize(1, "midwife", "midwives", include_n = FALSE)  # "midwife"
#'
#' @family text
#' @export
mysterymaps_pluralize <- function(n, singular, plural = NULL,
                                  big_mark = TRUE, include_n = TRUE) {
  stopifnot(is.character(singular), length(singular) == 1L)
  if (is.null(plural)) plural <- paste0(singular, "s")
  stopifnot(is.character(plural), length(plural) == 1L)

  # abs() so -1 agrees as singular; the sign belongs to the number, not the noun.
  noun <- ifelse(!is.na(n) & abs(n) == 1, singular, plural)
  if (!include_n) return(ifelse(is.na(n), NA_character_, noun))

  num <- ifelse(is.na(n), NA_character_,
                format(n, big.mark = if (big_mark) "," else "", trim = TRUE,
                       scientific = FALSE))
  ifelse(is.na(n), NA_character_, paste(num, noun))
}

#' Title-case a place name without mangling it
#'
#' `EADS, CO` becomes `Eads, CO`. Written for popups that display upstream data
#' held in all caps, where `stringr::str_to_title()` alone produces `Eads, Co`
#' and `Mcallen`.
#'
#' @details
#' Handles the cases that actually appear in US place and provider data:
#' \itemize{
#'   \item a trailing two-letter state or territory code stays upper case;
#'   \item `Mc` and `Mac` prefixes capitalise the following letter
#'     (`MCALLEN` -> `McAllen`);
#'   \item hyphenated and apostrophied names capitalise each part
#'     (`WINSTON-SALEM`, `O'FALLON`);
#'   \item small words stay lower case inside a name but not at its start
#'     (`ISLE OF PALMS` -> `Isle of Palms`);
#'   \item directional and ordinal tokens keep their conventional form
#'     (`NW`, `US`, `ST`, `3RD`).
#' }
#' Input that is already mixed case is left alone: it is likelier to be correct
#' than a blind re-case would be.
#'
#' @param x [character]: place names, e.g. `"EADS"` or `"EADS, CO"`.
#' @return [character] the same length as `x`.
#'
#' @examples
#' mysterymaps_place_title_case("EADS, CO")        # "Eads, CO"
#' mysterymaps_place_title_case("MCALLEN, TX")     # "McAllen, TX"
#' mysterymaps_place_title_case("WINSTON-SALEM")   # "Winston-Salem"
#' mysterymaps_place_title_case("ISLE OF PALMS")   # "Isle of Palms"
#'
#' @family text
#' @export
mysterymaps_place_title_case <- function(x) {
  if (!length(x)) return(character(0))
  out <- as.character(x)

  # Tokens that must not be title-cased.
  keep_upper <- c("NW", "NE", "SW", "SE", "US", "USA", "II", "III", "IV",
                  "DC", "PR", "VI", "GU", "AS", "MP")
  small <- c("of", "the", "and", "at", "on", "in", "de", "del", "la", "las",
             "los", "el", "by", "upon")

  cap_word <- function(w) {
    if (!nzchar(w)) return(w)
    if (toupper(w) %in% keep_upper) return(toupper(w))
    # 3RD, 42ND: digits then letters stay as digits + lower letters.
    if (grepl("^[0-9]+(ST|ND|RD|TH)$", w, ignore.case = TRUE))
      return(paste0(gsub("[^0-9]", "", w), tolower(gsub("[0-9]", "", w))))
    w <- paste0(toupper(substring(w, 1, 1)), tolower(substring(w, 2)))
    # McAllen, MacArthur -- but not "Mac" alone, and not "Mci".
    w <- sub("^(Mc)([a-z])", "\\1\\U\\2", w, perl = TRUE)
    w <- sub("^(Mac)([a-z]{3,})", "\\1\\U\\2", w, perl = TRUE)
    w
  }

  title_one <- function(s) {
    if (is.na(s) || !nzchar(s)) return(s)
    # Leave anything already mixed case alone: it is more likely correct than a
    # re-case would be. Only ALL CAPS (or all lower) input is transformed.
    if (grepl("[a-z]", s) && grepl("[A-Z]", s)) return(s)

    # A trailing ", XX" is a state/territory code and stays upper.
    m <- regmatches(s, regexec("^(.*),\\s*([A-Za-z]{2})$", s))[[1]]
    tail_code <- NULL
    if (length(m) == 3) { tail_code <- toupper(m[3]); s <- m[2] }

    parts <- strsplit(s, "(?<=[\\s\\-'/])", perl = TRUE)[[1]]
    done <- vapply(seq_along(parts), function(i) {
      sep <- sub("^[^\\s\\-'/]*", "", parts[i], perl = TRUE)
      w   <- sub("[\\s\\-'/]*$", "", parts[i], perl = TRUE)
      cw  <- cap_word(w)
      # Small words stay lower unless they open the name.
      if (i > 1 && tolower(w) %in% small && !toupper(w) %in% keep_upper)
        cw <- tolower(w)
      paste0(cw, sep)
    }, character(1))

    res <- paste0(done, collapse = "")
    if (!is.null(tail_code)) res <- paste0(res, ", ", tail_code)
    res
  }

  vapply(out, title_one, character(1), USE.NAMES = FALSE)
}
