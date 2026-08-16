# Build the frozen Colorado E2SFCA validation fixture.
#
# WHY THIS EXISTS
#
# Every test in this package so far asks whether the machinery is trustworthy.
# None asks whether the answer is true. This fixture is the input to that
# question: one real study area, frozen, so that the accessibility surface
# `twostep` computes can be compared against a reference implementation written
# independently of it. A second call through the same internals proves only
# that the code is deterministic.
#
# WHAT IS FROZEN, AND WHY IT MATTERS THAT IT IS
#
# The isochrones are read from an artifact that already exists and is dated
# 2026-02-14. They are NOT regenerated: a HERE routing call is billed, is not
# reproducible, and would silently change the study area between runs. Census
# geography and population are pulled once and written to disk. Every input and
# output is hashed into MANIFEST.tsv, so a later comparison can state which
# bytes it validated rather than which script it ran.
#
# WHERE THE DATA GOES, AND WHY NOT HERE
#
# The fixture carries real provider coordinates and NPIs. That is public NPPES
# data, but a public git repository is a different kind of publication from a
# federal lookup, and one study's provider locations do not belong inside a
# general-purpose mapping package. This script is committed; its output is not.
# Point MM_CO_FIXTURE_DIR somewhere else to relocate it.
#
# Usage:
#   Rscript data-raw/build-colorado-fixture.R
#
# Requires CENSUS_API_KEY in ~/.Renviron. Requires no HERE key: see above.

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})

# ---------------------------------------------------------------------------
# Configuration -- every choice that would change the numbers
# ---------------------------------------------------------------------------

FIXTURE_DIR <- Sys.getenv("MM_CO_FIXTURE_DIR",
                          path.expand("~/co-validation-fixture"))

# The bands the study uses. twostep weights them 30 -> 1.00, 60 -> 0.68.
BANDS <- c(30L, 60L)

ISO_SOURCE <- setNames(
  path.expand(sprintf("~/isochrones/output/isochrones_%dmin_2026-02-14.rds",
                      BANDS)),
  as.character(BANDS))

# Not exported by twostep, so it is reached with ::: and pinned here rather
# than retyped. Retyping it would let the fixture and the implementation
# disagree about the decay without either one being wrong on its own.
BAND_WEIGHTS <- twostep:::E2SFCA_DEFAULT_WEIGHTS[as.character(BANDS)]
stopifnot(!anyNA(BAND_WEIGHTS), identical(names(BAND_WEIGHTS),
                                          as.character(BANDS)))

STATE <- "CO"
STATE_FIPS <- "08"

# Cache tigris downloads, but say WHERE. ~/.Renviron sets TIGRIS_CACHE_DIR to
# the relative path "data/tigris/", so enabling the cache without overriding it
# writes shapefiles into whatever directory the script was run from. In an R
# package that directory is `data/` -- the package dataset directory -- and
# `R CMD check` would then try to load census shapefiles as package data. An
# absolute path is set here so the cache cannot follow the working directory.
TIGRIS_CACHE <- Sys.getenv("MM_TIGRIS_CACHE",
                           path.expand("~/.cache/tigris"))
dir.create(TIGRIS_CACHE, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(TIGRIS_CACHE_DIR = TIGRIS_CACHE)
options(tigris_use_cache = TRUE)
if (!startsWith(Sys.getenv("TIGRIS_CACHE_DIR"), "/")) {
  stop("TIGRIS_CACHE_DIR is still relative (", Sys.getenv("TIGRIS_CACHE_DIR"),
       "); refusing to run and scatter shapefiles into the working directory.",
       call. = FALSE)
}

# mufflyaccess::acs_year_of() clamps to [2013, 2022] and
# mufflyaccess::tract_vintage_of() maps >= 2020 to the 2020 tract definitions.
# Both are read here rather than hard-coded so the fixture cannot drift from
# the convention the rest of the ecosystem uses.
ACS_YEAR <- mufflyaccess::acs_year_of(2022L)
TRACT_VINTAGE <- mufflyaccess::tract_vintage_of(ACS_YEAR)

# B01001_026 is total female population. twostep's compute_e2sfca() defaults to
# pop_col = "female_pop"; this is the variable behind that name.
POP_VAR <- mufflyaccess::TOTAL_FEMALE_VAR

# Planar geometry throughout. Every area calculation happens in EPSG:5070,
# where s2 does not apply, and st_intersects on a projected CRS is planar
# regardless -- but the setting is pinned and restored so the fixture cannot
# depend on what the session had.
old_s2 <- sf::sf_use_s2()
on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
suppressMessages(sf::sf_use_s2(FALSE))

dir.create(FIXTURE_DIR, recursive = TRUE, showWarnings = FALSE)
say <- function(...) message(sprintf(...))

# ---------------------------------------------------------------------------
# Provenance: hash the inputs before reading them
# ---------------------------------------------------------------------------
#
# A fixture that cannot name its sources is not frozen, it is merely old.

# No fallback. A hash function that quietly returns a different algorithm than
# its name claims is worse than no hash at all: the manifest would still look
# authoritative.
if (!requireNamespace("digest", quietly = TRUE)) {
  stop("`digest` is required to hash the fixture. install.packages('digest')",
       call. = FALSE)
}
sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  digest::digest(file = path, algo = "sha256")
}

