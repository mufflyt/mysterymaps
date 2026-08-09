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

# Credentials worth showing after a provider's name. Deliberately a keep-list,
# not a drop-list: NPPES credential text is free-form and unbounded, so an
# exclusion list silently admits whatever new noise appears next.
.MM_CRED_KEEP <- c(
  # Midwifery
  "CNM", "CM", "CPM", "LM", "LDM", "CNMW",
  # Nurse-practitioner board certifications commonly held alongside
  "WHNP-BC", "WHNP", "FNP-BC", "FNP", "PMHNP-BC", "AGNP",
  # Physician
  "MD", "DO"
)

# Punctuation and spacing variants seen in the data: C.N.M. (575 rows),
# L.M. (128), APRN-CNM (89), C.N.M (72).
.mm_cred_canon <- function(tok) {
  t <- toupper(trimws(tok))
  t <- gsub("[.]", "", t)              # C.N.M. -> CNM
  t <- gsub("\\s+", "", t)             # "WHNP - BC" -> WHNP-BC
  t <- sub("^BC$", "", t)              # stray "BC" from a split
  t
}

#' Format provider credentials for display after a name
#'
#' Turns free-form NPPES credential text into a short, canonical suffix:
#' `"C.N.M."` and `"RN, CNM"` both become `"CNM"`, and `"CNM, WHNP-BC"` is kept
#' whole.
#'
#' @details
#' NPPES credential text is entered by the provider and is not controlled
#' vocabulary. Across 18,760 midwives it appears as `CNM`, `C.N.M.`, `C.N.M`,
#' `RN, CNM`, `APRN-CNM`, `CNM, WHNP-BC`, `MSN, CNM` and dozens more. Rendering
#' it verbatim in a popup shows the data-entry variation rather than the
#' credential.
#'
#' Selection is a KEEP-list, not a drop-list. The text is unbounded, so an
#' exclusion list quietly admits whatever new string appears next; an inclusion
#' list fails closed. Degrees and licences that are not credentials in the
#' honorific sense (`RN`, `APRN`, `ARNP`, `MSN`, `DNP`, `PhD`) are therefore not
#' shown by default — pass `keep` to change that.
#'
#' Order follows the source string, so a provider who lists `CNM, WHNP-BC` keeps
#' that order rather than having one imposed.
#'
#' @param x [character]: raw credential text, e.g. `"RN, CNM"`.
#' @param keep [character]: credentials to display. Defaults to midwifery,
#'   women's-health nurse-practitioner and physician credentials.
#' @param max_n [integer(1)]: most credentials to show; extras are dropped
#'   rather than allowed to overrun a popup line.
#' @return [character] the same length as `x`; `NA` where nothing survives.
#'
#' @examples
#' mysterymaps_format_credentials("C.N.M.")        # "CNM"
#' mysterymaps_format_credentials("RN, CNM")       # "CNM"
#' mysterymaps_format_credentials("CNM, WHNP-BC")  # "CNM, WHNP-BC"
#' mysterymaps_format_credentials("RN")            # NA
#'
#' @family text
#' @export
mysterymaps_format_credentials <- function(x, keep = .MM_CRED_KEEP, max_n = 3L) {
  if (!length(x)) return(character(0))
  keep_u <- toupper(keep)

  vapply(as.character(x), function(s) {
    if (is.na(s) || !nzchar(trimws(s))) return(NA_character_)
    # Split on comma, slash or ampersand. NOT on "-": that would break WHNP-BC.
    toks <- unlist(strsplit(s, "[,/&]+"))
    # A hyphen means two different things: WHNP-BC is one credential, APRN-CNM
    # is two packed together. Resolve by trying the WHOLE token first -- if it
    # is recognised, keep it intact -- and only splitting when it is not, which
    # salvages the CNM from APRN-CNM without breaking WHNP-BC.
    toks <- unlist(lapply(toks, function(t) {
      if (.mm_cred_canon(t) %in% keep_u) return(t)
      parts <- unlist(strsplit(trimws(t), "-"))
      if (length(parts) > 1 && any(.mm_cred_canon(parts) %in% keep_u)) parts else t
    }))
    can <- .mm_cred_canon(toks)
    can <- can[nzchar(can)]
    can <- can[can %in% keep_u]
    can <- can[!duplicated(can)]
    if (!length(can)) return(NA_character_)
    paste(utils::head(can, max_n), collapse = ", ")
  }, character(1), USE.NAMES = FALSE)
}
