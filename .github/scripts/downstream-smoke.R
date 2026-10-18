# =============================================================================
# Downstream-consumer smoke test
# =============================================================================
# mysterymaps_geographic_map() shipped for months missing a `labels` argument
# that mufflyt/midwifery's manuscript (Figures 3-4,
# manuscript/midwife_persistence.qmd) already called. This package's own test
# suite never called it that way -- every existing test used the default
# percent formatter -- so R-CMD-check, coverage, and Scientific Nightly all
# stayed green while the actual caller broke with "unused argument (labels =
# ...)". None of those suites can catch that class of bug: they test this
# package against itself, not against how a real project outside it calls in.
#
# This script runs the exact argument shapes lifted from real consumer code
# (not invented scenarios) against a fresh install of this package built from
# the commit under test -- see the workflow's `local::.` dependency, which is
# what makes that "the commit under test" rather than whatever the dependency
# cache happens to hold.
#
# ADD A SCENARIO HERE whenever a consumer's call breaks in a way this file did
# not anticipate. That is the failure this file exists to stop from recurring
# silently. Keep each scenario traceable to the real call site it was lifted
# from -- an invented scenario tests this package's idea of how it is used,
# which is exactly what already failed once.
#
# Extended below to cover the six map-template functions added for
# mufflyt/isochrones' Siff_Virginia/ deliverable: mysterymaps_pathway_small_
# multiples_map(), mysterymaps_catchment_redundancy_map() and
# mysterymaps_bivariate_choropleth_map() have a real call site there
# (build_new_map_types.R, usa_hex_bivariate_physicians_population.R) and the
# fixtures below reproduce its exact argument shapes with small synthetic sf
# objects, not that repository's real geocoded/ACS data. The other three --
# mysterymaps_cartogram_map(), mysterymaps_flow_map() and
# mysterymaps_rate_choropleth_map() -- have no real external caller yet, so
# their scenarios are lifted from this package's own @examplesIf documentation
# instead; that is exactly the "tests itself" gap this file exists to avoid,
# so swap each for a real call site the day one exists.

stopifnot(requireNamespace("mysterymaps", quietly = TRUE))
stopifnot(requireNamespace("ggplot2", quietly = TRUE))

# Fixture shaped like manuscript/midwife_persistence.qmd's `sw` object
# (artifacts/state_obstetric_workforce.csv): 50 states + DC, a per-1,000 rate
# that is NOT a [0, 1] proportion, and a percentage-point share. Synthetic
# values -- this script does not have access to that repository's real data,
# nor does it need it; only the shape of the call matters.
set.seed(1)
sw <- data.frame(
  state       = c(state.abb, "DC"),
  rate_per_1k = runif(51, 0.5, 11),
  share_pct   = runif(51, 5, 60)
)

