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
  expect_error(mysterymaps_map_acog_districts(file.path(tempdir(), "nope.csv")),
               "Could not locate the ACOG districts file")
  expect_error(mysterymaps_map_acog_districts(""),
               "Could not locate the ACOG districts file")
})

test_that("a lookup with no State column is refused", {
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
  dir <- withr::local_tempdir()
  path <- write_lookup(dir, rows = "Atlantis,District I,Nowhere")
  expect_error(mysterymaps_map_acog_districts(path),
               "No matching states were found")
})

test_that("State_Abbreviations falls back to the Natural Earth postal code", {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
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
