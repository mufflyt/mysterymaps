# A deliberately nasty synthetic geography, loosely Colorado-shaped.
#
# Every pathology here is one that has actually reached a map: a county with no
# providers reading as missing, a self-intersecting ring that survives until an
# area calculation, a provider sitting exactly on a boundary being counted twice
# or not at all. The fixture exists so those cases are exercised on purpose
# rather than discovered in a published map.
#
# Everything is deterministic. No random generation, no network, no API key.
# Coordinates are EPSG:4326 in Colorado's bounding box (-109.06..-102.04,
# 37.0..41.0); nothing here is a real county boundary or a real provider.

co_bbox <- c(xmin = -109.06, ymin = 37.0, xmax = -102.04, ymax = 41.0)

# A closed rectangular ring, counter-clockwise.
co_ring <- function(xmin, ymin, xmax, ymax) {
  cbind(c(xmin, xmax, xmax, xmin, xmin), c(ymin, ymin, ymax, ymax, ymin))
}

co_rect <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(co_ring(xmin, ymin, xmax, ymax)))
}

#' Twelve synthetic counties on a 4x3 grid, plus two outside the study area.
#'
#' Column `rate` carries the pathologies that matter for shading: two zeroes,
#' which must stay their own colour class, and two NAs, which must stay unknown.
#' Geometry carries the pathologies that matter for area and overlap.
co_counties <- function() {
  skip_if_not_installed("sf")
  nx <- 4; ny <- 3
  w <- (co_bbox[["xmax"]] - co_bbox[["xmin"]]) / nx
  h <- (co_bbox[["ymax"]] - co_bbox[["ymin"]]) / ny

  cell <- function(i, j) {
    x0 <- co_bbox[["xmin"]] + (i - 1) * w
    y0 <- co_bbox[["ymin"]] + (j - 1) * h
    c(x0, y0, x0 + w, y0 + h)
  }

  geoms <- list()
  for (j in seq_len(ny)) for (i in seq_len(nx)) {
    b <- cell(i, j)
    geoms[[length(geoms) + 1]] <- co_rect(b[1], b[2], b[3], b[4])
  }

  # County 3 has a hole: a lake, or an inner county that was cut out. An area
  # computation that ignores the second ring overstates it.
  b <- cell(3, 1)
  geoms[[3]] <- sf::st_polygon(list(
    co_ring(b[1], b[2], b[3], b[4]),
    co_ring(b[1] + 0.4 * w, b[2] + 0.4 * h, b[1] + 0.6 * w, b[2] + 0.6 * h)
  ))

  # County 5 is two disjoint pieces. Code that keeps only the largest part
  # silently drops the smaller one and the county gets shaded on partial data.
  b <- cell(1, 2)
  geoms[[5]] <- sf::st_multipolygon(list(
    list(co_ring(b[1], b[2], b[1] + 0.6 * w, b[4])),
    list(co_ring(b[1] + 0.75 * w, b[2] + 0.1 * h, b[3], b[2] + 0.4 * h))
  ))

  # The bow tie is deliberately NOT here; see co_bowtie(). s2 refuses to build
  # a geography from any collection containing a self-crossing ring, so baking
  # one into the baseline makes every operation on the whole object error at
  # conversion -- which tests nothing except that s2 validates input.

  # Two counties outside the study area. Providers land in them, and coverage
  # must not be attributed to Colorado on their account.
  outside <- list(
    co_rect(co_bbox[["xmax"]], 37.5, co_bbox[["xmax"]] + 1, 38.5),
    co_rect(co_bbox[["xmin"]] - 1, 39.5, co_bbox[["xmin"]], 40.5)
  )

  n_in <- length(geoms)
  sf::st_sf(
    geoid    = sprintf("08%03d", seq_len(n_in + 2)),
    name     = c(paste("County", seq_len(n_in)), "Border East", "Border West"),
    in_study = c(rep(TRUE, n_in), FALSE, FALSE),
    # Zeroes at 1 and 2, NAs at 6 and 7. Zero is a real measured value; NA is
    # the absence of one. A map that renders them alike is wrong in a way
    # nobody notices, so both must survive every stage.
    rate     = c(0, 0, 12.5, 3.25, 41, NA, NA, 8, 19.75, 0.5, 62, 27, 5, 5),
    pop      = c(1200L, 0L, 45000L, 8800L, 130000L, 2400L, 0L,
                 15600L, 73000L, 640L, 210000L, 33000L, 9000L, 9000L),
    geometry = sf::st_sfc(c(geoms, outside), crs = 4326)
  )
}

