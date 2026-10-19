#!/usr/bin/env Rscript
# =============================================================================
# Regenerate the figures shown in README.md
# =============================================================================
# Run from the package root:  Rscript data-raw/make_readme_figures.R
#
# Everything here uses the North Carolina counties shipped inside {sf}, so the
# figures are reproducible with no API key, no network and no private data. The
# "rate" is synthetic and seeded; it exists to exercise the scales, not to say
# anything about North Carolina.
# =============================================================================
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)  # the commit under test, not an installed version
  library(sf); library(ggplot2); library(leaflet)
})
sf::sf_use_s2(FALSE)
set.seed(42)

FIG <- "man/figures"
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)

nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE) |>
  sf::st_transform(4326)

# A right-skewed rate with genuine zeros -- the shape provider counts actually
# take, and the case the zero-aware scale exists for.
nc$providers <- rpois(nrow(nc), lambda = 1.2)
nc$births    <- round(runif(nrow(nc), 120, 4200))
nc$rate      <- round(1000 * nc$providers / nc$births, 2)

# --- 1. static: zero-aware Jenks scale in ggplot2 ----------------------------
sc <- mysterymaps_jenks_zero_scale(nc$rate, k = 5, digits = 2)
sc$leg_labs[1] <- "none"
nc$fill <- sc$color(nc$rate)

p <- ggplot(nc) +
  geom_sf(aes(fill = fill), colour = "white", linewidth = 0.15) +
  scale_fill_identity(guide = "legend", breaks = sc$leg_cols,
                      labels = sc$leg_labs, name = "Providers per\n1,000 births") +
  labs(title = "Zero is its own class, not the bottom of a gradient",
       subtitle = sprintf("%d of %d counties have no provider",
                          sum(nc$providers == 0), nrow(nc)),
       caption = "Synthetic counts on sf's North Carolina counties") +
  theme_void(base_size = 11) +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold", size = 12),
        plot.subtitle = element_text(colour = "grey35", size = 10),
        plot.caption = element_text(colour = "grey55", size = 8))

ggsave(file.path(FIG, "static-jenks-zero.png"), p,
       width = 8, height = 4.2, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "static-jenks-zero.png"))

# --- 2. leaflet: county access map with coverage surfaces --------------------
# Two nested "coverage" surfaces, built by buffering a few county centroids, so
# the figure shows the real layer behaviour without shipping isochrones.
seeds <- sf::st_centroid(sf::st_geometry(nc[c(12, 40, 70, 95), ]))
band_a <- sf::st_sf(geometry = sf::st_union(sf::st_buffer(seeds, 0.30)))
band_b <- sf::st_sf(geometry = sf::st_union(sf::st_buffer(seeds, 0.65)))
gap    <- sf::st_sf(geometry = sf::st_difference(
  sf::st_union(sf::st_geometry(nc)), sf::st_union(sf::st_geometry(band_b))))

nc$.tooltip <- sprintf("<b>%s</b><br/>%s<br/>%s", nc$NAME,
                       mysterymaps_pluralize(nc$providers, "provider"),
                       mysterymaps_pluralize(nc$births, "birth"))
nc$.popup <- sprintf(
  "<div style='font:13px/1.6 system-ui'><b>%s County</b><br/>%s per 1,000 births</div>",
  nc$NAME, ifelse(nc$rate == 0, "no providers", nc$rate))

m <- mysterymaps_county_access_map(
  counties        = nc,
  value_col       = "rate",
  label_col       = ".tooltip",
  popup_col       = ".popup",
  coverage        = list("Within 30 minutes" = band_a,
                         "Within 60 minutes" = band_b,
                         "Beyond 60 minutes" = gap),
  coverage_colors = c("#08519c", "#3182bd", "#d94801"),
  coverage_labels = c("within 30 min of a provider",
                      "within 60 min of a provider",
                      "more than 60 min from any provider"),
  coverage_titles = c("Drive-time coverage", "Drive-time coverage",
                      "Coverage gap"),
  legend_title    = "Providers per<br/>1,000 births",
  bounds          = c(33.7, -84.4, 36.7, -75.4))

htmlwidgets::saveWidget(m, file.path(tempdir(), "readme_map.html"),
                        selfcontained = TRUE)
if (requireNamespace("webshot2", quietly = TRUE)) {
  webshot2::webshot(file.path(tempdir(), "readme_map.html"),
                    file.path(FIG, "leaflet-county-access.png"),
                    vwidth = 1100, vheight = 620, delay = 3)
  message("wrote ", file.path(FIG, "leaflet-county-access.png"))
} else {
  message("webshot2 unavailable; leaflet figure not regenerated")
}

# --- 3. rate choropleth: numerator/denominator, zero its own class ----------
p <- mysterymaps_rate_choropleth_map(
  nc, numerator_var = "providers", denominator_var = "births",
  numerator_label = "Providers", denominator_label = "Births", per = 1000,
  title = "Providers per 1,000 Births",
  subtitle = "Zero gets its own colour class, not the bottom of a gradient")
ggsave(file.path(FIG, "rate-choropleth.png"), p, width = 8, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "rate-choropleth.png"))

# --- 4. bivariate choropleth: joint class of two variables -------------------
nc$need <- round(runif(nrow(nc), 50, 500))
p <- mysterymaps_bivariate_choropleth_map(
  nc, x_var = "need", y_var = "rate",
  x_label = "Need (synthetic)", y_label = "Providers per 1,000 Births",
  title = "Need Versus Provider Supply, Jointly Classed")
ggsave(file.path(FIG, "bivariate-choropleth.png"), p, width = 8, height = 5.5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "bivariate-choropleth.png"))

