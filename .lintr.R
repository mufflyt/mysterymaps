# Lint configuration.
#
# Style rules that fight this package's deliberate house style are switched off
# individually, each with the reason. A .lintr that switches off everything is
# theatre; one that switches off nothing forces a 3,500-line reformat that
# reviews as noise. Below the style section, extra DEFECT linters are switched
# ON -- every one of them corresponds to a mistake that runs silently and
# produces a wrong answer.

linters <- lintr::linters_with_defaults(

  # ---- Style: off, with reasons ---------------------------------------------

  # Long comment lines carrying the "why" of a decision are the point of this
  # codebase, not an accident. 160 is still a hard ceiling.
  line_length_linter = lintr::line_length_linter(160L),

  # Continuation lines are aligned with the opening call, which reads better
  # for the deeply-nested leaflet pipelines than lintr's indentation model.
  indentation_linter = NULL,
  infix_spaces_linter = NULL,
  commas_linter = NULL,

  # `old <- sf::sf_use_s2(); sf::sf_use_s2(FALSE)` -- a paired set-and-restore
  # belongs on one line, and the package does this consistently.
  semicolon_linter = NULL,

  # Worked usage examples in trailing comment blocks. Deliberate.
  commented_code_linter = NULL,

  # `remove_HI_AK` and `.MM_CRED_KEEP` name domain concepts that are
  # conventionally capitalised.
  object_name_linter = NULL,
  object_length_linter = NULL,

  # HTML fragments are written in single quotes so the attribute quotes inside
  # them do not need escaping.
  quotes_linter = NULL,

  # A ratchet, not a target. The worst function today is
  # mysterymaps_isochrones_for_df() at 62 -- retry loop, checkpointing and
  # per-row validation in one body. 65 permits today and catches tomorrow;
  # lower it as those functions are split apart.
  cyclocomp_linter = lintr::cyclocomp_linter(65L),
  brace_linter = NULL,

  # magrittr's `%>%` is an explicit Import and appears throughout, including in
  # NAMESPACE. lintr 3.4 added a default preferring the native `|>`; converting
  # 44 call sites is a reformat, not a fix, and `%>%` still does things `|>`
  # does not (the `.` placeholder, which this package uses).
  pipe_consistency_linter = NULL,

  # `return()` as the final expression is explicit rather than redundant in
  # functions long enough that the exit point is not otherwise obvious.
  return_linter = NULL,

  # `last_save <<- Sys.time()` updates closure state in the isochrone
  # checkpoint saver, which is what `<<-` is for. Keep the rest of the
  # assignment rules.
  assignment_linter = lintr::assignment_linter(operator = c("<-", "<<-")),

  # ---- Defects: on ----------------------------------------------------------

  # `1:length(x)` counts DOWN from 1 to 0 when x is empty.
  seq_linter = lintr::seq_linter(),
  # `&&` on a vector silently used only the first element before R 4.3 and
  # errors after. Neither is what was meant.
  vector_logic_linter = lintr::vector_logic_linter(),
  # `x == NA` is always NA. The author meant `is.na(x)`.
  equals_na_linter = lintr::equals_na_linter(),
  any_is_na_linter = lintr::any_is_na_linter(),
  # T and F are rebindable variables; TRUE and FALSE are not.
  T_and_F_symbol_linter = lintr::T_and_F_symbol_linter(),
  # `class(x) == "sf"` misses subclasses; `inherits()` does not.
  class_equals_linter = lintr::class_equals_linter(),
  literal_coercion_linter = lintr::literal_coercion_linter(),
  # An argument named twice: one of them is silently discarded.
  duplicate_argument_linter = lintr::duplicate_argument_linter(),
  # A positional argument left empty by a stray comma.
  missing_argument_linter = lintr::missing_argument_linter(),
  # Code after return()/stop() never runs.
  unreachable_code_linter = lintr::unreachable_code_linter(),
  # sprintf() with the wrong argument count fails only at call time.
  sprintf_linter = lintr::sprintf_linter(),
  # A hard-coded /Users/... path in a package is broken everywhere else.
  absolute_path_linter = lintr::absolute_path_linter(),
  sort_linter = lintr::sort_linter(),
  redundant_ifelse_linter = lintr::redundant_ifelse_linter(),
  is_numeric_linter = lintr::is_numeric_linter(),

  # `expect_true(x == y)` reports "FALSE is not TRUE" rather than the values,
  # which turns every failure into a debugging session.
  expect_comparison_linter = lintr::expect_comparison_linter(),
  expect_named_linter = lintr::expect_named_linter(),
  expect_not_linter = lintr::expect_not_linter(),
  expect_true_false_linter = lintr::expect_true_false_linter(),
  expect_type_linter = lintr::expect_type_linter(),
  expect_s3_class_linter = lintr::expect_s3_class_linter(),
  expect_length_linter = lintr::expect_length_linter()
)

exclusions <- list(
  # Authored for humans or generated; not package code.
  "data-raw",
  "vignettes",
  "docs",
  ".github",

  # False positive, verified by test: the flagged line is the DEFAULT ARM of a
  # switch(), not code after a stop(). "an unsupported extension is named in
  # the error" in test-geocode.R reaches it and asserts the message, so the
  # code is provably live. Excluded by line so the linter still guards the
  # rest of the file.
  "R/geocode.R" = list(unreachable_code_linter = 102L),
  # object_usage_linter cannot resolve testthat's helpers without attaching the
  # package. Every other linter still applies to the tests.
  "tests/testthat" = list(object_usage_linter = Inf)
)

encoding <- "UTF-8"
