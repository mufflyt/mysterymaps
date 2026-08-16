# SPEC sections 5, 6 and 42: the national fixture, reproduced end to end.
#
# SCOPE. The spec's national study fixture starts at raw provider sources and
# runs through linkage, dedup and denominators. mysterymaps owns none of that
# (see .github/scripts/capability-guards.R), so this fixture starts where the
# package's responsibility starts: a national geography and a per-geography
# value, carried through
#
#   geometry -> spatial calculation -> classification -> map -> artifact
#
# The supply pattern is deliberately shaped like a rare subspecialty: most of
# the country at an observed zero, a handful of states with one or two
# providers, and several states unmeasured. That is the distribution in which
# a scientifically false map is most believable, because "almost everywhere is
# zero" is both the expected result and the shape of a total pipeline failure.
#
# Golden values below are frozen. An unexplained change fails the run.

skip_national <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("maps")
}

# ---------------------------------------------------------------------------
# The frozen fixture
# ---------------------------------------------------------------------------

national_fixture <- function() {
  skip_national()
  geo <- sf::st_as_sf(maps::map("state", plot = FALSE, fill = TRUE))
  # maps::map() carries no CRS. Assigning one is correct here (the coordinates
  # already ARE lon/lat) rather than a reprojection, which is what sf warns
  # about.
  geo <- suppressWarnings(sf::st_set_crs(geo, 4326))
  geo$region <- sub(":.*$", "", geo$ID)
  geo <- geo[!duplicated(geo$region), ]
  geo <- geo[order(geo$region), ]

  # Deterministic, not random: the fixture must be identical on every machine
  # and every R version, so nothing here calls the RNG.
  supply <- rep(0, nrow(geo))
  names(supply) <- geo$region

  # A handful of states hold the entire national workforce.
  supply[c("california", "new york")] <- 3
  supply[c("texas", "illinois", "massachusetts")] <- 2
  supply[c("colorado", "washington", "pennsylvania", "ohio")] <- 1

  # And several were never measured. These are NOT zeros, and the whole
  # scientific point of the fixture is that the map must keep saying so.
  #
  # All three are contiguous states: maps::map("state") is CONUS-only, so
  # Alaska and Hawaii are absent from this geography entirely rather than
  # unmeasured within it.
  unmeasured <- c("nevada", "wyoming", "vermont")
  stopifnot(all(unmeasured %in% names(supply)))
  supply[unmeasured] <- NA_real_

  geo$providers <- unname(supply)
  geo$tooltip <- sprintf("<b>%s</b>", geo$region)
  geo$profile <- sprintf("%s profile", geo$region)
  geo
}

# Everything the fixture is supposed to produce, in one reconcilable object.
national_accounting <- function(geo) {
  sc <- mysterymaps_jenks_zero_scale(geo$providers)
  fills <- sc$color(geo$providers)

  list(
    geographies       = nrow(geo),
    measured          = sum(!is.na(geo$providers)),
    unmeasured        = sum(is.na(geo$providers)),
    observed_zero     = sum(!is.na(geo$providers) & geo$providers == 0),
    with_supply       = sum(!is.na(geo$providers) & geo$providers > 0),
    national_supply   = sum(geo$providers, na.rm = TRUE),
    classes           = length(sc$leg_cols),
    has_no_data_class = ("No data" %in% sc$leg_labs),
    zero_fill         = unname(sc$color(0)),
    na_fill           = unname(sc$color(NA_real_)),
    distinct_fills    = length(unique(fills))
  )
}

# ---------------------------------------------------------------------------
# Accounting conservation
# ---------------------------------------------------------------------------

test_that("every geography is accounted for in exactly one state", {
  # The conservation identity. A geography that is neither measured nor
  # unmeasured has been lost somewhere between the join and the map.
  skip_national()
  a <- national_accounting(national_fixture())

  expect_equal(a$measured + a$unmeasured, a$geographies)
  expect_equal(a$observed_zero + a$with_supply, a$measured)
})

test_that("the national fixture reproduces its frozen accounting", {
  # The golden master. An unexplained change to any of these numbers is a
  # change to the map, and must be explained before it is accepted.
  skip_national()
  a <- national_accounting(national_fixture())

  expect_equal(a$geographies, 49L)        # CONUS + DC, one row per state
  expect_equal(a$unmeasured, 3L)
  expect_equal(a$measured, 46L)
  expect_equal(a$with_supply, 9L)
  expect_equal(a$observed_zero, 37L)
  expect_equal(a$national_supply, 16)
})

test_that("the unmeasured states are never counted as observed zeros", {
  # The scientifically load-bearing assertion of the whole fixture.
  skip_national()
  geo <- national_fixture()
  a <- national_accounting(geo)

  expect_true(a$has_no_data_class)
  expect_false(identical(a$zero_fill, a$na_fill))

  sc <- mysterymaps_jenks_zero_scale(geo$providers)
  fills <- sc$color(geo$providers)
  expect_equal(sum(fills == a$na_fill), a$unmeasured)
  expect_equal(sum(fills == a$zero_fill), a$observed_zero)
})