scenarios <- list(
  list(
    source = "mufflyt/midwifery manuscript/midwife_persistence.qmd, Figure 3",
    call = function() mysterymaps::mysterymaps_geographic_map(
      data            = sw,
      state_col       = "state",
      outcome_col     = "rate_per_1k",
      fill_label      = "Midwives per\n1,000 births",
      palette         = "viridis",
      low_states_warn = 0L,
      # The scenario this file exists to catch: a rate per 1,000, not a
      # proportion on [0, 1]. The default percent formatter rendered this as
      # "1 000%" before `labels` existed.
      labels          = function(x) sprintf("%.0f", x))
  ),
  list(
    source = "mufflyt/midwifery manuscript/midwife_persistence.qmd, Figure 4",
    call = function() mysterymaps::mysterymaps_geographic_map(
      data            = sw,
      state_col       = "state",
      outcome_col     = "share_pct",
      fill_label      = "Midwife share of\nbirth attendants",
      palette         = "cividis",
      low_states_warn = 0L,
      labels          = function(x) paste0(sprintf("%.0f", x), "%"))
  ),

  # ---- Siff_Virginia/build_new_map_types.R and usa_hex_bivariate_physicians_
  # population.R: real call sites, synthetic data of the same shape. ----
  list(
    source = "mufflyt/isochrones Siff_Virginia/build_new_map_types.R (pathway small multiples)",
    call = function() {
      set.seed(3)
      va_counties_fx <- sf::st_sf(
        NAME = c("Fairfax", "Wise", "Covington"),
        geometry = sf::st_sfc(lapply(0:2, function(i) {
          x <- -78 + i
          sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(37, 37, 38, 38, 37))))
        }), crs = 4326)
      )
      phys_fx <- sf::st_sf(
        pathway = sample(c("OB/GYN (ABOG)", "Urology (ABU, net-new)"), 20,
                         replace = TRUE, prob = c(0.7, 0.3)),
        geometry = sf::st_sfc(lapply(1:20, function(i)
          sf::st_point(c(stats::runif(1, -78, -75), stats::runif(1, 37, 38)))), crs = 4326)
      )
      pathway_labels_fx <- c(
        "OB/GYN (ABOG)"          = "Obstetrics and Gynecology Certification Pathway",
        "Urology (ABU, net-new)" = "Urology Certification Pathway")
      mysterymaps::mysterymaps_pathway_small_multiples_map(
        phys_fx, va_counties_fx, pathway_var = "pathway",
        pathway_labels = pathway_labels_fx,
        palette = c(
          "Obstetrics and Gynecology Certification Pathway" = "#0072B2",
          "Urology Certification Pathway" = "#009E73"),
        include_combined_panel = TRUE, ncol = 3,
        title = "fixture", subtitle = "fixture",
        jitter_miles = 1.2)
    }
  ),
  list(
    source = "mufflyt/isochrones Siff_Virginia/build_new_map_types.R (catchment redundancy)",
    call = function() {
      va_counties_fx <- sf::st_sf(
        NAME = c("Fairfax", "Wise", "Covington"),
        geometry = sf::st_sfc(lapply(0:2, function(i) {
          x <- -78 + i
          sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(37, 37, 38, 38, 37))))
        }), crs = 4326)
      )
      iso30_fx <- sf::st_sf(
        physician_id = c("p1", "p2", "p3", "p4"),
        geometry = sf::st_sfc(lapply(1:4, function(i)
          sf::st_buffer(sf::st_point(c(-78 + i * 0.3, 37.5)), 0.4)), crs = 4326)
      )
      mysterymaps::mysterymaps_catchment_redundancy_map(
        iso30_fx, va_counties_fx, provider_id_var = "physician_id", grid_spacing_miles = 4,
        title = "fixture", subtitle = "fixture") +
        mysterymaps::mysterymaps_scale_bar()
    }
  ),
  list(
    source = "mufflyt/isochrones Siff_Virginia/usa_hex_bivariate_physicians_population.R",
    call = function() {
      hexes_fx <- sf::st_sf(
        denominator = c(100, 500, 1200, 50, 900, 3000, 20, 600, 1500),
        count       = c(1, 3, 0, 0, 5, 8, 0, 2, 6),
        geometry = sf::st_sfc(lapply(0:8, function(i) {
          x <- -100 + (i %% 3); y <- 35 + (i %/% 3)
          sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(y, y, y + 1, y + 1, y))))
        }), crs = 4326)
      )
      mysterymaps::mysterymaps_bivariate_choropleth_map(
        hexes_fx, x_var = "denominator", y_var = "count",
        x_label = "fixture", y_label = "fixture", title = "fixture",
        crs = 5070, n_classes = 3) +
        mysterymaps::mysterymaps_scale_bar()
    }
  ),

  # ---- No real external caller yet for these three -- lifted from this
  # package's own @examplesIf documentation instead of a consumer call site. ----
  list(
    source = "mysterymaps_cartogram_map() @examplesIf (no external caller yet)",
    call = function() {
      counties <- sf::st_sf(
        id = 1:4, hub_lon = -97.5, hub_lat = 40.5,
        time_min = c(10, 20, 30, 60), straight_miles = c(9.6, 19.2, 28.8, 57.6),
        geometry = sf::st_sfc(lapply(1:4, function(i) {
          x <- -100 + i
          sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
        }), crs = 4326)
      )
      mysterymaps::mysterymaps_cartogram_map(
        counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
        time_var = "time_min", straight_distance_var = "straight_miles")
    }
  ),
  list(
    source = "mysterymaps_flow_map() @examplesIf (no external caller yet)",
    call = function() {
      routes <- sf::st_sf(
        trip = c("a", "b"), minutes = c(12, 45),
        geometry = sf::st_sfc(
          sf::st_linestring(rbind(c(-99, 40), c(-98, 40.5))),
          sf::st_linestring(rbind(c(-98, 41), c(-97, 41.2))),
          crs = 4326))
      basemap <- sf::st_sf(geometry = sf::st_sfc(
        sf::st_polygon(list(cbind(c(-100, -96, -96, -100, -100), c(39, 39, 43, 43, 39)))),
        crs = 4326))
      mysterymaps::mysterymaps_flow_map(routes, basemap, time_var = "minutes")
    }
  ),
  list(
    source = "mysterymaps_rate_choropleth_map() @examplesIf (no external caller yet)",
    call = function() {
      counties <- sf::st_sf(
        n_providers = c(1, 2, 0, 4), population = c(10000, 100000, 50000, 200000),
        geometry = sf::st_sfc(lapply(1:4, function(i) {
          x <- -100 + i
          sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
        }), crs = 4326)
      )
      mysterymaps::mysterymaps_rate_choropleth_map(
        counties, numerator_var = "n_providers", denominator_var = "population",
        numerator_label = "Urogynecologists", denominator_label = "Women Age 40 and Older")
    }
  )
)

failures <- character(0)
for (s in scenarios) {
  cat(sprintf("--- %s ---\n", s$source))
  ok <- tryCatch({
    p <- s$call()
    if (!inherits(p, "ggplot")) stop("did not return a ggplot object")
    # print() is where coord_map() resolves mapproj. The manuscript comment
    # that found this the hard way calls print() "load-bearing" for the same
    # reason: a builder can return happily and fail only once someone prints
    # or ggsaves it.
    grDevices::pdf(NULL)
    print(p)
    grDevices::dev.off()
    TRUE
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    FALSE
  })
  if (!ok) failures <- c(failures, s$source)
}

if (length(failures)) {
  stop(sprintf(
    "%d downstream-consumer scenario(s) failed:\n%s",
    length(failures),
    paste("  -", failures, collapse = "\n")
  ), call. = FALSE)
}

cat(sprintf("All %d downstream-consumer scenario(s) passed.\n", length(scenarios)))
