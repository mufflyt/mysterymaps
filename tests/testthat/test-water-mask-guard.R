sq <- function(n) {
  skip_if_not_installed("sf")
  sf::st_sfc(sf::st_polygon(list(cbind(c(0,n,n,0,0), c(0,0,n,n,0)))), crs = 4326)
}

test_that("a mask the size of its state is rejected", {
  # 102-104% of land area, single feature: a state outline, not water.
  m <- list(MO = sq(4))            # large
  aw <- c(MO = 1)                  # tiny mapped water
  expect_warning(out <- mysterymaps_guard_water_masks(m, aw), "state outlines")
  expect_length(out, 0L)
  # The attribute reports which state was dropped and how far off it was; a
  # bare non-NULL check would pass on an empty or mislabelled vector.
  expect_named(attr(out, "inverted"), "MO")
  expect_gt(attr(out, "inverted")[["MO"]], 5)
})

test_that("REGRESSION: a Great Lakes state is NOT rejected", {
  # Michigan's boundary contains the Great Lakes, so a large mask is correct.
  # Comparing to LAND area flagged it at 68% and would have let the surface run
  # across Lake Michigan -- the failure the clip exists to prevent.
  g <- sq(2)
  a <- as.numeric(sf::st_area(g)) / 1e6
  m <- list(MI = g)
  # expect_silent() cannot see through suppressMessages(): the messages are
  # gone before the expectation runs, so it only ever tested for warnings.
  # The claim worth making is the explicit one -- Michigan is not flagged.
  expect_no_warning(suppressMessages(out <- mysterymaps_guard_water_masks(m, c(MI = a))))
  expect_length(out, 1L)
  expect_null(attr(out, "inverted"))
})

test_that("plausible masks pass untouched", {
  g <- sq(1)
  a <- as.numeric(sf::st_area(g)) / 1e6
  out <- suppressMessages(mysterymaps_guard_water_masks(list(NY = g), c(NY = a * 2)))
  expect_named(out, "NY")
})

test_that("error mode aborts instead of excluding", {
  expect_error(
    mysterymaps_guard_water_masks(list(KS = sq(4)), c(KS = 1), action = "error"),
    "state outlines")
})

test_that("a state with no census water figure is not judged", {
  # Absent denominator means unknown, not guilty.
  out <- suppressWarnings(suppressMessages(
    mysterymaps_guard_water_masks(list(XX = sq(4)), c(YY = 1))))
  expect_length(out, 1L)
})

test_that("the threshold is a parameter, and 5x is the default", {
  expect_equal(formals(mysterymaps_guard_water_masks)$max_ratio, 5)
  g <- sq(2); a <- as.numeric(sf::st_area(g)) / 1e6
  expect_warning(mysterymaps_guard_water_masks(list(A = g), c(A = a / 10), max_ratio = 5))
  expect_no_warning(suppressMessages(
    mysterymaps_guard_water_masks(list(A = g), c(A = a / 10), max_ratio = 20)))
})

# ---------------------------------------------------------------------------
# The guard's own units
# ---------------------------------------------------------------------------
#
# The verdict is a ratio of the mask's area to the state's census water area,
# and the denominator arrives in km^2 by contract (`tigris::states()$AWATER /
# 1e6`). The numerator therefore has to be km^2 too -- and it was computed as
# st_area()/1e6, which is km^2 only when the mask's CRS is in metres.

# sq() builds its squares at lon 0, lat 0 -- fine for a ratio, useless for a
# reprojection test, because a state plane CRS extrapolates silently far outside
# its own zone and the distortion would read as a finding about the code. These
# sit inside Colorado, so EPSG:2232 (NAD83 / Colorado Central, US survey feet)
# is the CRS a Colorado study would actually reach for.
co_sq <- function(deg) {
  skip_if_not_installed("sf")
  sf::st_sfc(sf::st_polygon(list(cbind(
    c(-105.5, -105.5 + deg, -105.5 + deg, -105.5, -105.5),
    c(38.5, 38.5, 38.5 + deg, 38.5 + deg, 38.5)))), crs = 4326)
}

test_that("REGRESSION: a mask in survey feet is measured in km^2, not ft^2/1e6", {
  # The bug in one line. A polygon of A km^2 measures 10.76*A under the old
  # arithmetic, because a square US survey foot is 1/10.7639 of a square metre
  # and the /1e6 assumed metres.
  skip_if_not_installed("sf")
  skip_if_not_installed("units")
  g <- co_sq(1)
  truth <- mm_area_in(g, "km^2")
  in_feet <- sf::st_transform(g, 2232)

  expect_equal(mm_area_in(in_feet, "km^2"), truth, tolerance = 1e-3)
  # And the arithmetic that used to be here agrees with neither.
  expect_gt(as.numeric(sf::st_area(in_feet)) / 1e6 / truth, 10)
})

test_that("REGRESSION: a legitimate mask in feet is not excluded as a state outline", {
  # The consequence, stated as the guard's verdict rather than as a number.
  # Michigan's Great Lakes mask is about 0.95x its census water. Inflate the
  # numerator 10.76x and it reads as 10.2x -- past max_ratio = 5 -- so the
  # guard drops the only thing keeping the coverage surface off the lakes.
  skip_if_not_installed("sf")
  skip_if_not_installed("units")
  g <- co_sq(2)
  census_water <- mm_area_in(g, "km^2") / 0.95      # mask is 0.95x mapped water

  in_feet <- sf::st_transform(g, 2232)
  expect_no_warning(suppressMessages(
    out <- mysterymaps_guard_water_masks(list(MI = in_feet), c(MI = census_water))))
  expect_named(out, "MI")
  expect_null(attr(out, "inverted"))
})

test_that("the verdict is identical whatever CRS the mask arrives in", {
  # The scientific claim: the guard is about the geometry, not about how the
  # caller happened to store it. An inverted mask stays inverted and a
  # plausible one stays plausible, in lon/lat, in Albers metres, in Web
  # Mercator and in survey feet.
  skip_if_not_installed("sf")
  skip_if_not_installed("units")
  crs_list <- c(lonlat = 4326L, albers = 5070L, webmerc = 3857L, feet = 2232L)

  inverted <- co_sq(4); plausible <- co_sq(1)
  aw <- c(ST = mm_area_in(plausible, "km^2") * 2)   # plausible is 0.5x water

  verdicts <- vapply(crs_list, function(crs) {
    bad <- suppressWarnings(suppressMessages(mysterymaps_guard_water_masks(
      list(ST = sf::st_transform(inverted, crs)), aw)))
    good <- suppressMessages(mysterymaps_guard_water_masks(
      list(ST = sf::st_transform(plausible, crs)), aw))
    length(bad) == 0L && length(good) == 1L
  }, logical(1))
  expect_true(all(verdicts))
})

test_that("a mask with no CRS is refused by name, not measured in unknown units", {
  # An area whose unit is unknown cannot be compared to a km^2 denominator.
  # Guessing metres is how the factor got in; the error names the state so the
  # one bad mask in fifty is findable.
  skip_if_not_installed("sf")
  naked <- sf::st_sfc(sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0),
                                                c(0, 0, 1, 1, 0)))))
  expect_error(mysterymaps_guard_water_masks(list(MO = naked), c(MO = 1)),
               "water mask 'MO'")
  expect_error(mysterymaps_guard_water_masks(list(MO = naked), c(MO = 1)),
               "no CRS")
})
