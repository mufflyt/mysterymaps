# Get isochrones for each point in a dataframe

This function retrieves isochrones for each point in a given dataframe
by looping over the rows and calling the mysterymaps_create_isochrones
function for each point.

## Usage

``` r
mysterymaps_isochrones_for_df(
  input_file,
  breaks = c(1800, 3600, 7200, 10800),
  api_key = Sys.getenv("HERE_API_KEY"),
  output_dir = NULL,
  save_interval = 240
)
```

## Arguments

- input_file:

  A path to the input file containing points for which isochrones are to
  be retrieved.

- breaks:

  A numeric vector specifying the breaks for categorizing drive times
  (default is c(1800, 3600, 7200, 10800)).

- api_key:

  API key for the drive-time routing service. Defaults to the
  `HERE_API_KEY` environment variable.

- output_dir:

  Directory where intermediate `.rds` results are written. Defaults to a
  session-specific folder beneath
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- save_interval:

  Number of seconds between automatic checkpoint saves. Defaults to 240
  seconds (~4 minutes).

## Value

An sf data frame (class `c("sf", "data.frame")`) with one row per
isochrone polygon. Columns include all original input columns plus
`name` (character label such as `"30 minutes"`), `range` (drive-time in
seconds), and geometry. Returns an empty
[`data.frame()`](https://rdrr.io/r/base/data.frame.html) if no valid
isochrones were generated. Intermediate results are checkpointed as
`.rds` and `.gpkg` files in `output_dir` at `save_interval` seconds.

## See also

[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md)
for single-point isochrone creation;
[`mysterymaps_calculate_overlap()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_calculate_overlap.md)
for the downstream block-group intersection step.

Other mapping:
[`mysterymaps_clear_isochrone_cache()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_clear_isochrone_cache.md),
[`mysterymaps_create_isochrones()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_create_isochrones.md),
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md),
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
isochrones_data <- mysterymaps_isochrones_for_df("points.csv")
}
```
