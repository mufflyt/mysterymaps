# SPEC section 26: zero versus missingness.
#
# This is the single most consequential scientific gate in the package, and the
# one a rare-subspecialty map is most likely to fail believably.
#
# Four geographies can carry no number, and they mean four different things:
#
#   observed_zero       measured; there are no providers here
#   source_missing      the provider source does not cover this place
#   geography_missing   providers exist here but could not be placed
#   unresolved          provider identity was never resolved
#
# Only the first is a finding. On a map where most of the country is genuinely
# zero, rendering the other three as a measured zero is indistinguishable from
# the finding -- and it is the direction that inflates the apparent desert.
#
# These tests exist to make that collapse impossible to reintroduce quietly.

test_that("REGRESSION: NA does not receive the observed-zero colour", {
  # Before this gate, `out[is.na(x) | x <= 0] <- zero_col` gave a county with no
  # data the same fill as a county measured at zero, and the legend called that
  # fill "0". The map did not merely lose the distinction -- it asserted the
  # stronger claim.
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30))
  expect_false(identical(sc$color(NA_real_), sc$color(0)))
})

test_that("REGRESSION: the legend never labels the NA colour '0'", {
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30))
  na_idx <- which(sc$leg_cols == sc$color(NA_real_))
  expect_length(na_idx, 1L)
  expect_false(sc$leg_labs[[na_idx]] == "0")
  expect_identical(sc$leg_labs[[na_idx]], "No data")
})

test_that("the NA class carries its own legend entry, not a shared one", {
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30))
  expect_true(sc$leg_labs[[length(sc$leg_labs)]] == "No data")
  expect_length(sc$leg_cols, length(sc$leg_labs))
  # zero, the positive classes, and no-data are all distinct entries.
  expect_equal(length(unique(sc$leg_cols)), length(sc$leg_cols))
})

test_that("complete data produces a legend with NO no-data entry", {
  # The distinction must not cost anything on a map that has no gaps: a
  # complete-data map renders exactly as it did before this class existed.
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 4, 9, 30))
  expect_false("No data" %in% sc$leg_labs)
  expect_false("No data" %in% sc$leg_labs)
  expect_identical(sc$leg_labs[[1]], "0")
})

test_that("all four missingness states stay distinguishable through the scale", {
  # The four rows arrive with three NAs that mean different things. The scale
  # cannot tell them apart -- that is the caller's job -- but it must not
  # collapse any of them into the measured zero.
  four <- mm_four_states()
  sc <- mysterymaps_jenks_zero_scale(c(four$rate, 5, 12))

  fills <- sc$color(four$rate)
  observed_zero <- fills[four$state_label == "observed_zero"]
  unmeasured <- fills[four$state_label != "observed_zero"]

  expect_length(unique(observed_zero), 1L)
  expect_false(any(unmeasured == observed_zero))
})

test_that("na_col = zero_col collapses them, but only when asked explicitly", {
  # The old behaviour remains reachable. It must be a decision someone typed,
  # not a default someone inherited.
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 9), na_col = "#e0e0e0")
  expect_identical(sc$color(NA_real_), sc$color(0))
})

test_that("the distinction survives every degenerate branch of the scale", {
  # Three code paths build a scale: no positive values, exactly one positive
  # value, and the general Jenks path. All three had the collapse.
  cases <- list(
    all_zero      = c(0, 0, NA),
    one_positive  = c(0, NA, 7),
    general        = c(0, NA, 1, 4, 9, 30)
  )
  for (nm in names(cases)) {
    sc <- mysterymaps_jenks_zero_scale(cases[[nm]])
    expect_false(identical(sc$color(NA_real_), sc$color(0)),
                 info = sprintf("branch: %s", nm))
    expect_true("No data" %in% sc$leg_labs, info = sprintf("branch: %s", nm))
  }
})

test_that("an observed zero is never rendered as missing either", {
  # The reverse error understates the desert instead of inflating it, and is
  # just as wrong.
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 3, 11))
  expect_false(identical(sc$color(0), sc$color(NA_real_)))
  expect_identical(sc$color(0), sc$leg_cols[[1]])
  expect_identical(sc$leg_labs[[1]], "0")
})

test_that("NaN is treated as missing, not as a number", {
  # 0/0 in a rate calculation upstream produces NaN. It is not a measurement.
  sc <- mysterymaps_jenks_zero_scale(c(0, NaN, 2, 8))
  expect_identical(sc$color(NaN), sc$color(NA_real_))
  expect_false(identical(sc$color(NaN), sc$color(0)))
})

test_that("a vector of only NA does not become a map of zeros", {
  # A county layer joined against the wrong key produces exactly this: every
  # value NA. The old scale rendered it as a nationwide observed zero.
  sc <- mysterymaps_jenks_zero_scale(rep(NA_real_, 5))
  fills <- sc$color(rep(NA_real_, 5))
  expect_length(unique(fills), 1L)
  expect_false(identical(unique(fills), sc$color(0)))
  expect_true("No data" %in% sc$leg_labs)
})

test_that("the county template propagates the no-data class into the legend", {
  # The scale is only half the gate; the template is what actually draws the
  # legend a reader sees.
  skip_if_not_installed("leaflet")
  cty <- mm_counties(6)
  cty$rate <- c(0, NA, 1.5, 3, 8, 20)

  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL)
  legend <- mm_call_args(m, "addLegend")
  labs <- unlist(legend)
  expect_true(any(grepl("No data", labs, fixed = TRUE)))
})

test_that("negative values are not silently folded into the zero class", {
  # A negative rate is a data error upstream, not a low value. It currently
  # takes the zero colour; this test pins that so the choice is visible and a
  # future change to it is deliberate.
  sc <- mysterymaps_jenks_zero_scale(c(-3, 0, 2, 9))
  expect_identical(sc$color(-3), sc$color(0))
})
