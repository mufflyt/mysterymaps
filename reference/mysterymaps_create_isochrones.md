# Calculate drive-time isochrones for a location

Computes drive-time isolines (isochrones) for a given point using the
HERE routing API via the `hereR` package. Results are memoized in memory
for the duration of the R session so repeated calls with the same inputs
are free. Use
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md)
to release memory after a batch.

## Usage

``` r
mysterymaps_create_isochrones(
  location,
  range,
  posix_time = as.POSIXct("2023-10-20 08:00:00", format = "%Y-%m-%d %H:%M:%S"),
  api_key = Sys.getenv("HERE_API_KEY")
)
```

## Arguments

- location:

  An `sf` point object representing the origin location.

- range:

  Numeric vector of drive-time thresholds in **seconds** (e.g.
  `c(1800, 3600)` for 30- and 60-minute isochrones).

- posix_time:

  A `POSIXct` scalar giving the departure time used by the routing
  engine. Defaults to `"2023-10-20 08:00:00"` (a weekday morning).

- api_key:

  HERE API key. Defaults to the `HERE_API_KEY` environment variable.
  Obtain a free key at <https://www.here.com/developer>.

## Value

A named `list`. On success: one element per value in `range`, named by
the drive-time threshold in seconds (e.g., `"1800"`), each containing an
`sf` POLYGON object with the isochrone geometry. On API failure: a
`list` with a single `error` element (character scalar) containing the
error message. Detect failures with
`if (!is.null(result$error)) { ... }`.

## See also

[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md)
to free session memory after batch processing;
[`mysterymaps_geocode()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_geocode.md)
to produce the input coordinates.

Other mapping:
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
[`mysterymaps_isochrones_for_df()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_isochrones_for_df.md),
[`mysterymaps_map_acceptance_rate()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acceptance_rate.md),
[`mysterymaps_map_acog_districts()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_acog_districts.md),
[`mysterymaps_map_base()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_base.md),
[`mysterymaps_map_block_group()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_block_group.md),
[`mysterymaps_map_leaflet()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_leaflet.md),
[`mysterymaps_map_physicians()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_map_physicians.md),
[`mysterymaps_plot_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_plot_isochrones.md)

## Examples

``` r
if (FALSE) { # interactive()
location <- sf::st_sfc(sf::st_point(c(-73.987, 40.757)), crs = 4326)
isolines <- mysterymaps_create_isochrones(
  location = location,
  range    = c(1800, 3600)
)
mysterymaps_clear_isochrone_cache()
}
```
