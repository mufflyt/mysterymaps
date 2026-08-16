# SPEC section 38 (output contracts) and the package-owned half of section 37
# (provenance).
#
# The provenance split matters. mysterymaps is responsible for recording what
# IT did to the data: the CRS it measured in, the area method, the value column
# it was asked to shade, the seed it jittered with, the schema it wrote. It is
# NOT responsible for source hashes, roster vintages, linkage thresholds or
# denominator years, because it never sees them -- those are guarded by
# .github/scripts/capability-guards.R and are NOT OWNED rather than NOT TESTED.
#
# Every artifact this package promises must exist, carry the documented schema,
# and round-trip without losing information.

skip_no_sf <- function() skip_if_not_installed("sf")

overlap_run <- function() {
  out <- withr::local_tempdir(.local_envir = parent.frame())
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))
  out
}

# ---------------------------------------------------------------------------
# Existence and schema
# ---------------------------------------------------------------------------

test_that("every promised artifact exists after a run", {
  skip_no_sf()
  out <- overlap_run()
  for (f in c("intersect_30_minutes.shp", "intersect_30_minutes.csv",
              "intersect_30_minutes.csvt")) {
    expect_true(file.exists(file.path(out, f)), info = f)
    expect_gt(file.size(file.path(out, f)), 0)
  }
})

test_that("the canonical CSV carries exactly the documented columns", {
  skip_no_sf()
  out <- overlap_run()
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_named(tbl, c("GEOID", "intersect_area", "area_method"))
  expect_type(tbl$GEOID, "character")
  expect_type(tbl$intersect_area, "double")
  expect_type(tbl$area_method, "character")
})

test_that("column types are declared in the csvt sidecar", {
  skip_no_sf()
  out <- overlap_run()
  types <- strsplit(gsub('"', "", readLines(
    file.path(out, "intersect_30_minutes.csvt"), warn = FALSE)[1]), ",")[[1]]
  expect_length(types, 3L)
  expect_identical(types[[1]], "String")   # GEOID is an identifier
  expect_identical(types[[2]], "Real")
  expect_identical(types[[3]], "String")
})

test_that("area_method uses a controlled vocabulary, not free text", {
  # A method column that can say anything cannot be checked by anyone.
  skip_no_sf()
  out <- overlap_run()
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_true(all(tbl$area_method %in% c("projected:EPSG:5070")))
  expect_true(all(grepl("^projected:EPSG:[0-9]+$", tbl$area_method)))
})

test_that("values round-trip through the CSV without loss", {
  skip_no_sf()
  out <- overlap_run()
  csv <- file.path(out, "intersect_30_minutes.csv")
  tbl <- utils::read.csv(csv, colClasses = c(GEOID = "character"))

  again <- file.path(out, "again.csv")
  utils::write.csv(tbl, again, row.names = FALSE)
  back <- utils::read.csv(again, colClasses = c(GEOID = "character"))

  expect_equal(back$GEOID, tbl$GEOID)
  expect_equal(back$intersect_area, tbl$intersect_area, tolerance = 1e-9)
  expect_equal(back$area_method, tbl$area_method)
})

test_that("the CSV and the shapefile describe the same features", {
  # Two representations of one result. If they disagree, one of them is the
  # number someone will publish.
  skip_no_sf()
  out <- overlap_run()
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  shp <- sf::st_read(file.path(out, "intersect_30_minutes.shp"), quiet = TRUE)

  expect_equal(nrow(tbl), nrow(shp))
  expect_setequal(tbl$GEOID, as.character(shp$GEOID))
})

test_that("the shapefile is written in EPSG:4326 regardless of measurement CRS", {
  skip_no_sf()
  out <- overlap_run()
  shp <- sf::st_read(file.path(out, "intersect_30_minutes.shp"), quiet = TRUE)
  expect_equal(sf::st_crs(shp)$epsg, 4326L)
})

test_that("a malformed output path fails loudly rather than writing nowhere", {
  skip_no_sf()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, ""),
    "non-empty character string")
})

test_that("re-running overwrites rather than appending", {
  # Silent append doubles every row on the second run, and the resulting
  # coverage figure is exactly twice the truth.
  skip_no_sf()
  out <- withr::local_tempdir()
  for (i in 1:2) {
    suppressWarnings(suppressMessages(
      mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))
  }
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_equal(anyDuplicated(tbl$GEOID), 0L)
})

# ---------------------------------------------------------------------------
# Package-owned provenance (SPEC 37, current-package half)
# ---------------------------------------------------------------------------

test_that("the artifact records the CRS it was measured in", {
  # Without this, an area column is a number with no units and no method.
  skip_no_sf()
  out <- overlap_run()
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_match(tbl$area_method[[1]], "5070")
})

test_that("the jitter seed is recorded on the map object", {
  # The subject is the recorded seed, not the district layer.
  mm_setup_dot_map()

  pd <- data.frame(long = c(-105, -104), lat = c(39, 40),
                   name = c("a", "b"),
                   ACOG_District = c("District VIII", "District VIII"))
  m <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(pd, output_dir = withr::local_tempdir(), seed = 7)))
  expect_equal(attr(m, "mysterymaps_seed"), 7)
})

test_that("the scale reports whether it emitted a no-data class", {
  # Machine-readable provenance for the most consequential display decision
  # the package makes.
  # The scale reports this through the legend rather than a flag: the no-data
  # entry is emitted only when some value is actually missing.
  expect_true("No data" %in% mysterymaps_jenks_zero_scale(c(0, NA, 4))$leg_labs)
  expect_false("No data" %in% mysterymaps_jenks_zero_scale(c(0, 2, 4))$leg_labs)
})

test_that("coverage-surface registration records which legend belongs to which group", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list("Within 30 minutes" = mm_surface()),
    colors = "#08519c")
  reg <- attr(m, "mysterymaps_base_legends")
  expect_named(reg, "Within 30 minutes")
  expect_type(reg[[1]], "character")
})

test_that("the coverage gate returns a reconcilable count, not just a verdict", {
  # n = inside + outside. The identity a caller needs in order to report how
  # much of the surface was actually built.
  skip_no_sf()
  res <- suppressMessages(mysterymaps_gate_provider_coverage(
    mm_points(4), mm_surface(x = -101, y = 39, w = 6, h = 4)))
  expect_named(res, c("n", "n_outside", "pct_outside", "by_group"))
  expect_equal(res$n, 4L)
  expect_equal(res$pct_outside, 100 * res$n_outside / res$n)
})
