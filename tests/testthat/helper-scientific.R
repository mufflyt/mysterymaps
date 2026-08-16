# Fixtures and generators for the scientific validation suite.
#
# The suite these support is not trying to show that mysterymaps works. It is
# trying to make mysterymaps produce a believable but scientifically false map,
# and to fail when it succeeds. Everything here exists to build inputs that look
# fine and are not.

# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

# Property-based tests need randomness that a failure can be replayed from. The
# seed is printed on failure and belongs in the regression corpus afterwards.
mm_with_seed <- function(seed, code) {
  old <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  set.seed(seed)
  on.exit({
    if (is.null(old)) {
      suppressWarnings(rm(".Random.seed", envir = .GlobalEnv))
    } else {
      assign(".Random.seed", old, envir = .GlobalEnv)
    }
  }, add = TRUE)
  force(code)
}

# How many cases a property runs. One value locally, a much larger one in the
# deep audit, so the same test file serves both tiers.
mm_property_n <- function(default = 25L) {
  n <- suppressWarnings(as.integer(Sys.getenv("MYSTERYMAPS_PROPERTY_N", "")))
  if (is.na(n) || n < 1L) default else n
}

# Report the seed with the failure, so a nightly counterexample is reproducible
# rather than a story about one.
mm_for_each_seed <- function(n, f) {
  seeds <- seq_len(n) * 7919L
  for (s in seeds) {
    withCallingHandlers(
      mm_with_seed(s, f(s)),
      error = function(e) {
        message(sprintf("PROPERTY FAILED at seed %d", s))
      }
    )
  }
  invisible(seeds)
}

# ---------------------------------------------------------------------------
# Geometry generators
# ---------------------------------------------------------------------------

mm_rect <- function(xmin, ymin, xmax, ymax, crs = 4326) {
  sf::st_sfc(
    sf::st_polygon(list(cbind(c(xmin, xmax, xmax, xmin, xmin),
                              c(ymin, ymin, ymax, ymax, ymin)))),
    crs = crs)
}

# A random axis-aligned rectangle inside CONUS-ish bounds.
mm_random_rect <- function(crs = 4326) {
  x <- stats::runif(1, -120, -75)
  y <- stats::runif(1, 26, 48)
  w <- stats::runif(1, 0.2, 3)
  h <- stats::runif(1, 0.2, 3)
  mm_rect(x, y, x + w, y + h, crs = crs)
}

# The pathological geometry corpus. Each entry is a named list with the
# geometry and what the package is REQUIRED to do with it: "repair" (fix and
# proceed), "reject" (fail closed with an informative error), or "accept".
mm_bad_geometries <- function() {
  list(
    bowtie = list(
      why = "self-intersecting ring; what routing APIs return",
      contract = "repair",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 2, 0, 2, 0), c(0, 0, 2, 2, 0)))),
        crs = 4326)),

    duplicate_vertices = list(
      why = "repeated vertex; harmless but trips some predicates",
      contract = "accept",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 1, 1, 1, 0, 0), c(0, 0, 0, 1, 1, 0)))),
        crs = 4326)),

    reversed_ring = list(
      why = "clockwise exterior ring instead of counter-clockwise",
      contract = "accept",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)))),
        crs = 4326)),

    with_hole = list(
      why = "a polygon with an interior ring; area must exclude the hole",
      contract = "accept",
      geom = sf::st_sfc(
        sf::st_polygon(list(
          cbind(c(0, 4, 4, 0, 0), c(0, 0, 4, 4, 0)),
          cbind(c(1, 1, 2, 2, 1), c(1, 2, 2, 1, 1)))),
        crs = 4326)),

    multipolygon = list(
      why = "a multipart state, e.g. Michigan or an island chain",
      contract = "accept",
      geom = sf::st_sfc(
        sf::st_multipolygon(list(
          list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0))),
          list(cbind(c(3, 4, 4, 3, 3), c(0, 0, 1, 1, 0))))),
        crs = 4326)),

    sliver = list(
      why = "near-zero-width polygon from a boundary difference",
      contract = "accept",
      geom = mm_rect(0, 0, 1, 1e-9)),

    zero_area = list(
      why = "collapsed polygon; area is exactly zero",
      contract = "reject",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 0, 0, 0)))),
        crs = 4326)),

    empty = list(
      why = "an empty geometry; a row that carries no place",
      contract = "reject",
      geom = sf::st_sfc(sf::st_polygon(), crs = 4326)),

    no_crs = list(
      why = "missing CRS; degrees and metres become indistinguishable",
      contract = "reject",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0)))))),

    unrepairable = list(
      why = "a ring with too few distinct points to be a polygon at all",
      contract = "reject",
      geom = sf::st_sfc(
        sf::st_polygon(list(cbind(c(0, 0, 0, 0), c(0, 0, 0, 0)))),
        crs = 4326))
  )
}

# ---------------------------------------------------------------------------
# The four states a geography can be in
# ---------------------------------------------------------------------------
#
# The single most dangerous transformation in this package is the one that maps
# all four of these to the number 0. They are scientifically distinct and the
# map must keep them distinct.
#
#   observed_zero        the place was measured and has no providers
#   source_missing       the provider source does not cover this place
#   geography_missing    providers exist but could not be placed
#   unresolved           provider identity was never resolved
mm_four_states <- function() {
  cty <- mm_counties(4)
  cty$state_label <- c("observed_zero", "source_missing",
                       "geography_missing", "unresolved")
  cty$rate <- c(0, NA_real_, NA_real_, NA_real_)
  cty$evidence <- c("measured", "no_source", "ungeocoded", "ambiguous")
  cty
}

# ---------------------------------------------------------------------------
# Perturbation helpers used by the metamorphic tests
# ---------------------------------------------------------------------------

# Shuffle rows. Scientific output must not notice.
mm_shuffle_rows <- function(x) x[sample.int(nrow(x)), , drop = FALSE]

# Add columns nothing reads. Scientific output must not notice.
mm_add_noise_cols <- function(x, n = 12L) {
  for (i in seq_len(n)) {
    x[[paste0("noise_", i)]] <- sample(c(letters, NA), nrow(x), replace = TRUE)
  }
  x
}

# Rename the identifier columns to arbitrary tokens, preserving relationships.
mm_rename_ids <- function(x, col = "GEOID") {
  if (!col %in% names(x)) return(x)
  u <- unique(x[[col]])
  map <- stats::setNames(paste0("tok", seq_along(u)), u)
  x[[col]] <- unname(map[x[[col]]])
  x
}

# ---------------------------------------------------------------------------
# Numerical tolerance
# ---------------------------------------------------------------------------
#
# Stated once, with a reason, rather than scattered all.equal() defaults. Areas
# are compared in square metres after projection to EPSG:5070; 1e-6 relative is
# far below any difference that could change a map class, and far above the
# floating-point noise of a reprojection round trip.
MM_AREA_TOL <- 1e-6
MM_COORD_TOL <- 1e-9
