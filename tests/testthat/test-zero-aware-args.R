# mm_validate_zero_aware_args(): the validation shared by every static map
# function offering an opt-in mysterymaps_jenks_zero_scale() path. Tested
# directly so its error messages cannot drift from what each caller expects
# without a test catching it here first.

test_that("zero_aware must be a single logical value", {
  expect_error(mm_validate_zero_aware_args("yes", 6, NULL, "red"),
               "single logical value")
  expect_error(mm_validate_zero_aware_args(c(TRUE, FALSE), 6, NULL, "red"),
               "single logical value")
  expect_error(mm_validate_zero_aware_args(NA, 6, NULL, "red"),
               "single logical value")
})

test_that("zero_aware = FALSE skips every other check, whatever is passed", {
  expect_null(mm_validate_zero_aware_args(FALSE, "not a number", "not valid", 1))
})

test_that("k must be a positive numeric scalar when zero_aware = TRUE", {
  expect_error(mm_validate_zero_aware_args(TRUE, "six", NULL, "red"),
               "positive integer scalar")
  expect_error(mm_validate_zero_aware_args(TRUE, 0, NULL, "red"),
               "positive integer scalar")
  expect_error(mm_validate_zero_aware_args(TRUE, c(1, 2), NULL, "red"),
               "positive integer scalar")
})

test_that("digits must be NULL or a non-negative numeric scalar when zero_aware = TRUE", {
  expect_error(mm_validate_zero_aware_args(TRUE, 6, "two", "red"),
               "non-negative integer scalar")
  expect_error(mm_validate_zero_aware_args(TRUE, 6, -1, "red"),
               "non-negative integer scalar")
  expect_error(mm_validate_zero_aware_args(TRUE, 6, c(1, 2), "red"),
               "non-negative integer scalar")
  expect_null(mm_validate_zero_aware_args(TRUE, 6, NULL, "red"))
  expect_null(mm_validate_zero_aware_args(TRUE, 6, 0, "red"))
})

test_that("zero_color must be a single character string when zero_aware = TRUE", {
  expect_error(mm_validate_zero_aware_args(TRUE, 6, NULL, 1),
               "single character string")
  expect_error(mm_validate_zero_aware_args(TRUE, 6, NULL, c("red", "blue")),
               "single character string")
})

test_that("a fully valid call returns NULL invisibly", {
  expect_invisible(mm_validate_zero_aware_args(TRUE, 6, 1, "#e0e0e0"))
  expect_null(mm_validate_zero_aware_args(TRUE, 6, 1, "#e0e0e0"))
})
