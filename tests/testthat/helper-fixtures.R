# Shared fixtures.
#
# Every builder here makes the smallest object that still exercises the thing
# under test. Small on purpose: an sf fixture with 3,000 counties makes the
# suite slow and tells you nothing a 4-county one does not.

# A square polygon in WGS84, sized and placed by its lower-left corner.
mm_square <- function(x = -100, y = 40, w = 1, h = w, crs = 4326) {
  sf::st_sfc(
    sf::st_polygon(list(cbind(
      c(x, x + w, x + w, x, x),
      c(y, y, y + h, y + h, y)
    ))),
    crs = crs
  )
}

# n counties in a west-to-east row, carrying the columns the map template wants.
mm_counties <- function(n = 6,
                        rate = c(0, 0, 1.5, 3, 8, 20),
                        crs = 4326) {
  skip_if_not_installed("sf")
  polys <- lapply(seq_len(n), function(i) {
    x <- -100 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(40, 40, 41, 41, 40))))
  })
  sf::st_sf(
    GEOID    = sprintf("080%02d", seq_len(n)),
    NAMELSAD = paste("County", seq_len(n)),
    rate     = rep_len(rate, n),
    tooltip  = paste0("<b>County ", seq_len(n), "</b>"),
    profile  = paste0("County ", seq_len(n), " profile."),
    geometry = sf::st_sfc(polys, crs = crs)
  )
}

# Provider points, placed inside the county row by default.
#
# The default latitudes are deliberately NOT all equal: a collinear point set
# has ymin == ymax, which validate_sf_inputs() rejects as a degenerate bounding
# box. That rejection is correct and is pinned by its own test; it should not
# be the accidental behaviour of every fixture in the suite.
mm_points <- function(n = 3, lon = NULL, lat = NULL, crs = 4326) {
  skip_if_not_installed("sf")
  if (is.null(lon)) lon <- -99.5 + seq_len(n) - 1
  if (is.null(lat)) lat <- 40.2 + (seq_len(n) - 1) * 0.2
  sf::st_as_sf(
    data.frame(
      name  = paste("Provider", seq_len(n)),
      state = rep_len(c("CO", "KS"), n),
      popup = paste0("<b>Provider ", seq_len(n), "</b>"),
      lon   = lon,
      lat   = lat
    ),
    coords = c("lon", "lat"), crs = crs
  )
}

# A dissolved coverage band: one polygon covering the whole county row.
mm_surface <- function(x = -99.5, y = 40, w = 4, h = 1, crs = 4326) {
  skip_if_not_installed("sf")
  sf::st_sf(band = "30 minutes", geometry = mm_square(x, y, w, h, crs))
}

# Block groups carrying the columns mysterymaps_calculate_overlap() requires.
mm_block_groups <- function(n = 4, vintage = 2020) {
  skip_if_not_installed("sf")
  polys <- lapply(seq_len(n), function(i) {
    x <- -100 + (i - 1) * 0.5
    sf::st_polygon(list(cbind(c(x, x + 0.5, x + 0.5, x, x),
                              c(40, 40, 40.5, 40.5, 40))))
  })
  sf::st_sf(
    GEOID    = sprintf("0800100%02d", seq_len(n)),
    NAMELSAD = paste("Block Group", seq_len(n)),
    vintage  = vintage,
    geometry = sf::st_sfc(polys, crs = 4326)
  )
}

# Isochrones in the shape mysterymaps_calculate_overlap() expects: a
# `drive_time` column in minutes and a `data_year` provider vintage.
mm_isochrones <- function(drive_time = c(30, 60), data_year = 2020) {
  skip_if_not_installed("sf")
  geoms <- lapply(seq_along(drive_time), function(i) {
    sf::st_polygon(list(cbind(
      c(-100, -100 + 0.6 * i, -100 + 0.6 * i, -100, -100),
      c(40, 40, 40.4, 40.4, 40)
    )))
  })
  sf::st_sf(
    drive_time = drive_time,
    data_year  = data_year,
    geometry   = sf::st_sfc(geoms, crs = 4326)
  )
}

# The method names leaflet recorded on a widget, in call order. Nearly every
# leaflet assertion in this suite starts here.
mm_calls <- function(map) {
  vapply(map$x$calls, function(cl) cl$method, character(1))
}

# The arguments of the i-th call to `method`.
mm_call_args <- function(map, method, i = 1L) {
  hits <- Filter(function(cl) identical(cl$method, method), map$x$calls)
  if (length(hits) < i) return(NULL)
  hits[[i]]$args
}

# Every JS payload attached with htmlwidgets::onRender(), concatenated. The
# zoom-gating and legend-switching behaviour lives in these strings, so this is
# how it gets asserted on.
mm_onrender_js <- function(map) {
  jsh <- map$jsHooks$render
  if (is.null(jsh)) return("")
  paste(vapply(jsh, function(h) as.character(h$code), character(1)),
        collapse = "\n")
}

# Run an expression with a temporary working directory that is cleaned up.
mm_in_tempdir <- function(code) {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  force(code)
}

# The default ACOG district table ships inside mysterycall's inst/extdata.
# mysterymaps_map_acog_districts() falls back to it when no file is given, and
# anything that draws districts -- mysterymaps_map_physicians() among them --
# reaches it. It is present in a developer install and absent on a CI runner
# that resolved mysterycall differently, so tests that rely on it skip rather
# than fail.
skip_if_no_acog_csv <- function() {
  p <- system.file("extdata", "acog_districts.csv", package = "mysterycall")
  if (!nzchar(p) || !file.exists(p)) {
    skip("mysterycall's packaged acog_districts.csv is not available")
  }
}
