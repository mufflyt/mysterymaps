# ACOG districts are built by joining a packaged state->district lookup to
# Natural Earth state geometries. The lookup is a CSV that has arrived with a
# byte-order mark and with non-ASCII in its header before now, so the column
# repair is tested directly rather than assumed.

write_lookup <- function(dir, header = "State,ACOG_District,Subregion",
                         rows = c("Colorado,District VIII,Mountain",
                                  "California,District IX,Pacific")) {
  path <- file.path(dir, "acog.csv")
  writeLines(c(header, rows), path)
  path
}

test_that("a missing lookup file is refused, with the path in the message", {
  # Without sf the function stops at its own requireNamespace guard, so the
  # expect_error() below would match the wrong error.
  skip_if_not_installed("sf")
  skip_if_not_installed("readr")
  expect_error(mysterymaps_map_acog_districts(file.path(tempdir(), "nope.csv")),
               "Could not locate the ACOG districts file")
  expect_error(mysterymaps_map_acog_districts(""),
               "Could not locate the ACOG districts file")
})

test_that("a lookup with no State column is refused", {
  # Without sf the function stops at its own requireNamespace guard, so the
  # expect_error() below would match the wrong error.
  skip_if_not_installed("sf")
  skip_if_not_installed("readr")
  dir <- withr::local_tempdir()
  path <- write_lookup(dir, header = "Place,ACOG_District,Subregion")
  expect_error(mysterymaps_map_acog_districts(path),
               "must contain a 'State' column")
})

test_that("a UTF-8 BOM on the State header is repaired, not fatal", {
  # Excel writes one on every CSV it exports, and "﻿State" is not "State".
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bom.csv")
  con <- file(path, open = "wb")
  writeBin(charToRaw("﻿State,ACOG_District,Subregion\n"), con)
  writeBin(charToRaw("Colorado,District VIII,Mountain\n"), con)
  close(con)

  expect_no_error(mysterymaps_map_acog_districts(path))
})

test_that("districts come back as sf polygons, one row per district", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  out <- mysterymaps_map_acog_districts(write_lookup(dir))

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 2L)
  expect_true(all(c("ACOG_District", "Subregion", "States",
                    "State_Abbreviations") %in% names(out)))
})

test_that("states in one district are dissolved into a single geometry", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  path <- write_lookup(dir, rows = c("Colorado,District VIII,Mountain",
                                     "Wyoming,District VIII,Mountain"))
  out <- mysterymaps_map_acog_districts(path)

  expect_equal(nrow(out), 1L)
  expect_match(out$States, "Colorado")
  expect_match(out$States, "Wyoming")
})

test_that("districts are returned in sorted order", {
  # The colour ramp is assigned by position, so an unstable order silently
  # recolours the whole map between runs.
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  path <- write_lookup(dir, rows = c("Wyoming,District Z,Mountain",
                                     "Colorado,District A,Mountain"))
  out <- mysterymaps_map_acog_districts(path)
  expect_false(is.unsorted(out$ACOG_District))
})

test_that("a lookup naming no real state is an error, not an empty map", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  path <- write_lookup(dir, rows = "Atlantis,District I,Nowhere")
  expect_error(mysterymaps_map_acog_districts(path),
               "No matching states were found")
})

test_that("State_Abbreviations falls back to the Natural Earth postal code", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  dir <- withr::local_tempdir()
  out <- mysterymaps_map_acog_districts(write_lookup(dir))
  expect_false(anyNA(out$State_Abbreviations))
  expect_true(any(grepl("CO", out$State_Abbreviations)))
})

test_that("sf, readr and rnaturalearth are each named in their own error", {
  dir <- withr::local_tempdir()
  path <- write_lookup(dir)
  for (pkg in c("sf", "readr", "rnaturalearth")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(mysterymaps_map_acog_districts(path),
                 sprintf("'%s' is required", pkg))
  }
})

