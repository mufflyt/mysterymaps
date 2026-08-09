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
  library(mysterymaps); library(sf); library(ggplot2); library(leaflet)
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
