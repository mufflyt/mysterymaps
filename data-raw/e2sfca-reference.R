# An independent E2SFCA reference implementation, and the comparison.
#
# WHAT "INDEPENDENT" MEANS HERE, AND WHAT IT DOES NOT
#
# This file calls no twostep function. It implements Enhanced Two-Step Floating
# Catchment Area from the published method (Luo & Qi 2009, Health & Place 15:
# 1100-1107) using sf and base R, and reads only the frozen fixture.
#
# It is not independent in the strongest sense: the same person wrote it, and
# `twostep::compute_e2sfca()` had already been read in order to build the
# fixture at all. So a shared misreading of the method would survive both. What
# it does establish is that two different ROUTES to the number agree -- and
# where they disagree, the disagreement is the finding. Every place this
# implementation makes a choice the paper leaves open is marked DECISION, so a
# difference can be attributed to a choice rather than to a bug.
#
# THE ONE DELIBERATE DIVERGENCE
#
# E2SFCA weights discrete travel-time ZONES: the 0-30 ring at 1.00, the 30-60
# ring at 0.68. Our isochrones are CUMULATIVE -- the 60-minute polygon already
# contains the 30-minute one -- so twostep recovers ring weights algebraically,
# applying w_inc = c(30 = 1.00 - 0.68, 60 = 0.68) = c(0.32, 0.68) to cumulative
# overlaps. Area inside both bands then collects 0.32 + 0.68 = 1.00 and area in
# the 60 alone collects 0.68, which is exactly right.
#
# It is exactly right ONLY IF the 30-minute polygon lies inside the 60-minute
# one. Area inside the 30 but outside the 60 collects 0.32 alone, when the
# method says 1.00 -- under-weighted 3.1x. The fixture has three such locations.
#
# This reference therefore builds the rings GEOMETRICALLY: ring_60 is the
# difference iso_60 \ iso_30, and each ring carries its own weight directly.
# That is the method as written, it needs no nesting assumption, and the gap
# between the two routes is a measurement of what the assumption costs.
#
# Usage:
#   Rscript data-raw/e2sfca-reference.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})

FIXTURE_DIR <- Sys.getenv("MM_CO_FIXTURE_DIR",
                          path.expand("~/co-validation-fixture"))
AREA_CRS <- 5070L
PER_CAPITA_SCALE <- 1e5

old_s2 <- sf::sf_use_s2()
on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
suppressMessages(sf::sf_use_s2(FALSE))

say <- function(...) message(sprintf(...))

# ---------------------------------------------------------------------------
# The reference implementation
# ---------------------------------------------------------------------------

