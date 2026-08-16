# Count providers per honeycomb cell over a study-area polygon

Split out of
[`mysterymaps_hrr_maps()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_hrr_maps.md)
because the count it produces was the one thing that function could not
be tested on: it returns a `gtable`, so a cell losing every provider it
holds is invisible to any assertion about the output.

## Usage

``` r
mm_honeycomb_counts(
  usa,
  physician_sf,
  cellsize = 0.3,
  min_count = 2L,
  southern_limit = 15
)
```

## Arguments

- usa:

  `sf`: the study-area polygon the grid is built over and clipped to.

- physician_sf:

  `sf`: provider points.

- cellsize:

  `numeric(1)`: hexagon size in degrees.

- min_count:

  `integer(1)`: cells holding fewer than this many providers are dropped
  rather than drawn. Two is the long-standing behaviour and is a
  small-cell suppression choice, not a rendering detail – a cell with
  one provider is drawn exactly like a cell with none.

- southern_limit:

  `numeric(1)`: cells entirely south of this latitude are outlying
  territory, not study area.

## Value

An `sf` of cells carrying a `physician_count`.

## The row-index filter this replaces

The line here used to be `dplyr::filter(grid_id > 9546L)`, commented
`# Filter out Palmyra Atoll`. `grid_id` is
[`dplyr::row_number()`](https://dplyr.tidyverse.org/reference/row_number.html)
over
[`sf::st_make_grid()`](https://r-spatial.github.io/sf/reference/st_make_grid.html),
whose cells run in longitude order across the bounding box of `usa` – so
the cut removed the 9,546 WESTERNMOST cells, whatever happened to be in
them, and moved whenever Natural Earth shipped a polygon with a
different extent.

Measured against the current polygon (bbox 171.8W-67.0W, 18.9N-71.4N):
the cut removed 1,223 cells containing US land – 1,214 in western
Alaska, 9 in Hawaii – among them Honolulu, Kauai and Nome. Palmyra Atoll
sits at 5.9N, outside that bounding box altogether, so the filter never
once removed the thing it named. What it removed was every physician in
Honolulu, from a map whose caller had just asked for Hawaii by name
(`remove_HI_AK = FALSE`) and which draws a Hawaii inset. The inset
rendered empty and read as a workforce finding.

The intent – keep a far-flung outlying territory from stretching the map
– is kept and expressed as geography, which cannot drift with a data
release. The southernmost point of the fifty states is Ka Lae, Hawaii,
at 18.9N; `southern_limit` sits well below it and well above Palmyra.

## See also

Other geospatial:
[`mm_area_in()`](https://mufflyt.github.io/mysterymaps/reference/mm_area_in.md),
[`validate_sf_inputs()`](https://mufflyt.github.io/mysterymaps/reference/validate_sf_inputs.md)
