# Semantic and adversarial tests for the zero-aware scale.
#
# Semantic: the scale's job is not "return colours" but "say something true
# about the data". A legend that reads -1.6 for a rate that cannot be negative
# is a returned-a-colour success and a said-something-true failure.
#
# Adversarial: every input here is one a real roster can produce. The standard
# is not that all of them succeed -- it is that none of them silently corrupt.

# ---- semantics: zero is a category, not a low value ------------------------

test_that("zero never receives a palette colour", {
  s <- mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, 20), k = 4)
  expect_identical(s$color(0), "#e0e0e0")
  expect_false(s$color(0) %in% setdiff(s$leg_cols, "#e0e0e0"))
  # The whole point of the function: zero is not the bottom of the ramp.
  expect_false(identical(s$color(0), s$color(1.5)))
})

test_that("the legend leads with zero and pairs every colour with a label", {
  s <- mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, 20), k = 4)
  expect_identical(s$leg_cols[[1]], "#e0e0e0")
  expect_identical(s$leg_labs[[1]], "0")
  # A mismatch here shifts every label by one in addLegend(), which mislabels
  # the map without any error at all.
  expect_equal(length(s$leg_cols), length(s$leg_labs))
})

test_that("no positive value is ever coloured as zero", {
  # A positive rate rendered in the zero colour reads as "no providers here"
  # -- the single most consequential thing this map can get wrong.
  vals <- c(0.001, 0.5, 1.5, 3, 8, 20, 1e6)
  s <- mysterymaps_jenks_zero_scale(vals, k = 5)
  expect_false(any(s$color(vals) == "#e0e0e0"))
})

test_that("every positive value lands in a class that exists", {
  vals <- c(0, 0, 1.5, 3, 8, 20, 41, 62)
  s <- mysterymaps_jenks_zero_scale(vals, k = 6)
  cols <- s$color(vals)
  expect_false(anyNA(cols))
  expect_true(all(cols %in% s$leg_cols))
})

# ---- semantics: labels must describe the data ------------------------------

test_that("legend labels never claim a value the data cannot hold", {
  # classInt's jenks extrapolates beyond the data when the class count reaches
  # the number of distinct values -- which this function induces on itself via
  # k <- min(k, length(unique(positive))). The result was a first class reading
  # "-1.6-2.2" for a rate with a floor of zero.
  s <- suppressWarnings(
    mysterymaps_jenks_zero_scale(c(0, 0, 1.5, 3, 8, 20, NA), k = 4, digits = 1))
  bounds <- suppressWarnings(as.numeric(unlist(
    strsplit(s$leg_labs, "–", fixed = TRUE))))
  bounds <- bounds[!is.na(bounds)]
  expect_true(all(bounds >= 0),
              info = paste("labels:", paste(s$leg_labs, collapse = " | ")))
})

test_that("legend labels stay inside the observed range", {
  vals <- c(0, 1.5, 3, 8, 20)
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(vals, k = 4, digits = 1))
  bounds <- suppressWarnings(as.numeric(unlist(
    strsplit(s$leg_labs, "–", fixed = TRUE))))
  bounds <- bounds[!is.na(bounds)]
  expect_lte(max(bounds), max(vals))
  expect_gte(min(bounds), 0)
})

# ---- semantics: order must not change meaning ------------------------------

test_that("input order does not change any colour or label", {
  vals <- c(0, 0, 1.5, 3, 8, 20, 41, 62, NA)
  a <- suppressWarnings(mysterymaps_jenks_zero_scale(vals, k = 5, digits = 1))
  b <- suppressWarnings(mysterymaps_jenks_zero_scale(rev(vals), k = 5, digits = 1))
  set.seed(1)
  c3 <- suppressWarnings(
    mysterymaps_jenks_zero_scale(sample(vals), k = 5, digits = 1))
  expect_identical(a$leg_labs, b$leg_labs)
  expect_identical(a$leg_labs, c3$leg_labs)
  expect_identical(a$leg_cols, b$leg_cols)
  # And the colour assigned to a given value is order-independent too.
  expect_identical(a$color(vals), b$color(vals))
  expect_identical(a$color(vals), c3$color(vals))
})

test_that("duplicated values do not change the classification", {
  vals <- c(0, 1.5, 3, 8, 20)
  a <- suppressWarnings(mysterymaps_jenks_zero_scale(vals, k = 4, digits = 1))
  b <- suppressWarnings(
    mysterymaps_jenks_zero_scale(rep(vals, each = 3), k = 4, digits = 1))
  # Classes are built from distinct values, so repeating a roster row -- a
  # group practice at one address -- must not move a break.
  expect_identical(a$leg_labs, b$leg_labs)
})

# ---- adversarial: degenerate inputs ----------------------------------------

test_that("all-zero and empty input collapse to a single zero class", {
  for (x in list(c(0, 0, 0), numeric(0))) {
    s <- mysterymaps_jenks_zero_scale(x)
    expect_identical(s$leg_cols, "#e0e0e0")
    expect_identical(s$leg_labs, "0")
    expect_identical(s$color(c(0, 1)), c("#e0e0e0", "#e0e0e0"))
  }
})

test_that("all-NA input is a map of unknowns, not a map of zeroes", {
  # The distinction has to survive the degenerate path too: a study area with
  # no measurements anywhere must not render as one where nobody practises.
  s <- mysterymaps_jenks_zero_scale(c(NA_real_, NA_real_))
  expect_identical(s$leg_cols, c("#e0e0e0", "#ffffff"))
  expect_identical(s$leg_labs, c("0", "No data"))
  expect_identical(s$color(c(NA, 0)), c("#ffffff", "#e0e0e0"))
})