#' E2SFCA from the published method, with geometric rings.
#'
#' @param iso sf with coord_id, drive_time_minutes, geometry (cumulative bands)
#' @param supply data.frame with coord_id, supply
#' @param tracts sf with GEOID and a population column
#' @param weights named numeric, cumulative band weights e.g. c(`30`=1, `60`=.68)
#' @param pop_col population column in `tracts`
#' @param zero_demand what to do with a provider no population can reach:
#'   "exclude" drops their supply from the surface, "keep" is not defined by the
#'   method and errors. See DECISION 3.
e2sfca_reference <- function(iso, supply, tracts, weights,
                             pop_col = "female_pop",
                             area_crs = AREA_CRS,
                             per_capita_scale = PER_CAPITA_SCALE,
                             zero_demand = c("exclude", "error")) {
  zero_demand <- match.arg(zero_demand)
  stopifnot(all(c("coord_id", "drive_time_minutes") %in% names(iso)),
            all(c("coord_id", "supply") %in% names(supply)),
            "GEOID" %in% names(tracts), pop_col %in% names(tracts))

  bands <- sort(as.integer(names(weights)))
  stopifnot(setequal(bands, sort(unique(as.integer(iso$drive_time_minutes)))))

  iso <- sf::st_make_valid(sf::st_transform(iso, area_crs))
  iso$coord_id <- as.character(iso$coord_id)
  tr <- sf::st_make_valid(sf::st_transform(tracts, area_crs))
  tr$GEOID <- as.character(tr$GEOID)

  # DECISION 1: the denominator of overlap_fraction is the tract's own area in
  # the equal-area CRS, so a fraction is a share of the tract and the weighted
  # sum below is a headcount. Using the isochrone's area instead would answer a
  # different question (what share of the catchment is this tract) and would
  # not sum to the population.
  tr$.area <- as.numeric(sf::st_area(tr))
  tr <- tr[tr$.area > 0, , drop = FALSE]

  # -- rings, built geometrically -------------------------------------------
  #
  # ring(b) = iso(b) minus every tighter band for the SAME provider. Built per
  # coord_id because subtracting another provider's isochrone would be a
  # different model entirely.
  ring_for <- function(id, b) {
    g_b <- sf::st_geometry(iso[iso$coord_id == id &
                                 iso$drive_time_minutes == b, ])
    if (!length(g_b)) return(NULL)
    inner <- bands[bands < b]
    if (!length(inner)) return(sf::st_union(g_b))
    g_in <- sf::st_geometry(iso[iso$coord_id == id &
                                  iso$drive_time_minutes %in% inner, ])
    if (!length(g_in)) return(sf::st_union(g_b))
    d <- suppressMessages(sf::st_difference(sf::st_union(g_b), sf::st_union(g_in)))
    if (!length(d)) NULL else d
  }

  ids <- sort(unique(iso$coord_id))
  frac_rows <- list()
  for (id in ids) {
    for (b in bands) {
      g <- ring_for(id, b)
      if (is.null(g) || all(sf::st_is_empty(g))) next
      hit <- which(lengths(suppressMessages(sf::st_intersects(tr, g))) > 0L)
      if (!length(hit)) next
      inter <- suppressMessages(sf::st_intersection(sf::st_geometry(tr[hit, ]), g))
      # st_intersection can drop rows; recompute the mapping by index.
      keep <- attr(inter, "idx")
      a <- as.numeric(sf::st_area(inter))
      idx <- if (is.null(keep)) hit else hit[keep[, 1]]
      frac_rows[[length(frac_rows) + 1L]] <- data.frame(
        coord_id = id, band = b, GEOID = tr$GEOID[idx],
        ring_area = a, tract_area = tr$.area[idx],
        stringsAsFactors = FALSE)
    }
  }
  frac <- dplyr::bind_rows(frac_rows) |>
    dplyr::group_by(coord_id, band, GEOID) |>
    dplyr::summarise(ring_area = sum(ring_area),
                     tract_area = dplyr::first(tract_area), .groups = "drop") |>
    dplyr::mutate(ring_fraction = ring_area / tract_area)

  # A share of a tract cannot exceed the tract. Anything above 1 is a geometry
  # or CRS error, not a rounding artifact, so it stops rather than being capped.
  if (any(frac$ring_fraction > 1 + 1e-9)) {
    stop("ring_fraction > 1 for ", sum(frac$ring_fraction > 1 + 1e-9),
         " rows; the intersection is larger than the tract it is inside.",
         call. = FALSE)
  }

  pop <- tibble::tibble(GEOID = tr$GEOID, pop = as.numeric(tr[[pop_col]]))
  # DECISION 2: a tract with NA population is UNMEASURED, not empty. It is
  # excluded from the demand sum rather than counted as zero, because counting
  # it as zero would let a provider's ratio rise on population that was simply
  # never observed. The fixture has none; the branch exists so a later vintage
  # with suppressed tracts does not silently inflate access.
  pop_na <- pop$GEOID[is.na(pop$pop)]
  pop <- pop[!is.na(pop$pop), ]

  wtab <- tibble::tibble(band = bands, w = as.numeric(weights[as.character(bands)]))

  base <- frac |>
    dplyr::inner_join(wtab, by = "band") |>
    dplyr::inner_join(pop, by = "GEOID")

  # -- step 1: provider-to-population ratio ---------------------------------
  demand <- base |>
    dplyr::group_by(coord_id) |>
    dplyr::summarise(weighted_demand = sum(w * ring_fraction * pop),
                     .groups = "drop") |>
    dplyr::right_join(dplyr::mutate(supply, coord_id = as.character(coord_id)),
                      by = "coord_id") |>
    dplyr::mutate(weighted_demand = dplyr::coalesce(weighted_demand, 0))

  if (any(demand$weighted_demand <= 0) && identical(zero_demand, "error")) {
    stop("providers with zero weighted demand: ",
         paste(demand$coord_id[demand$weighted_demand <= 0], collapse = ", "),
         call. = FALSE)
  }
  # DECISION 3: R_j is undefined when no population is reachable. The surface
  # cannot carry an undefined ratio, so that supply is excluded from step 2 and
  # reported separately -- it is supply that serves nobody in this model, which
  # is a finding about the model's reach, not a zero.
  demand <- dplyr::mutate(
    demand,
    ratio = dplyr::if_else(weighted_demand > 0, supply / weighted_demand,
                           NA_real_),
    ratio_used = dplyr::coalesce(ratio, 0))

  # -- step 2: accessibility at each tract ----------------------------------
  access <- base |>
    dplyr::inner_join(demand[, c("coord_id", "ratio_used")], by = "coord_id") |>
    dplyr::group_by(GEOID) |>
    dplyr::summarise(access = sum(w * ring_fraction * ratio_used),
                     n_providers = dplyr::n_distinct(coord_id[ratio_used > 0]),
                     .groups = "drop")

  # DECISION 4, and the one that matters most downstream: a tract no ring
  # touches is NOT given access 0. Zero is a measurement -- "providers were
  # modelled here and the answer was none" -- while these tracts were never
  # reached by the model at all. Both columns are returned: `access` is NA for
  # them and `access_zerofilled` is the 0-coerced form, so a caller has to
  # choose which claim to make rather than inherit one.
  all_tracts <- tibble::tibble(GEOID = sort(unique(tr$GEOID)))
  out <- all_tracts |>
    dplyr::left_join(access, by = "GEOID") |>
    dplyr::mutate(
      reached = !is.na(access),
      n_providers = dplyr::coalesce(n_providers, 0L),
      access_zerofilled = dplyr::coalesce(access, 0),
      access_scaled = access * per_capita_scale,
      access_scaled_zerofilled = access_zerofilled * per_capita_scale)

  list(access = out,
       provider_ratios = dplyr::arrange(demand, coord_id),
       ring_fractions = frac,
       weights = weights,
       unmeasured_population_tracts = pop_na,
       method = "E2SFCA (reference, geometric rings)")
}