#' A single self-crossing county, for repair tests.
#'
#' Kept out of co_counties() on purpose. Any s2 operation on a collection
#' holding this geometry fails while reading it -- "Loop 0 is not valid: Edge 0
#' crosses edge 2" -- so it must be handled alone, with s2 off, and repaired
#' before it joins anything else. That is also how it should be handled in the
#' package: repair at the boundary, not three stages downstream.
co_bowtie <- function() {
  skip_if_not_installed("sf")
  w <- (co_bbox[["xmax"]] - co_bbox[["xmin"]]) / 4
  h <- (co_bbox[["ymax"]] - co_bbox[["ymin"]]) / 3
  x0 <- co_bbox[["xmin"]] + 3 * w
  y0 <- co_bbox[["ymin"]] + h
  sf::st_sfc(sf::st_polygon(list(cbind(
    c(x0, x0 + w, x0, x0 + w, x0),
    c(y0, y0 + h, y0 + h, y0, y0)
  ))), crs = 4326)
}

#' Run an expression with s2 switched off, restoring the previous setting.
#'
#' Invalid input has to be inspected in planar mode; s2 will not read it.
co_without_s2 <- function(expr) {
  skip_if_not_installed("sf")
  old <- sf::sf_use_s2()
  suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(old)), add = TRUE)
  force(expr)
}

#' Providers, including every placement that has caused a miscount.
co_providers <- function() {
  skip_if_not_installed("sf")
  w <- (co_bbox[["xmax"]] - co_bbox[["xmin"]]) / 4
  boundary_x <- co_bbox[["xmin"]] + w   # exactly the county 1 / county 2 edge

  d <- data.frame(
    npi      = sprintf("1%09d", 1:10),
    medicaid = c(TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE),
    note     = c("interior", "interior", "duplicate of 2", "duplicate of 2",
                 "on a county boundary", "in the hole of county 3",
                 "outside the study area", "outside the study area",
                 "interior", "interior"),
    x = c(-108.5, -107.0, -107.0, -107.0, boundary_x, -105.4, -101.5,
          -109.5, -103.0, -104.2),
    y = c(37.4, 38.2, 38.2, 38.2, 37.6, 37.6, 38.0, 40.0, 39.1, 40.4),
    stringsAsFactors = FALSE
  )
  sf::st_as_sf(d, coords = c("x", "y"), crs = 4326)
}

#' The same providers with one empty geometry appended.
#'
#' Kept separate because an empty point is not merely another row: it makes
#' every predicate return NA, and most pipelines should reject it rather than
#' quietly carry it.
co_providers_with_empty <- function() {
  skip_if_not_installed("sf")
  p <- co_providers()
  empty <- p[1, ]
  empty$npi <- "1000000011"
  empty$note <- "empty geometry"
  sf::st_geometry(empty) <- sf::st_sfc(sf::st_point(), crs = 4326)
  rbind(p, empty)
}

#' Strictly nested drive-time bands: 30 within 60 within 120 within 180.
#'
#' Concentric rectangles rather than buffers, so nesting is exact and does not
#' depend on the s2 setting or on a projection choice.
co_bands <- function() {
  skip_if_not_installed("sf")
  cx <- -105.5; cy <- 39.0
  half <- c("30" = 0.5, "60" = 1.0, "120" = 1.75, "180" = 2.5)
  out <- lapply(half, function(r) {
    sf::st_sfc(co_rect(cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), crs = 4326)
  })
  names(out) <- paste0(names(half), " minutes")
  out
}