# ---------------------------------------------------------------------------
# The branches the dot-map tests used to reach incidentally
# ---------------------------------------------------------------------------
#
# Mocking mysterymaps_map_acog_districts() out of the dot-map tests was right --
# those tests are about jitter and seeding -- but it removed the only thing
# exercising these paths. They are error and fallback branches, which is
# exactly the code that most needs a test of its own rather than incidental
# traffic from somewhere else.

test_that("the packaged table is used when no file is given", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")
  p <- system.file("extdata", "acog_districts.csv", package = "mysterycall")
  skip_if(!nzchar(p), "mysterycall's packaged table is unavailable")

  out <- mysterymaps_map_acog_districts()
  expect_s3_class(out, "sf")
  expect_gt(nrow(out), 0L)
})

test_that("an absent packaged table names mysterycall, not an empty path", {
  # Without sf the function stops at its own requireNamespace guard, so the
  # expect_error() below would match the wrong error.
  skip_if_not_installed("sf")
  skip_if_not_installed("readr")
  # system.file() returns "" when the file is missing, and the generic message
  # then reads "Could not locate the ACOG districts file at ''" -- true, and
  # useless to whoever has to fix it.
  local_mocked_bindings(
    system.file = function(..., package = "base") {
      if (identical(package, "mysterycall")) "" else base::system.file(..., package = package)
    },
    .package = "base")

  expect_error(mysterymaps_map_acog_districts(),
               "packaged ACOG districts table")
  expect_error(mysterymaps_map_acog_districts(), "mysterycall")
})

test_that("a byte-order mark on the State header is repaired", {
  # Excel writes a BOM on every CSV it exports, and readr surfaces it as a
  # column whose name is not "State". The rename is what keeps such a file
  # usable instead of failing on a missing column.
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")

  dir <- withr::local_tempdir()
  path <- file.path(dir, "bom-name.csv")
  writeLines(c("..State,ACOG_District,Subregion",
               "Colorado,District VIII,Mountain"), path)

  out <- mysterymaps_map_acog_districts(path)
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 1L)
})

test_that("a table without ACOG_District is refused by name", {
  # Without sf the function stops at its own requireNamespace guard, so the
  # expect_error() below would match the wrong error.
  skip_if_not_installed("sf")
  skip_if_not_installed("readr")
  dir <- withr::local_tempdir()
  path <- file.path(dir, "no-district.csv")
  writeLines(c("State,Subregion", "Colorado,Mountain"), path)

  expect_error(mysterymaps_map_acog_districts(path),
               "must contain an 'ACOG_District' column")
})

test_that("Subregion is optional and falls back to the district name", {
  # dplyr::coalesce() cannot reach a column that is not there, so the fallback
  # only works because the column is materialised as NA first.
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
  skip_if_not_installed("rnaturalearthhires")

  dir <- withr::local_tempdir()
  path <- file.path(dir, "no-subregion.csv")
  writeLines(c("State,ACOG_District", "Colorado,District VIII"), path)

  out <- mysterymaps_map_acog_districts(path)
  expect_s3_class(out, "sf")
  expect_identical(out$Subregion, out$ACOG_District)
})

test_that("a failure inside ne_states names the off-CRAN package to install", {
  # rnaturalearthhires is not on CRAN, so this is the common failure for
  # anyone who installed rnaturalearth on its own. The message has to say so;
  # rnaturalearth's own error does not mention this function or the repo.
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")

  dir <- withr::local_tempdir()
  path <- file.path(dir, "ok.csv")
  writeLines(c("State,ACOG_District,Subregion",
               "Colorado,District VIII,Mountain"), path)

  local_mocked_bindings(
    ne_states = function(...) stop("no data available"),
    .package = "rnaturalearth")

  expect_error(mysterymaps_map_acog_districts(path), "rnaturalearthhires")
  expect_error(mysterymaps_map_acog_districts(path), "r-universe")
})