# --- 5. catchment redundancy: how many providers' catchments overlap --------
set.seed(7)
provider_pts <- sf::st_sample(sf::st_union(sf::st_geometry(nc)), size = 10, exact = TRUE)
catchments <- sf::st_sf(physician_id = paste0("p", 1:10),
                        geometry = sf::st_buffer(provider_pts, 0.9))
p <- mysterymaps_catchment_redundancy_map(
  catchments, nc, provider_id_var = "physician_id", k = 4,
  title = "How Many Providers' Catchments Reach Each County",
  subtitle = "Count of overlapping 30-minute catchments per grid cell")
ggsave(file.path(FIG, "catchment-redundancy.png"), p, width = 8, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "catchment-redundancy.png"))

# --- 6. cartogram: polygons warped by drive time, not true area -------------
hub_coords <- sf::st_coordinates(sf::st_centroid(sf::st_union(sf::st_geometry(nc))))
nc$hub_lon <- hub_coords[1, "X"]
nc$hub_lat <- hub_coords[1, "Y"]
cent <- sf::st_centroid(sf::st_geometry(nc))
nc$straight_miles <- as.numeric(sf::st_distance(cent, sf::st_centroid(sf::st_union(sf::st_geometry(nc))))) / 1609.34
set.seed(8)
nc$drive_minutes <- pmax(nc$straight_miles * 1.3 + rnorm(nrow(nc), 0, 3), 1)
p <- mysterymaps_cartogram_map(
  nc, hub_id_var = "NAME", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
  time_var = "drive_minutes", straight_distance_var = "straight_miles",
  title = "Counties Warped by Drive Time From One Hub")
ggsave(file.path(FIG, "cartogram.png"), p, width = 8, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "cartogram.png"))

# --- 7. flow map: pre-routed paths coloured by travel time ------------------
set.seed(9)
hub_pt <- sf::st_centroid(sf::st_union(sf::st_geometry(nc)))
dest_idx <- c(5, 25, 45, 65, 85)
dests <- sf::st_centroid(sf::st_geometry(nc[dest_idx, ]))
routes <- sf::st_sf(
  trip    = nc$NAME[dest_idx],
  minutes = round(as.numeric(sf::st_distance(dests, hub_pt)) / 1609.34 * 1.3),
  geometry = sf::st_sfc(lapply(seq_along(dest_idx), function(i)
    sf::st_linestring(rbind(sf::st_coordinates(hub_pt), sf::st_coordinates(dests[i])))),
    crs = 4326))
basemap_sf <- sf::st_sf(geometry = sf::st_sfc(sf::st_union(sf::st_geometry(nc)), crs = 4326))
p <- mysterymaps_flow_map(
  routes, basemap_sf, time_var = "minutes",
  title = "Drive Time From One Hub to Five Destinations")
ggsave(file.path(FIG, "flow-map.png"), p, width = 8, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "flow-map.png"))

# --- 8. pathway small multiples: one facet per group, plus combined ---------
set.seed(11)
phys_pts <- sf::st_sample(sf::st_union(sf::st_geometry(nc)), size = 40, exact = TRUE)
phys <- sf::st_sf(
  pathway  = sample(c("Family Medicine", "Obstetrics & Gynecology"), 40,
                    replace = TRUE, prob = c(0.6, 0.4)),
  geometry = phys_pts)
p <- mysterymaps_pathway_small_multiples_map(
  phys, nc, pathway_var = "pathway", include_combined_panel = TRUE,
  title = "Where Each Pathway Practices")
ggsave(file.path(FIG, "pathway-small-multiples.png"), p, width = 10, height = 3.5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "pathway-small-multiples.png"))

# --- 9. hex-bin counts and hex-bin rate --------------------------------------
set.seed(13)
hex_pts <- sf::st_sample(sf::st_union(sf::st_geometry(nc)), size = 60, exact = TRUE)
hex_phys <- sf::st_sf(count_var = rep(1, 60), geometry = hex_pts)
boundary_sf <- sf::st_sf(geometry = sf::st_sfc(sf::st_union(sf::st_geometry(nc)), crs = 4326))

hexes <- mysterymaps_hex_bin_counts(
  boundary_sf, hex_phys, value_col = "count_var", cellsize = 0.25,
  include_zero_cells = TRUE)
p <- ggplot(hexes) +
  geom_sf(data = boundary_sf, fill = "grey97", colour = "grey80", linewidth = 0.15) +
  geom_sf(aes(fill = count_var), colour = "white", linewidth = 0.08) +
  scale_fill_viridis_c(name = "Providers per\nhexagon cell") +
  labs(title = "Provider Density, Hex-Binned") +
  theme_void(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 12))
ggsave(file.path(FIG, "hex-bin-counts.png"), p, width = 8.6, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "hex-bin-counts.png"))

hexes_rate <- mysterymaps_hex_bin_rate(
  boundary_sf, hex_phys, nc, denominator_col = "births", cellsize = 0.25,
  per = 1000, value_col = "rate_var")
p <- ggplot(hexes_rate) +
  geom_sf(data = boundary_sf, fill = "grey97", colour = "grey80", linewidth = 0.15) +
  geom_sf(aes(fill = rate_var), colour = "white", linewidth = 0.08) +
  scale_fill_viridis_c(name = "Providers per\n1,000 births", na.value = "white") +
  labs(title = "Provider Rate, Hex-Binned Over Areally-Interpolated Births") +
  theme_void(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 12))
ggsave(file.path(FIG, "hex-bin-rate.png"), p, width = 8.6, height = 5, dpi = 150, bg = "white")
message("wrote ", file.path(FIG, "hex-bin-rate.png"))
