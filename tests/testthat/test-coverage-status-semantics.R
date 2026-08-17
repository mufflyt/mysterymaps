# Outside every modelled catchment is a third state, and a finding.
#
# twostep::compute_e2sfca() now distinguishes a measured zero from a geography
# no isochrone reaches. This file pins that the map keeps the distinction the
# producer went to the trouble of making, rather than filing the finding under
# "No data" -- which would be a quieter version of the same collapse that put it
# in the zero class.
#
# The three states, and why none of them is another:
#   in catchment, value 0  -> measured: no supply reaches here
#   outside all catchments -> measured: no provider within the drive time
#   NA                     -> unknown: suppressed denominator, failed join

INSIDE <- "within_modeled_catchment"
OUTSIDE <- "outside_all_modeled_catchments"

test_that("without coverage the old behaviour is exactly preserved", {
  # Backwards compatibility is load-bearing: every existing caller passes no
  # coverage and must get the same map it got yesterday.
  a <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30))
  b <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30), coverage = NULL)
  expect_identical(a$leg_cols, b$leg_cols)
  expect_identical(a$leg_labs, b$leg_labs)
  expect_identical(a$color(c(0, NA, 4)), b$color(c(0, NA, 4)))
  expect_false("No provider within the modelled drive time" %in% a$leg_labs)
})

test_that("an outside geography is not the zero colour", {
  # The defect this whole line of work started from, at its last hop.
  sc <- mysterymaps_jenks_zero_scale(
    c(0, NA, 2, 8), coverage = c(INSIDE, OUTSIDE, INSIDE, INSIDE))
  fills <- sc$color(c(0, NA, 2, 8))
  expect_false(identical(fills[[2]], fills[[1]]))
})

test_that("REGRESSION: an outside geography is not the no-data colour either", {
  # Both arrive as NA, so the older scale gave them the same fill and the same
  # legend entry. "No provider within 60 minutes" is a measurement; "No data"
  # is an admission. A map that says the second when it means the first
  # understates the finding it exists to report.
  sc <- mysterymaps_jenks_zero_scale(
    c(0, NA, NA, 5), coverage = c(INSIDE, OUTSIDE, INSIDE, INSIDE))
  fills <- sc$color(c(0, NA, NA, 5))
  expect_false(identical(fills[[2]], fills[[3]]))    # outside vs genuinely NA
  expect_true("No data" %in% sc$leg_labs)
  expect_true(any(grepl("No provider", sc$leg_labs)))
})

test_that("all three states get distinct colours and distinct legend entries", {
  sc <- mysterymaps_jenks_zero_scale(
    c(0, NA, NA, 1, 6, 20),
    coverage = c(INSIDE, OUTSIDE, INSIDE, INSIDE, INSIDE, INSIDE))
  fills <- sc$color(c(0, NA, NA, 1, 6, 20))
  expect_equal(length(unique(fills[1:3])), 3L)       # zero, outside, no-data
  expect_equal(length(unique(sc$leg_cols)), length(sc$leg_cols))
  expect_equal(length(sc$leg_cols), length(sc$leg_labs))
})

test_that("the outside entry appears only when something is actually outside", {
  # A complete map must not gain an empty category, the same rule the no-data
  # entry already follows.
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 5), coverage = rep(INSIDE, 3))
  expect_false(any(grepl("No provider", sc$leg_labs)))
  expect_identical(sc$leg_labs[[1]], "0")
})

test_that("the logical `reached` shape works as well as `coverage_status`", {
  chr <- mysterymaps_jenks_zero_scale(c(0, NA, 3), coverage = c(INSIDE, OUTSIDE, INSIDE))
  lgl <- mysterymaps_jenks_zero_scale(c(0, NA, 3), coverage = c(TRUE, FALSE, TRUE))
  expect_identical(chr$leg_cols, lgl$leg_cols)
  expect_identical(chr$color(c(0, NA, 3)), lgl$color(c(0, NA, 3)))
})

test_that("outside values are kept out of the Jenks classification", {
  # A caller mapping the ALGEBRAIC column hands structural zeros to the scale.
  # Those must not join the zero class or stretch the breaks.
  with_out <- mysterymaps_jenks_zero_scale(
    c(0, 0, 0, 1, 4, 9, 30),
    coverage = c(INSIDE, OUTSIDE, OUTSIDE, INSIDE, INSIDE, INSIDE, INSIDE))
  without <- mysterymaps_jenks_zero_scale(c(0, 1, 4, 9, 30))
  # Coverage passed explicitly: this is a 4-vector against a scale built from
  # 7, which is exactly the subset case color() refuses to guess about.
  expect_equal(with_out$color(c(1, 4, 9, 30), coverage = rep(INSIDE, 4)),
               without$color(c(1, 4, 9, 30)))
  # and the structural zeros are outside, not zero
  f <- with_out$color(c(0, 0, 0, 1, 4, 9, 30),
                      coverage = c(INSIDE, OUTSIDE, OUTSIDE, rep(INSIDE, 4)))
  expect_false(identical(f[[2]], f[[1]]))
})

