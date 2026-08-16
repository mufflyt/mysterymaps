# Create and Save a Leaflet Dot Map of Physicians

This function creates a Leaflet dot map of physicians using their
longitude and latitude coordinates. It also adds ACOG district
boundaries to the map and saves it as an HTML file with an accompanying
PNG screenshot.

## Usage

``` r
mysterymaps_map_physicians(
  physician_data,
  jitter_range = 0.05,
  color_palette = "magma",
  popup_var = "name",
  output_dir = NULL,
  seed = NULL
)
```

## Arguments

- physician_data:

  An sf object containing physician data with `"long"` and `"lat"`
  columns.

- jitter_range:

  The range for adding jitter to latitude and longitude coordinates.

- color_palette:

  The color palette for ACOG district colors.

- popup_var:

  The variable to use for popup text.

- output_dir:

  Directory where the HTML map and PNG screenshot are saved. Defaults to
  a session-specific temporary folder.

- seed:

  Integer or `NULL`. Seed for the coordinate jitter, so a published dot
  map can be regenerated exactly. `NULL` (default) leaves the caller's
  random stream alone and produces a different jitter each run.

## Value

Invisibly returns the Leaflet map object, with a `mysterymaps_seed`
attribute recording the seed actually used.

## Reproducibility

The jitter moves every point by up to `jitter_range` degrees. That is a
real displacement on a published figure, so it has to be replayable:
pass `seed` and the same map comes back. The seed is applied locally –
the caller's `.Random.seed` is saved and restored – so seeding a map
does not silently reseed the rest of a script.

## See also

Other mapping:
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md)

## Examples

``` r
if (FALSE) { # interactive()
# Load required libraries
library(viridis)
library(leaflet)

# Generate physician data (replace with your own data)
physician_data <- data.frame(
  long = c(-95.363271, -97.743061, -98.493628, -96.900115, -95.369803),
  lat = c(29.763283, 30.267153, 29.424349, 32.779167, 29.751808),
  name = c("Physician 1", "Physician 2", "Physician 3", "Physician 4", "Physician 5"),
  ACOG_District = c("District I", "District II", "District III", "District IV", "District V")
)

# Create and save the dot map
mysterymaps_map_physicians(physician_data)
}
```
