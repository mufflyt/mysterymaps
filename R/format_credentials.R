#' Tidy a raw NPPES credential string for display
#'
#' @description
#' Turns the free text NPPES stores in `credential` into something fit for a map
#' label: `"C.N.M."`, `"CNM"`, `"RN, CNM"` and `"APRN-CNM"` are all written by
#' hand by the provider, and a tooltip that shows them verbatim looks like the
#' underlying data was never examined.
#'
#' Punctuation is stripped, separators are normalised, tokens are upper-cased
#' and de-duplicated in place, and the result is rejoined with commas.
#'
#' @section This formats; it does not classify:
#' It makes no judgement about what a credential *means* — it will not tell you
#' whether someone is a nurse-midwife. Classification lives elsewhere and is a
#' harder problem: see `classify_nppes_credential()` and
#' `apply_credential_gate()` in mufflyt/isochrones. Those return a physician
#' degree (`"MD"`, `"DO"`, `"UNKNOWN"`) and are the wrong tool for midwifery
#' credentials, which is why this function is a formatter and stops there.
#'
#' Deliberately NO synonym table. Folding `ARNP` into `APRN`, or dropping `RN`
#' as redundant beside `CNM`, is a substantive claim about credentialing that
#' belongs in a classifier a domain expert has reviewed — not in a label
#' helper, where it would silently rewrite what a provider reported.
#'
#' @param x `character`: raw credential strings.
#' @param sep `character(1)`: separator for the rejoined tokens. Default `", "`.
#' @return `character` the same length as `x`; `NA` where the input was `NA`,
#'   empty, or held no usable token.
#' @examples
#' mysterymaps_format_credentials(c("C.N.M.", "RN, CNM", "cnm/whnp", NA))
#' # "CNM" "RN, CNM" "CNM, WHNP" NA
#'
#' mysterymaps_format_credentials("CNM, C.N.M., CNM")
#' # "CNM"
#' @family map-labels
#' @export
mysterymaps_format_credentials <- function(x, sep = ", ") {
  x <- as.character(x)
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x) & nzchar(trimws(x))
  if (!any(keep)) return(out)

  tidied <- vapply(x[keep], function(s) {
    s <- toupper(s)
    # Periods inside an abbreviation only ("C.N.M." -> "CNM"); slashes,
    # semicolons, ampersands, plus signs and hyphens are all separators people
    # actually use.
    s <- gsub("\\.", "", s)
    parts <- unlist(strsplit(s, "[,;/&+]|\\s-\\s|\\s{2,}"))
    parts <- trimws(parts)
    parts <- parts[nzchar(parts)]
    if (!length(parts)) return(NA_character_)
    paste(unique(parts), collapse = sep)
  }, character(1), USE.NAMES = FALSE)

  out[keep] <- tidied
  out
}