test_that("a genuine in-catchment zero stays in the zero class", {
  # The negative control. If outside were inferred from the value, this row
  # would move and the bug would simply have relocated one package downstream.
  sc <- mysterymaps_jenks_zero_scale(
    c(0, NA, 7), coverage = c(INSIDE, OUTSIDE, INSIDE))
  expect_identical(sc$color(0, coverage = INSIDE), sc$leg_cols[[1]])
  expect_identical(sc$leg_labs[[1]], "0")
})

test_that("coverage is validated, not guessed", {
  expect_error(mysterymaps_jenks_zero_scale(c(0, 1), coverage = c(INSIDE)),
               "must line up")
  expect_error(mysterymaps_jenks_zero_scale(c(0, 1), coverage = c(INSIDE, "maybe")),
               "Unrecognised")
  expect_error(mysterymaps_jenks_zero_scale(c(0, 1), coverage = c(TRUE, NA)),
               "contains NA")
  expect_error(mysterymaps_jenks_zero_scale(c(0, 1), coverage = c(1, 2)),
               "must be logical")
})

test_that("colouring a different-length vector errors instead of dropping the class", {
  # A scale built nationally and applied to one state is legitimate. Silently
  # losing the outside class there is the failure mode nobody would re-check.
  sc <- mysterymaps_jenks_zero_scale(
    c(0, NA, 2, 8), coverage = c(INSIDE, OUTSIDE, INSIDE, INSIDE))
  expect_error(sc$color(c(2, 8)), "Pass `coverage` to color")
  expect_silent(sc$color(c(2, 8), coverage = c(INSIDE, INSIDE)))
})

test_that("the distinction survives every degenerate branch of the scale", {
  cases <- list(no_positive  = list(v = c(0, NA), cov = c(INSIDE, OUTSIDE)),
                one_positive = list(v = c(0, NA, 7), cov = c(INSIDE, OUTSIDE, INSIDE)),
                general      = list(v = c(0, NA, 1, 4, 9, 30),
                                    cov = c(INSIDE, OUTSIDE, rep(INSIDE, 4))))
  for (nm in names(cases)) {
    cc <- cases[[nm]]
    sc <- mysterymaps_jenks_zero_scale(cc$v, coverage = cc$cov)
    f <- sc$color(cc$v, coverage = cc$cov)
    expect_false(identical(f[[2]], f[[1]]), info = sprintf("branch: %s", nm))
    expect_true(any(grepl("No provider", sc$leg_labs)),
                info = sprintf("branch: %s", nm))
  }
})

test_that("the county template propagates coverage into the legend", {
  skip_if_not_installed("leaflet")
  cty <- mm_counties(6)
  cty$rate <- c(0, NA, 1.5, 3, 8, 20)
  cty$cov <- c(INSIDE, OUTSIDE, INSIDE, INSIDE, INSIDE, INSIDE)

  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL,
                                     coverage_col = "cov")
  labs <- unlist(mm_call_args(m, "addLegend"))
  expect_true(any(grepl("No provider", labs)))
})

test_that("the template names a bad coverage_col instead of ignoring it", {
  skip_if_not_installed("leaflet")
  cty <- mm_counties(4)
  cty$rate <- c(0, 1, 4, 9)
  expect_error(
    mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                  notes = NULL, search = NULL,
                                  coverage_col = "nope"),
    "not a column")
})

test_that("the template without coverage_col renders exactly as before", {
  skip_if_not_installed("leaflet")
  cty <- mm_counties(6)
  cty$rate <- c(0, NA, 1.5, 3, 8, 20)
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL)
  labs <- unlist(mm_call_args(m, "addLegend"))
  expect_false(any(grepl("No provider", labs)))
  expect_true(any(grepl("No data", labs)))
})

test_that("REGRESSION: the outside class cannot disappear during rendering", {
  # The explicit end-to-end guard. Fill is the high-risk place: the legend and
  # the underlying data can both be right while the polygons themselves are
  # shaded as measured zeros, and nothing about the map looks wrong.
  vals <- c(0, NA, 1.5, 3, 8, 20, NA)
  cov <- c(INSIDE, OUTSIDE, INSIDE, INSIDE, INSIDE, INSIDE, OUTSIDE)

  sc <- mysterymaps_jenks_zero_scale(vals, coverage = cov, digits = 1)
  fills <- sc$color(vals, coverage = cov)

  outside_fill <- unique(fills[cov == OUTSIDE])
  zero_fill <- unique(fills[cov == INSIDE & !is.na(vals) & vals == 0])

  expect_length(outside_fill, 1L)          # every outside row, one appearance
  expect_length(zero_fill, 1L)             # the genuine zero, the zero class
  expect_false(identical(outside_fill, zero_fill))
  expect_identical(zero_fill, sc$leg_cols[[1]])
  expect_false(any(fills[cov == OUTSIDE] %in% fills[cov == INSIDE]))
})

