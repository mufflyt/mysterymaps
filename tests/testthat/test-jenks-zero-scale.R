# The whole point of this scale is that zero is a category, not the bottom of a
# ramp. A first draft of a midwifery access map used an equal-interval bottom
# bin of 0.0-0.5 and coloured 1,619 of 3,109 counties -- over half the map -- as
# "low" when the truth was "none". These tests exist to keep that from
# regressing quietly.

test_that("zero gets its own colour, distinct from every positive class", {
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40), k = 4)
  zero_col <- sc$color(0)
  expect_identical(zero_col, "#e0e0e0")
  expect_false(zero_col %in% sc$leg_cols[-1])
})

test_that("zero is the FIRST legend entry, not folded into the low bin", {
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40), k = 4)
  expect_identical(sc$leg_labs[[1]], "0")
  expect_identical(sc$leg_cols[[1]], "#e0e0e0")
  expect_length(sc$leg_cols, length(sc$leg_labs))
})

test_that("NA and negatives get a defined colour, never a transparent hole", {
  # findInterval() would otherwise hand NA back an NA colour, which leaflet
  # renders as transparent -- a hole that reads as "no county here".
  #
  # NA now takes na_col rather than zero_col: see test-zero-vs-missing.R for
  # why colouring an unmeasured county as a measured zero is the more
  # dangerous of the two failures. Negatives still take the zero colour.
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 5, 20))
  expect_identical(sc$color(-3), "#e0e0e0")
  expect_false(is.na(sc$color(NA_real_)))
  expect_identical(sc$color(NA_real_), "#ffffff")
})

test_that("an all-zero column degrades to a single grey class, not an error", {
  # classIntervals() cannot break an empty vector. A national map of a rare
  # subspecialty really can have zero everywhere.
  sc <- mysterymaps_jenks_zero_scale(c(0, 0, 0))
  expect_identical(sc$leg_cols, "#e0e0e0")
  expect_identical(sc$leg_labs, "0")
  expect_identical(sc$color(c(0, 0, 0)), rep("#e0e0e0", 3))
})

test_that("k is clamped to the number of distinct positive values", {
  # Asking for 6 classes from 2 distinct values is not an error, it is a
  # request that cannot be honoured; honour what can be.
  sc <- mysterymaps_jenks_zero_scale(c(0, 4, 4, 9), k = 6)
  expect_lte(length(sc$leg_cols) - 1L, 2L)
  expect_gte(length(sc$leg_cols), 2L)
})

test_that("colour is a vectorised function over the original values", {
  n <- c(0, 1, 2, 5, 9, 40, NA)
  sc <- mysterymaps_jenks_zero_scale(n, k = 3)
  out <- sc$color(n)
  expect_length(out, length(n))
  expect_type(out, "character")
  expect_false(anyNA(out))
})

test_that("digits switches labels from integer counts to formatted rates", {
  counts <- mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40), k = 3)
  rates  <- mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40), k = 3, digits = 1)

  expect_identical(counts$leg_labs[[1]], "0")
  expect_identical(rates$leg_labs[[1]], "0.0")
  expect_true(all(grepl("[.]", rates$leg_labs[-1])))
})

test_that("the highest value lands in the top class, not off the end", {
  # findInterval(all.inside = TRUE) is what keeps the maximum from falling
  # outside the last break and colouring as NA.
  n <- c(0, 1, 3, 8, 25, 700)
  sc <- mysterymaps_jenks_zero_scale(n, k = 4)
  top_colour <- sc$leg_cols[[length(sc$leg_cols)]]
  expect_identical(sc$color(max(n)), top_colour)
})

test_that("a custom palette is used and sized to the positive classes", {
  flat <- function(k) rep("#123456", k)
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 5, 20, 60), k = 3, palette = flat)
  expect_true(all(sc$leg_cols[-1] == "#123456"))
  expect_identical(sc$leg_cols[[1]], "#e0e0e0")
})

test_that("zero_col is honoured for zero and for its legend entry", {
  sc <- mysterymaps_jenks_zero_scale(c(0, 2, 9), zero_col = "#ff00ff")
  expect_identical(sc$color(0), "#ff00ff")
  expect_identical(sc$leg_cols[[1]], "#ff00ff")
})

test_that("na_col is honoured independently of zero_col", {
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 2, 9),
                                     zero_col = "#ff00ff", na_col = "#00ff00")
  expect_identical(sc$color(0), "#ff00ff")
  expect_identical(sc$color(NA_real_), "#00ff00")
  expect_true("#00ff00" %in% sc$leg_cols)
})

test_that("integer labels read as ranges of the values actually present", {
  # The label should describe the data, not the break arithmetic: a class
  # holding only 4s should say "4", not "3-6".
  sc <- mysterymaps_jenks_zero_scale(c(0, 4, 4, 4, 100), k = 2)
  expect_true(any(sc$leg_labs == "4"))
})

test_that("a single positive value produces one positive class", {
  sc <- mysterymaps_jenks_zero_scale(c(0, 0, 7))
  expect_length(sc$leg_cols, 2L)
  expect_identical(sc$color(7), sc$leg_cols[[2]])
  expect_identical(sc$color(0), sc$leg_cols[[1]])
})

test_that("the requested number of classes is honoured, not overridden", {
  # MUTANT KILL: k_ignored. Asking for 3 classes and silently receiving 7
  # changes what the map claims about the distribution -- Jenks with more
  # classes splits the low end that the caller deliberately grouped.
  vals <- c(0, 1, 2, 4, 7, 12, 20, 33, 51, 90)
  for (k in 2:5) {
    sc <- mysterymaps_jenks_zero_scale(vals, k = k)
    n_positive_classes <- length(sc$leg_cols) - 1L   # minus the zero class
    expect_true(n_positive_classes <= k,
                label = sprintf("classes (%d) <= requested k (%d)",
                                n_positive_classes, k))
  }
  # And the counts really do differ across k, so the assertion above is not
  # trivially satisfied by every input collapsing to the same answer.
  sizes <- vapply(2:5, function(k)
    length(mysterymaps_jenks_zero_scale(vals, k = k)$leg_cols), integer(1))
  expect_gt(length(unique(sizes)), 1L)
})
