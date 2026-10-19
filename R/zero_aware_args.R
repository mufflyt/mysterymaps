#' Validate the shared zero_aware / k / digits / zero_color argument group
#'
#' Shared by every static map function that offers an opt-in
#' [mysterymaps_jenks_zero_scale()] path alongside a pre-existing continuous
#' scale default ([mysterymaps_geographic_map()],
#' [mysterymaps_map_acceptance_rate()]), so the validation -- and its error
#' messages -- cannot drift between them the way this ecosystem's functions
#' have drifted when the same logic got typed twice.
#'
#' @param zero_aware `logical(1)`: the caller's `zero_aware` argument.
#' @param k `numeric(1)`: the caller's `k` argument. Only checked when
#'   `zero_aware` is `TRUE`.
#' @param digits `numeric(1)` or `NULL`: the caller's `digits` argument. Only
#'   checked when `zero_aware` is `TRUE`.
#' @param zero_color `character(1)`: the caller's `zero_color` argument. Only
#'   checked when `zero_aware` is `TRUE`.
#' @return `invisible(NULL)`; called for its errors.
#' @keywords internal
#' @noRd
mm_validate_zero_aware_args <- function(zero_aware, k, digits, zero_color) {
  if (!is.logical(zero_aware) || length(zero_aware) != 1L || is.na(zero_aware)) {
    stop("`zero_aware` must be a single logical value.", call. = FALSE)
  }
  if (!zero_aware) return(invisible(NULL))
  if (!is.numeric(k) || length(k) != 1L || k < 1) {
    stop("`k` must be a positive integer scalar.", call. = FALSE)
  }
  if (!is.null(digits) && (!is.numeric(digits) || length(digits) != 1L || digits < 0)) {
    stop("`digits` must be NULL or a non-negative integer scalar.", call. = FALSE)
  }
  if (!is.character(zero_color) || length(zero_color) != 1L) {
    stop("`zero_color` must be a single character string.", call. = FALSE)
  }
  invisible(NULL)
}