provenance <- tibble::tibble(
  role = paste0("isochrones_", names(ISO_SOURCE), "min"),
  path = unname(ISO_SOURCE),
  sha256 = vapply(unname(ISO_SOURCE), sha256, character(1)),
  bytes = vapply(unname(ISO_SOURCE), function(p)
    if (file.exists(p)) file.size(p) else NA_real_, numeric(1))
)
stopifnot(all(file.exists(ISO_SOURCE)))

# ---------------------------------------------------------------------------
# 1. Study area
# ---------------------------------------------------------------------------

say("[1/6] Colorado boundary (tigris cb, %d)", TRACT_VINTAGE)
co <- tigris::states(cb = TRUE, year = 2023, progress_bar = FALSE) |>
  dplyr::filter(STUSPS == STATE) |>
  sf::st_transform(4326)

# ---------------------------------------------------------------------------
# 2. Isochrones reaching Colorado
# ---------------------------------------------------------------------------
#
# Selected by INTERSECTION with the state, not by the provider's own
# coordinates. A provider in Cheyenne whose 60-minute surface covers northern
# Larimer County supplies Colorado, and dropping them would manufacture a
# border desert -- the same artifact the water-mask guard exists to prevent at
# the other end of the pipeline. It happens that no out-of-state provider
# qualifies in this cohort, which is a finding about the cohort rather than a
# reason not to ask.

say("[2/6] isochrones reaching %s", STATE)
iso <- lapply(names(ISO_SOURCE), function(b) {
  x <- readRDS(ISO_SOURCE[[b]])
  stopifnot(inherits(x, "sf"), all(x$status == "success"))
  x <- x[lengths(sf::st_intersects(x, co)) > 0L, , drop = FALSE]
  x$drive_time_minutes <- as.integer(b)
  x
}) |> dplyr::bind_rows() |> sf::st_as_sf()

iso <- iso[, c("coord_id", "drive_time_minutes", "lat", "lon", "example_npi",
               "subspecialties", "n_physicians", "geometry")]
iso$coord_id <- as.character(iso$coord_id)

say("      %d isochrones, %d locations, %d physicians",
    nrow(iso), dplyr::n_distinct(iso$coord_id),
    sum(iso$n_physicians[iso$drive_time_minutes == min(BANDS)]))

# The 30-minute surface must lie inside the 60-minute surface for the same
# provider. If it does not, the bands came from different runs and every
# incremental-ring weight below is being applied to the wrong geometry.
nesting <- lapply(unique(iso$coord_id), function(id) {
  a <- sf::st_geometry(iso[iso$coord_id == id & iso$drive_time_minutes == 30L, ])
  b <- sf::st_geometry(iso[iso$coord_id == id & iso$drive_time_minutes == 60L, ])
  if (!length(a) || !length(b)) {
    return(tibble::tibble(coord_id = id, area_30_km2 = NA_real_,
                          area_60_km2 = NA_real_, outside_frac = NA_real_))
  }
  a5 <- sf::st_make_valid(sf::st_transform(a, 5070))
  b5 <- sf::st_make_valid(sf::st_transform(b, 5070))
  a_area <- as.numeric(sum(sf::st_area(a5)))
  outside <- as.numeric(sum(sf::st_area(sf::st_difference(a5, b5))))
  tibble::tibble(coord_id = id,
                 area_30_km2 = a_area / 1e6,
                 area_60_km2 = as.numeric(sum(sf::st_area(b5))) / 1e6,
                 outside_frac = if (a_area > 0) outside / a_area else NA_real_)
}) |> dplyr::bind_rows() |> dplyr::arrange(dplyr::desc(outside_frac))

# Areas in EPSG:5070 rather than st_area()/1e6 on lon/lat, for the reason
# mysterymaps learned the hard way: the divisor is only correct for a CRS whose
# linear unit is the metre, and a projected CRS is not automatically that.
BAND_NESTING_TOL <- 0.01
nest_bad <- nesting[!is.na(nesting$outside_frac) &
                      nesting$outside_frac > BAND_NESTING_TOL, ]
say("      band nesting (30 within 60): %d ok, %d violated (> %.0f%%), %d unpaired",
    sum(nesting$outside_frac <= BAND_NESTING_TOL, na.rm = TRUE),
    nrow(nest_bad), BAND_NESTING_TOL * 100, sum(is.na(nesting$outside_frac)))
if (nrow(nest_bad)) {
  say("      worst: %s",
      paste(sprintf("coord %s (%.1f%% of its 30-min surface outside its 60-min)",
                    nest_bad$coord_id, 100 * nest_bad$outside_frac),
            collapse = "; "))
}

# ---------------------------------------------------------------------------
# 3. Supply
# ---------------------------------------------------------------------------
#
# One row per provider LOCATION, not per provider. n_physicians is the count
# that geocoded to that coordinate; the artifact already collapsed them, which
# is why a coordinate can carry three subspecialties.