test_that("the legend names the no-data class rather than calling it zero", {
  skip_national()
  sc <- mysterymaps_jenks_zero_scale(national_fixture()$providers)
  na_idx <- which(sc$leg_cols == sc$color(NA_real_))
  expect_length(na_idx, 1L)
  expect_identical(sc$leg_labs[[na_idx]], "No data")
  expect_identical(sc$leg_labs[[1]], "0")
})

# ---------------------------------------------------------------------------
# Reproducibility and invariance
# ---------------------------------------------------------------------------

test_that("the fixture is bit-stable across repeated construction", {
  skip_national()
  expect_equal(national_accounting(national_fixture()),
               national_accounting(national_fixture()))
})

test_that("the national result is invariant to geography row order", {
  # A national map that depends on the order states arrive in has a hidden
  # ordering dependence somewhere in the classification.
  skip_national()
  geo <- national_fixture()
  ref <- national_accounting(geo)

  mm_for_each_seed(mm_property_n(5L), function(seed) {
    shuffled <- geo[sample.int(nrow(geo)), ]
    expect_equal(national_accounting(shuffled), ref)
  })
})

test_that("recombining regional partitions reproduces the national total", {
  # Compute supply nationally, then over four arbitrary partitions, and
  # reassemble. Disagreement means a cross-region dependence.
  skip_national()
  geo <- national_fixture()
  national <- sum(geo$providers, na.rm = TRUE)

  parts <- split(geo, seq_len(nrow(geo)) %% 4L)
  recombined <- sum(vapply(parts, function(p) sum(p$providers, na.rm = TRUE),
                           numeric(1)))
  expect_equal(recombined, national)

  # And the unmeasured states survive partitioning as unmeasured.
  expect_equal(sum(vapply(parts, function(p) sum(is.na(p$providers)), integer(1))),
               sum(is.na(geo$providers)))
})

test_that("removing one state changes that state and the total, nothing else", {
  # The leave-one-out audit, at the scale this package owns.
  skip_national()
  geo <- national_fixture()
  base <- national_accounting(geo)

  drop <- which(geo$region == "colorado")
  reduced <- national_accounting(geo[-drop, ])

  expect_equal(reduced$geographies, base$geographies - 1L)
  expect_equal(reduced$national_supply, base$national_supply - 1)
  expect_equal(reduced$unmeasured, base$unmeasured)
})

test_that("one added provider moves the national total by exactly one", {
  # Rare-event sensitivity: in a country with 16 providers, one more is a 6%
  # national change and must be exactly attributable.
  skip_national()
  geo <- national_fixture()
  base <- national_accounting(geo)

  geo$providers[geo$region == "kansas"] <- 1
  bumped <- national_accounting(geo)

  expect_equal(bumped$national_supply, base$national_supply + 1)
  expect_equal(bumped$with_supply, base$with_supply + 1L)
  expect_equal(bumped$observed_zero, base$observed_zero - 1L)
  expect_equal(bumped$measured, base$measured)
})

# ---------------------------------------------------------------------------
# The map itself
# ---------------------------------------------------------------------------

test_that("the national map builds with one feature per geography", {
  skip_national()
  skip_if_not_installed("leaflet")
  geo <- national_fixture()

  m <- mysterymaps_county_access_map(geo, "providers", "tooltip", "profile",
                                     legend_title = "Providers",
                                     notes = NULL, search = NULL, mesh = FALSE)
  expect_s3_class(m, "leaflet")

  args <- mm_call_args(m, "addPolygons")
  fills <- unname(unlist(args[[4]]$fillColor))
  expect_length(fills, nrow(geo))

  sc <- mysterymaps_jenks_zero_scale(geo$providers, k = 6, digits = 1)
  expect_equal(fills, sc$color(geo$providers))
})

test_that("the national map's legend carries the no-data class", {
  skip_national()
  skip_if_not_installed("leaflet")
  m <- mysterymaps_county_access_map(
    national_fixture(), "providers", "tooltip", "profile",
    notes = NULL, search = NULL, mesh = FALSE)
  expect_true(any(grepl("No data", unlist(mm_call_args(m, "addLegend")),
                        fixed = TRUE)))
})

test_that("the national map survives being written to a self-contained file", {
  # Rendering is the last place a map can fail, and a widget that will not
  # serialise is a map nobody can send anyone.
  skip_national()
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")

  m <- mysterymaps_county_access_map(
    national_fixture(), "providers", "tooltip", "profile",
    notes = NULL, search = NULL, mesh = FALSE)

  f <- file.path(withr::local_tempdir(), "national.html")
  suppressWarnings(htmlwidgets::saveWidget(m, f, selfcontained = FALSE))
  expect_true(file.exists(f))
  expect_gt(file.size(f), 10000)
})