# ---------------------------------------------------------------------------
# Run it against the fixture, and compare
# ---------------------------------------------------------------------------

rd <- function(f) readRDS(file.path(FIXTURE_DIR, paste0(f, ".rds")))
iso <- rd("isochrones"); supply <- rd("supply"); tracts <- rd("tracts")
ts <- rd("e2sfca_twostep")

WEIGHTS <- c(`30` = 1.00, `60` = 0.68)

say("running the reference implementation ...")
ref <- e2sfca_reference(iso, supply, tracts, weights = WEIGHTS)

say("  reached tracts: %d of %d (%d never reached)",
    sum(ref$access$reached), nrow(ref$access), sum(!ref$access$reached))
say("  providers with zero demand: %d",
    sum(is.na(ref$provider_ratios$ratio)))

# -- compare ---------------------------------------------------------------

cmp <- ref$access |>
  dplyr::select(GEOID, ref = access_zerofilled, reached) |>
  dplyr::inner_join(dplyr::select(ts$access, GEOID, pkg = access), by = "GEOID") |>
  dplyr::mutate(diff = ref - pkg,
                rel = dplyr::if_else(pkg > 0, abs(diff) / pkg, NA_real_))

# Compared on a RELATIVE scale, deliberately. Access values here are of order
# 1e-5, so an absolute tolerance of 1e-12 is a relative tolerance of 1e-7 --
# tighter than the noise from summing 22,535 products in a different order, and
# it reports every tract in the state as "differing". The first run of this
# script did exactly that and made a floating-point artifact look like a
# systematic bias.
say("")
say("=== ACCESS SURFACE: reference vs twostep ===")
say("  tracts compared            : %d", nrow(cmp))
say("  access values are of order : %.1e", stats::median(cmp$pkg[cmp$pkg > 0]))
reached <- cmp[cmp$reached & cmp$pkg > 0, ]
say("  median relative difference : %.2e", stats::median(reached$rel))
for (t in c(1e-6, 1e-3, 1e-2)) {
  say("  agreeing within %-7s    : %d of %d", format(t),
      sum(reached$rel < t), nrow(reached))
}
say("  max relative difference    : %.2f%%", 100 * max(reached$rel))

# -- is the residual disagreement the nesting violation? -------------------
#
# Stated as a linkage with a control, not as a correlation. "The worst
# disagreements are near the violators" is the kind of claim that is true of
# any two rankings; the control is what makes it evidence.

nest <- rd("band_nesting")
violators <- nest$coord_id[!is.na(nest$outside_frac) &
                             nest$outside_frac > 0.01]
