# SPEC section 20: spatial geometry assault.
#
# Routing APIs and national boundary files routinely return geometry that is
# syntactically fine and topologically broken. Every case below must produce
# exactly one of three outcomes:
#
#   correct result           the geometry was usable as-is
#   documented repair        it was fixed, and the fix is inspectable
#   informative failure      it was rejected, by name, with a reason
#
# The forbidden fourth outcome is silent feature loss: a polygon that quietly
# vanishes, an area that quietly becomes zero, a row that quietly disappears
# from a national count. That outcome produces a map, and the map is wrong.

skip_no_sf <- function() skip_if_not_installed("sf")

test_that("every pathological geometry meets its declared contract", {
  skip_no_sf()
  corpus <- mm_bad_geometries()

  for (nm in names(corpus)) {
    case <- corpus[[nm]]
    obj <- sf::st_sf(id = 1L, geometry = case$geom)
    info <- sprintf("%s: %s (contract: %s)", nm, case$why, case$contract)

    result <- tryCatch(
      list(ok = TRUE, value = validate_sf_inputs(shape = obj)),
      error = function(e) list(ok = FALSE, msg = conditionMessage(e)))

    if (identical(case$contract, "reject")) {
      expect_false(result$ok, info = info)
      # An informative failure names the object and says something specific.
      expect_true(nchar(result$msg) > 20, info = info)
      expect_match(result$msg, "shape|CRS|empty|degenerate|invalid|bounding",
                   info = info)
    } else {
      expect_true(result$ok, info = info)
      out <- result$value$shape
      # Whatever happened, a feature came back and it is valid.
      expect_equal(nrow(out), 1L, info = info)
      expect_true(all(sf::st_is_valid(out)), info = info)
      expect_false(any(sf::st_is_empty(sf::st_geometry(out))), info = info)
    }
  }
})

test_that("a bowtie is repaired into valid geometry with positive area", {
  # The named regression: s2 declines to repair a self-intersecting ring that
  # the planar algorithm splits cleanly, and a self-intersecting ring is
  # precisely what a drive-time routing API returns.
  skip_no_sf()
  bowtie <- sf::st_sf(id = 1L, geometry = mm_bad_geometries()$bowtie$geom)
  expect_false(all(sf::st_is_valid(bowtie)))

  out <- validate_sf_inputs(shape = bowtie)$shape
  expect_true(all(sf::st_is_valid(out)))

  area <- as.numeric(sum(sf::st_area(sf::st_transform(out, 5070))))
  expect_true(is.finite(area))
  expect_gt(area, 0)
  expect_equal(sf::st_crs(out), sf::st_crs(4326))
})

test_that("a genuinely unrepairable geometry fails closed, it does not vanish", {
  # The distinction that matters: "I fixed it" and "I dropped it" look
  # identical downstream unless one of them is an error.
  skip_no_sf()
  bad <- sf::st_sf(id = 1L, geometry = mm_bad_geometries()$unrepairable$geom)
  expect_error(validate_sf_inputs(shape = bad))
})

test_that("a hole is preserved: area excludes the interior ring", {
  # A polygon with a hole that silently loses its hole overstates area, and
  # therefore overstates coverage, by the size of the hole.
  skip_no_sf()
  with_hole <- sf::st_sf(id = 1L, geometry = mm_bad_geometries()$with_hole$geom)
  out <- validate_sf_inputs(shape = with_hole)$shape

  outer_only <- sf::st_sf(id = 1L, geometry = mm_rect(0, 0, 4, 4))

  a_hole <- as.numeric(sf::st_area(sf::st_transform(out, 5070)))
  a_full <- as.numeric(sf::st_area(sf::st_transform(outer_only, 5070)))
  expect_lt(a_hole, a_full)
})

test_that("a multipolygon keeps every part; a multipart state stays multipart", {
  # Michigan is two land masses. Keeping only the larger one loses the Upper
  # Peninsula and every provider in it.
  skip_no_sf()
  mp <- sf::st_sf(id = 1L, geometry = mm_bad_geometries()$multipolygon$geom)
  out <- validate_sf_inputs(shape = mp)$shape

  n_parts <- length(sf::st_cast(sf::st_geometry(out), "POLYGON"))
  expect_equal(n_parts, 2L)
})

test_that("mixed geometry types are rejected when a type is required", {
  skip_no_sf()
  mixed <- rbind(
    sf::st_sf(id = 1L, geometry = mm_rect(0, 0, 1, 1)),
    sf::st_sf(id = 2L, geometry = sf::st_sfc(sf::st_point(c(5, 5)), crs = 4326)))
  expect_error(
    validate_sf_inputs(shape = mixed,
                       expected_types = c("POLYGON", "MULTIPOLYGON")),
    "geometry types")
})

test_that("mismatched CRS is transformed and announced, never assumed away", {
  # Two objects silently treated as sharing a CRS produce an intersection of
  # zero area and a coverage figure of 0%, which reads as a finding.
  skip_no_sf()
  a <- sf::st_sf(id = 1L, geometry = mm_rect(-100, 40, -99, 41))
  b <- sf::st_transform(a, 5070)
  expect_warning(out <- validate_sf_inputs(a = a, b = b), "CRS")
  expect_equal(sf::st_crs(out$b), sf::st_crs(out$a))
})

test_that("a feature is never silently lost across validation", {
  # The blunt conservation check: rows in equals rows out, for every case the
  # contract says is survivable.
  skip_no_sf()
  corpus <- mm_bad_geometries()
  survivable <- corpus[vapply(corpus, function(x) x$contract != "reject", logical(1))]

  for (nm in names(survivable)) {
    geoms <- c(survivable[[nm]]$geom, mm_rect(50, 10, 51, 11))
    obj <- sf::st_sf(id = 1:2, geometry = geoms)
    out <- validate_sf_inputs(shape = obj)$shape
    expect_equal(nrow(out), 2L, info = nm)
    expect_setequal(out$id, 1:2)
  }
})

test_that("a sliver survives with a small but non-negative area", {
  # Slivers arise from differencing two boundary vintages. They are not errors
  # and must not become negative or NaN.
  skip_no_sf()
  sliver <- sf::st_sf(id = 1L, geometry = mm_bad_geometries()$sliver$geom)
  out <- validate_sf_inputs(shape = sliver)$shape
  a <- as.numeric(sf::st_area(sf::st_transform(out, 5070)))
  expect_true(is.finite(a))
  expect_gte(a, 0)
})

test_that("the coverage gate treats swapped coordinates as a miss, not a pass", {
  # Longitude and latitude transposed puts a Denver provider in the Indian
  # Ocean. The gate must notice they are outside their own surface.
  skip_no_sf()
  surface <- mm_surface(x = -105, y = 39, w = 2, h = 2)
  swapped <- sf::st_as_sf(
    data.frame(name = "swapped", lon = 39.7, lat = -104.9),
    coords = c("lon", "lat"), crs = 4326)

  expect_error(
    suppressMessages(mysterymaps_gate_provider_coverage(swapped, surface)),
    "OUTSIDE the surface")
})