test_that("a single distinct positive value yields one usable class", {
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 7, 7, 7), k = 6))
  expect_equal(length(s$leg_cols), length(s$leg_labs))
  expect_false(s$color(7) == "#e0e0e0")
})

test_that("k larger than the number of distinct values is absorbed", {
  # Rural county sets routinely hold fewer distinct rates than the default k.
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1, 2), k = 20))
  expect_lte(length(s$leg_cols), 21L)
  expect_equal(length(s$leg_cols), length(s$leg_labs))
})

test_that("colour output length always matches input length", {
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8), k = 3))
  for (x in list(numeric(0), 5, c(0, NA, 3), rep(2, 100))) {
    expect_length(s$color(x), length(x))
  }
})

# ---- adversarial: values that should never reach a map ---------------------

test_that("NaN is treated as unknown, not as zero", {
  # NaN reaches a rate through 0/0 -- no providers over no population. That is
  # an unmeasurable geography, not a measured zero.
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, NA), k = 3))
  expect_identical(s$color(NaN), "#ffffff")
  expect_identical(s$color(NaN), s$color(NA_real_))
})

test_that("REGRESSION: negative input is rejected, not shaded as zero", {
  # Was "DOCUMENTED GAP: negative input is silently shaded as zero". A negative
  # rate is impossible; arriving at one means an upstream subtraction went
  # wrong. The scale used to absorb it into the zero class, so the map rendered
  # "no providers" and the arithmetic error never surfaced -- a believable
  # desert manufactured out of a bug. No class is honest here, so it errors.
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8), k = 3))
  expect_error(s$color(-5), "cannot be negative")
  expect_error(mysterymaps_jenks_zero_scale(c(0, -1.5, 3, 8), k = 3),
               "cannot be negative")
})

test_that("REGRESSION: Inf is shaded as no data, not as the top class", {
  # Was "DOCUMENTED GAP: Inf is shaded as the top class". Inf reaches a rate
  # through division by a zero denominator -- a county with no births, no
  # population -- so it is the emptiest place on the map, and rendering it as
  # the most-covered colour was the opposite of the truth.
  #
  # Asserted against the PALETTE classes rather than tail(leg_cols, 1): the
  # no-data colour is appended last, so comparing with the final entry would
  # now pass for the wrong reason.
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, Inf), k = 3))
  palette_cols <- s$leg_cols[-c(1, length(s$leg_cols))]

  expect_false(s$color(Inf) %in% palette_cols)
  expect_identical(s$color(Inf), s$color(NA_real_))
  expect_true("No data" %in% s$leg_labs)

  # NaN travels the same route. -Inf does not: it is unmeasurable AND
  # negative, and the negative complaint is the more specific one, so it
  # errors rather than shading. See test-zero-vs-missing.R.
  expect_identical(s$color(NaN), s$color(NA_real_))
  expect_error(s$color(-Inf), "cannot be negative")

  # A finite county keeps the class it had before the fix.
  finite_only <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8), k = 3))
  expect_identical(s$color(3), finite_only$color(3))
})

test_that("zero and NA are different colours", {
  # The distinction this scale exists to protect, at the other end: a county
  # measured at zero has no providers; a county never measured is unknown.
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, NA), k = 3))
  expect_false(identical(s$color(0), s$color(NA_real_)))
  expect_identical(s$color(0), "#e0e0e0")
  expect_identical(s$color(NA_real_), "#ffffff")
  # And neither is a palette colour: unknown is not a quantity.
  expect_false(s$color(NA_real_) %in% s$leg_cols[-c(1, length(s$leg_cols))])
})

test_that("the No data entry appears only when data is actually missing", {
  # A complete map should not carry a legend category nothing falls into.
  complete <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8), k = 3))
  expect_false("No data" %in% complete$leg_labs)
  expect_false("#ffffff" %in% complete$leg_cols)

  partial <- suppressWarnings(
    mysterymaps_jenks_zero_scale(c(0, 1.5, 3, 8, NA), k = 3))
  expect_identical(utils::tail(partial$leg_labs, 1), "No data")
  expect_identical(utils::tail(partial$leg_cols, 1), "#ffffff")
  expect_equal(length(partial$leg_cols), length(partial$leg_labs))
})

test_that("NA stays distinct on every code path, not just the common one", {
  # The degenerate paths return early and each had its own colour logic.
  all_zero <- mysterymaps_jenks_zero_scale(c(0, 0, NA))
  expect_false(identical(all_zero$color(0), all_zero$color(NA_real_)))

  one_value <- suppressWarnings(mysterymaps_jenks_zero_scale(c(0, 7, 7, NA)))
  expect_false(identical(one_value$color(0), one_value$color(NA_real_)))
  expect_false(identical(one_value$color(7), one_value$color(NA_real_)))
})

test_that("na_col can be set back to zero_col for continuity with old maps", {
  s <- suppressWarnings(mysterymaps_jenks_zero_scale(
    c(0, 1.5, 3, 8, NA), k = 3, na_col = "#e0e0e0"))
  expect_identical(s$color(0), s$color(NA_real_))
})

test_that("non-numeric input errors rather than guessing", {
  expect_error(mysterymaps_jenks_zero_scale(c("a", "b")), "not numeric")
})