test_that("NEGATIVE CONTROL: dropping coverage collapses the distinction", {
  # Prove the test above can fail. Render the same data without coverage and
  # the outside rows become indistinguishable from the no-data rows -- which is
  # the defect, one layer quieter than the zero-class version.
  # Position 8 is the row that makes this a control at all: INSIDE with an
  # unknown value, i.e. genuinely missing. Without it there is no
  # missing-but-inside row for the outside rows to be confused WITH, and the
  # assertion below passes vacuously instead of failing. (It did, first run.)
  vals <- c(0, NA, 1.5, 3, 8, 20, NA, NA)
  cov <- c(INSIDE, OUTSIDE, INSIDE, INSIDE, INSIDE, INSIDE, OUTSIDE, INSIDE)

  collapsed <- mysterymaps_jenks_zero_scale(vals, digits = 1)   # no coverage
  cf <- collapsed$color(vals)

  # The outside rows and a genuinely-missing row now share one appearance ...
  expect_identical(unique(cf[cov == OUTSIDE]), unique(cf[is.na(vals)]))
  # ... so the assertion that protects the real behaviour fails here.
  expect_failure(
    expect_false(any(cf[cov == OUTSIDE] %in% cf[is.na(vals) & cov == INSIDE])))
  expect_false(any(grepl("No provider", collapsed$leg_labs)))
})

test_that("FROZEN COLORADO: 190 outside tracts never render in the zero class", {
  # The real surface, through the real map path. Guarded because the fixture
  # carries real provider coordinates and is not committed.
  fixture <- Sys.getenv("MM_CO_FIXTURE_DIR",
                        unset = path.expand("~/co-validation-fixture"))
  skip_if_not(file.exists(file.path(fixture, "e2sfca_corrected.rds")),
              "corrected Colorado surface not present")
  a <- readRDS(file.path(fixture, "e2sfca_corrected.rds"))

  sc <- mysterymaps_jenks_zero_scale(a$access_scaled, k = 6, digits = 2,
                                     coverage = a$coverage_status)
  fills <- sc$color(a$access_scaled, coverage = a$coverage_status)
  outside <- a$coverage_status == "outside_all_modeled_catchments"

  expect_equal(sum(outside), 190L)
  expect_equal(sum(fills[outside] == sc$leg_cols[[1]]), 0L)   # never the zero class
  expect_length(unique(fills[outside]), 1L)
  expect_false(unique(fills[outside]) %in% fills[!outside])

  # Any genuine reached-zero tract stays in the zero class. Colorado has none,
  # which is itself the finding: every zero on the old map was structural.
  reached_zero <- !outside & !is.na(a$access_scaled) & a$access_scaled == 0
  expect_equal(sum(reached_zero), 0L)
  if (any(reached_zero)) {
    expect_true(all(fills[reached_zero] == sc$leg_cols[[1]]))
  }
})

test_that("FROZEN COLORADO: removing 190 false zeros does not move the Jenks breaks", {
  # Reported rather than assumed. The scale already excluded zeros from
  # classification (`pos <- n[!is.na(n) & n > 0]`), so the false zeros never
  # entered the break computation -- they only occupied the zero class. If a
  # future change makes zeros influence breaks, this fails and the estimand
  # question has to be answered again rather than silently re-snapshotted.
  fixture <- Sys.getenv("MM_CO_FIXTURE_DIR",
                        unset = path.expand("~/co-validation-fixture"))
  skip_if_not(all(file.exists(file.path(fixture,
    c("e2sfca_corrected.rds", "e2sfca_twostep.rds")))),
    "Colorado surfaces not present")

  before <- readRDS(file.path(fixture, "e2sfca_twostep.rds"))$access   # 190 zeros
  after <- readRDS(file.path(fixture, "e2sfca_corrected.rds"))         # 190 NA

  sc_b <- mysterymaps_jenks_zero_scale(before$access_scaled, k = 6, digits = 2)
  sc_a <- mysterymaps_jenks_zero_scale(after$access_scaled, k = 6, digits = 2,
                                       coverage = after$coverage_status)

  pos_b <- sc_b$leg_labs[-1]                                   # drop zero class
  pos_a <- sc_a$leg_labs[-c(1, length(sc_a$leg_labs))]          # drop zero + outside
  expect_identical(pos_b, pos_a)

  # And the reached tracts are coloured identically before and after.
  fb <- sc_b$color(before$access_scaled)
  fa <- sc_a$color(after$access_scaled, coverage = after$coverage_status)
  reached <- after$coverage_status == "within_modeled_catchment"
  expect_identical(fb[reached], fa[reached])
})