disagree <- reached$GEOID[reached$rel > 1e-2]
agree <- reached$GEOID[reached$rel < 1e-6]

served_by_violator <- function(geoids) {
  if (!length(geoids)) return(c(hit = 0L, n = 0L))
  s <- ref$ring_fractions |>
    dplyr::filter(GEOID %in% geoids) |>
    dplyr::group_by(GEOID) |>
    dplyr::summarise(v = any(coord_id %in% violators), .groups = "drop")
  c(hit = sum(s$v), n = nrow(s))
}
d_hit <- served_by_violator(disagree)
a_hit <- served_by_violator(agree)

say("")
say("=== IS THE RESIDUAL THE NESTING VIOLATION? ===")
say("  locations violating nesting        : %s", paste(violators, collapse = ", "))
say("  tracts disagreeing > 1%%            : %d, of which %d served by a violator",
    d_hit[["n"]], d_hit[["hit"]])
say("  tracts agreeing to 1e-6 (control)  : %d, of which %d served by a violator",
    a_hit[["n"]], a_hit[["hit"]])
say("  direction: reference higher in %d of %d disagreeing tracts",
    sum(reached$ref[reached$rel > 1e-2] > reached$pkg[reached$rel > 1e-2]),
    d_hit[["n"]])
say("  (the cumulative decomposition gives area inside the 30-minute polygon")
say("   but outside the 60-minute one a weight of 0.32 where the method says")
say("   1.00, so the package reads LOW exactly there.)")

pr <- ref$provider_ratios |>
  dplyr::select(coord_id, ref_supply = supply, ref_demand = weighted_demand,
                ref_ratio = ratio) |>
  dplyr::inner_join(
    dplyr::select(ts$provider_ratios, coord_id,
                  pkg_demand = weighted_demand, pkg_ratio = ratio),
    by = "coord_id") |>
  dplyr::mutate(demand_rel = abs(ref_demand - pkg_demand) / pkg_demand) |>
  dplyr::left_join(nest[, c("coord_id", "outside_frac")], by = "coord_id")

say("")
say("=== STEP 1 (weighted demand per provider) ===")
say("  providers compared         : %d", nrow(pr))
say("  max relative difference    : %.4f%%", 100 * max(pr$demand_rel))
say("  the three largest disagreements:")
print(as.data.frame(head(dplyr::arrange(pr, dplyr::desc(demand_rel))[
  , c("coord_id", "outside_frac", "ref_demand", "pkg_demand", "demand_rel")], 3)),
  row.names = FALSE)

# -- conservation ----------------------------------------------------------

say("")
say("=== CONSERVATION ===")
say("  supply, fixture / reference / twostep : %g / %g / %g",
    sum(supply$supply), sum(ref$provider_ratios$supply),
    sum(ts$provider_ratios$supply))
# NOT a conservation identity. Summing weighted demand across providers counts
# the same woman once per provider whose catchment reaches her, so the total
# exceeds the population by the mean catchment overlap. Stated as a multiplier
# so it cannot be mistaken for a leak.
say("  state female population              : %s",
    format(sum(tracts$female_pop, na.rm = TRUE), big.mark = ","))
say("  summed weighted demand / population  : %.2fx (mean catchment overlap,",
    sum(ref$provider_ratios$weighted_demand) / sum(tracts$female_pop, na.rm = TRUE))
say("                                         not a conservation check)")

# -- zero versus missing ---------------------------------------------------

say("")
say("=== ZERO VERSUS MISSING ===")
say("  twostep tracts at exactly 0      : %d", sum(ts$access$access == 0))
say("  reference tracts never reached   : %d", sum(!ref$access$reached))
say("  reference tracts reached AND 0   : %d",
    sum(ref$access$reached & ref$access$access == 0, na.rm = TRUE))
say("  the two sets are the same tracts : %s",
    identical(sort(ts$access$GEOID[ts$access$access == 0]),
              sort(ref$access$GEOID[!ref$access$reached])))

saveRDS(ref, file.path(FIXTURE_DIR, "e2sfca_reference.rds"),
        version = 3, compress = "xz")
saveRDS(list(access = cmp, providers = pr),
        file.path(FIXTURE_DIR, "comparison.rds"), version = 3, compress = "xz")
say("")
say("wrote e2sfca_reference.rds and comparison.rds to %s", FIXTURE_DIR)