say("[3/6] supply")
supply <- iso |>
  sf::st_drop_geometry() |>
  dplyr::filter(drive_time_minutes == min(BANDS)) |>
  dplyr::transmute(coord_id, supply = as.numeric(n_physicians),
                   lat, lon, example_npi, subspecialties)
stopifnot(!anyDuplicated(supply$coord_id), all(supply$supply > 0))

# ---------------------------------------------------------------------------
# 4. Population denominator
# ---------------------------------------------------------------------------

say("[4/6] ACS %d tracts + %s (female population)", ACS_YEAR, POP_VAR)
tracts <- tidycensus::get_acs(
  geography = "tract", variables = POP_VAR, state = STATE,
  year = ACS_YEAR, geometry = TRUE, progress_bar = FALSE) |>
  sf::st_transform(4326) |>
  dplyr::transmute(GEOID = as.character(GEOID),
                   female_pop = estimate,
                   female_pop_moe = moe)

say("      %d tracts, %s women, %d tracts with NA population",
    nrow(tracts), format(sum(tracts$female_pop, na.rm = TRUE), big.mark = ","),
    sum(is.na(tracts$female_pop)))

# NA is not zero. compute_e2sfca() coerces a missing denominator to 0, which
# makes an unmeasured tract demand nothing and therefore inflates every
# provider ratio that reaches it. Recorded here so the comparison can ask
# whether that coercion changed the map rather than discovering it later.
na_pop_geoids <- tracts$GEOID[is.na(tracts$female_pop)]

# ---------------------------------------------------------------------------
# 5. Overlap and the package's own answer
# ---------------------------------------------------------------------------

say("[5/6] band x tract overlap (EPSG:5070)")
overlap <- twostep::compute_band_tract_overlap(
  iso_sf = iso, tracts_sf = tracts, verbose = FALSE)

say("      %d overlap rows, %d tracts touched by any band",
    nrow(overlap), dplyr::n_distinct(overlap$GEOID))

say("      running twostep::compute_e2sfca()")
e2sfca <- twostep::compute_e2sfca(
  overlap = overlap,
  tract_pop = sf::st_drop_geometry(tracts),
  supply = supply[, c("coord_id", "supply")],
  weights = BAND_WEIGHTS)

say("      access: %d tracts, %d with access > 0, %d providers with zero demand",
    nrow(e2sfca$access), sum(e2sfca$access$access > 0),
    e2sfca$audit$n_zero_demand_origins)

# ---------------------------------------------------------------------------
# 6. Freeze
# ---------------------------------------------------------------------------

say("[6/6] writing to %s", FIXTURE_DIR)
artifacts <- list(
  isochrones = iso,
  band_nesting = nesting,
  supply = supply,
  tracts = tracts,
  overlap = overlap,
  e2sfca_twostep = e2sfca,
  study_area = co
)
for (nm in names(artifacts)) {
  saveRDS(artifacts[[nm]], file.path(FIXTURE_DIR, paste0(nm, ".rds")),
          version = 3, compress = "xz")
}

meta <- list(
  built_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  state = STATE, state_fips = STATE_FIPS,
  bands = BANDS,
  band_weights = as.list(BAND_WEIGHTS),
  acs_year = ACS_YEAR, tract_vintage = TRACT_VINTAGE, pop_var = POP_VAR,
  area_crs = 5070L,
  n_locations = nrow(supply), n_physicians = sum(supply$supply),
  n_tracts = nrow(tracts),
  n_tracts_na_pop = length(na_pop_geoids),
  tracts_na_pop = na_pop_geoids,
  n_overlap_rows = nrow(overlap),
  band_nesting_tol = BAND_NESTING_TOL,
  n_band_nesting_violations = nrow(nest_bad),
  band_nesting_violations = as.list(nest_bad$coord_id),
  sf_use_s2_during_build = FALSE,
  package_versions = lapply(
    c("sf", "twostep", "mufflyaccess", "tidycensus", "tigris", "dplyr"),
    function(p) as.character(utils::packageVersion(p)))
)
names(meta$package_versions) <- c("sf", "twostep", "mufflyaccess",
                                  "tidycensus", "tigris", "dplyr")
jsonlite::write_json(meta, file.path(FIXTURE_DIR, "meta.json"),
                     auto_unbox = TRUE, pretty = TRUE)

built <- list.files(FIXTURE_DIR, pattern = "\\.(rds|json)$", full.names = TRUE)
manifest <- dplyr::bind_rows(
  dplyr::mutate(provenance, kind = "source"),
  tibble::tibble(role = tools::file_path_sans_ext(basename(built)),
                 path = built,
                 sha256 = vapply(built, sha256, character(1)),
                 bytes = file.size(built),
                 kind = "artifact")
)
utils::write.table(manifest, file.path(FIXTURE_DIR, "MANIFEST.tsv"),
                   sep = "\t", row.names = FALSE, quote = FALSE)

say("done. %d artifacts, %s", nrow(manifest),
    format(structure(sum(manifest$bytes, na.rm = TRUE), class = "object_size"),
           units = "auto"))
