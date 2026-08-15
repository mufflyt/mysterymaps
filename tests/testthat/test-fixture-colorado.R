# The fixture is only useful if it really carries the pathologies it claims.
# A fixture that quietly loses its bow tie stops testing repair, and every
# suite built on it goes green for the wrong reason. These tests guard it.

test_that("the fixture keeps zero and NA as different things", {
  skip_if_not_installed("sf")
  co <- co_counties()
  expect_true(any(co$rate == 0, na.rm = TRUE))
  expect_true(anyNA(co$rate))
  # The pairing that matters: a county measured at zero and a county never
  # measured must not be collapsible to the same value.
  expect_false(identical(which(co$rate == 0), which(is.na(co$rate))))
  expect_equal(sum(co$rate == 0, na.rm = TRUE), 2L)
  expect_equal(sum(is.na(co$rate)), 2L)
})

test_that("the study area is separable from its border counties", {
  skip_if_not_installed("sf")
  co <- co_counties()
  expect_equal(nrow(co), 14L)
  expect_equal(sum(co$in_study), 12L)
  expect_false(any(duplicated(co$geoid)))
})

test_that("the fixture carries a hole and an island, and is otherwise valid", {
  skip_if_not_installed("sf")
  co <- co_counties()
  g <- sf::st_geometry(co)

  # County 3: two rings, so an area that ignores the inner one is too big.
  expect_length(g[[3]], 2L)

  # County 5: two disjoint parts, so keeping the largest drops real ground.
  expect_s3_class(g[[5]], "MULTIPOLYGON")
  expect_length(g[[5]], 2L)

  # The baseline must be usable: every downstream test would otherwise fail at
  # s2 conversion rather than on the behaviour it means to check.
  expect_true(all(suppressMessages(sf::st_is_valid(g))))
})

test_that("the bow tie is invalid, repairable, and repairs to a real area", {
  skip_if_not_installed("sf")
  co_without_s2({
    bt <- co_bowtie()
    expect_false(sf::st_is_valid(bt))
    repaired <- suppressMessages(sf::st_make_valid(bt))
    expect_true(sf::st_is_valid(repaired))
    expect_gt(as.numeric(sf::st_area(repaired)), 0)
  })
})

test_that("s2 refuses the bow tie outright, which is why it is kept separate", {
  skip_if_not_installed("sf")
  skip_if_not_installed("s2")
  skip_if_not(isTRUE(sf::sf_use_s2()), "s2 is off in this session")
  # Documents the constraint that shaped the fixture: this is a read failure,
  # not a validity report, so nothing downstream can inspect its way out of it.
  expect_error(sf::st_area(co_bowtie()), "crosses edge")
})

test_that("providers include duplicates, a boundary case and outsiders", {
  skip_if_not_installed("sf")
  p <- co_providers()
  expect_equal(nrow(p), 10L)

  # Duplicate coordinates: three providers share one point, which is ordinary
  # in a roster (a group practice) and breaks anything assuming uniqueness.
  xy <- sf::st_coordinates(p)
  expect_gt(sum(duplicated(xy)), 0L)

  # The boundary provider sits exactly on a shared county edge -- verified, not
  # assumed: its x equals both counties' shared bound to the last bit. s2
  # resolves the tie to exactly one county. That is the property worth pinning:
  # counted once. Two hits would double-count them, zero would lose them, and
  # both errors move a denominator without moving anything visible on the map.
  co <- co_counties()
  hits <- suppressMessages(sf::st_intersects(p[5, ], co))[[1]]
  expect_length(hits, 1L)

  # Two providers fall outside every study county.
  study <- co[co$in_study, ]
  inside <- lengths(suppressMessages(sf::st_intersects(p, study))) > 0
  expect_equal(sum(!inside), 2L)
})

test_that("an empty provider geometry is present and stays empty", {
  skip_if_not_installed("sf")
  p <- co_providers_with_empty()
  expect_equal(nrow(p), 11L)
  empty <- sf::st_is_empty(p)
  expect_equal(sum(empty), 1L)
  # The row survives as a row: dropping it silently would move a denominator.
  expect_equal(p$note[empty], "empty geometry")
})

test_that("drive-time bands are strictly nested and strictly increasing", {
  skip_if_not_installed("sf")
  b <- co_bands()
  expect_named(b, c("30 minutes", "60 minutes", "120 minutes", "180 minutes"))

  # 30 within 60 within 120 within 180. This is the invariant every coverage
  # surface depends on; if the fixture ever stops satisfying it, tests built
  # on it are asserting nothing.
  for (i in seq_len(length(b) - 1)) {
    covered <- suppressMessages(sf::st_covered_by(b[[i]], b[[i + 1]], sparse = FALSE))
    expect_true(covered[1, 1],
                info = paste(names(b)[i], "is not inside", names(b)[i + 1]))
  }

  areas <- vapply(b, function(x) as.numeric(sf::st_area(x)), numeric(1))
  expect_true(all(diff(areas) > 0))
  expect_true(all(areas > 0))
})
