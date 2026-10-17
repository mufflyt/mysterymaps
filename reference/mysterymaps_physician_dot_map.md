# Dot map of physician practice locations

Plots one point per physician over a state basemap. Ported from the
`isochrones` project's `THE_ONE_physician_dot_map()` after that function
was found to render maps with **no dots at all**, and the three traps
behind that failure are handled here rather than left for the next
caller.

## Usage

``` r
mysterymaps_physician_dot_map(
  physicians,
  basemap,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  point_color = "#e74c3c",
  point_size = 1.4,
  point_alpha = 0.75,
  color_var = NULL,
  palette = NULL,
  crs = 5070,
  jitter_miles = 1.5,
  jitter_seed = 42,
  outline = TRUE,
  point_outline_color = "black"
)
```

## Arguments

- physicians:

  `sf` POINT layer, one row per physician.

- basemap:

  `sf` polygon layer to draw beneath the points.

- title, subtitle, caption:

  Character labels. `NULL` omits.

- point_color:

  Fill colour when `color_var` is `NULL`.

- point_size, point_alpha:

  Point aesthetics.

- color_var:

  Optional column in `physicians` to colour by.

- palette:

  Optional named/unnamed colour vector for `color_var`. When `NULL` a
  hue scale is used; passing `NULL` to
  [`scale_color_manual()`](https://ggplot2.tidyverse.org/reference/scale_manual.html)
  raises "Insufficient values in manual scale", which is what the
  original did.

- crs:

  Projection for display. Default EPSG:5070, Albers Equal Area,
  appropriate for the contiguous United States.

- jitter_miles:

  `numeric(1)`: maximum deterministic jitter radius, in miles, applied
  via
  [`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md)
  before plotting. Default `1.5` (under the 2-mile ceiling), so
  physicians stacked on the same building or block separate visually
  without a run-to-run-unstable map. `0` disables jitter.

- jitter_seed:

  `numeric(1)` or `NULL`: seed for `jitter_miles`. Default `42`, so the
  jitter – and therefore the published figure – is reproducible. Passed
  to
  [`mysterymaps_jitter_points()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_jitter_points.md).

- outline:

  `logical(1)`: draw points as a filled, outlined shape (`shape = 21`)
  rather than a solid dot (`shape = 16`). Default `TRUE`; an outline
  reads more clearly against a busy basemap or a `color_var` fill that
  is close in hue to the basemap.

- point_outline_color:

  Outline colour used when `outline = TRUE`.

## Value

A `ggplot` object. The caller saves it; this function writes nothing.

## Details

**Trap 1: a bare `if` inside a ggplot `+` chain swallows the rest of the
chain.** The original built its point layer as an inline
`... + if (cond) A else B + coord_sf(...) + theme(...)`. R parses `if`
as extending as far right as possible, so the tail of the chain became
part of the else branch and the layer never joined the plot. Measured on
a real call: 601 points reached the plotting code, the assembled plot
carried three layers (states, north arrow, scale bar), and the PNG
contained zero coloured pixels, while the caption confidently reported
the physician count. Here the layer is built into an object first and
added as a plain term.

**Trap 2: basemap polygons are frequently invalid.**
[`maps::map()`](https://rdrr.io/pkg/maps/man/map.html) output breaks
[`sf::st_union()`](https://r-spatial.github.io/sf/reference/geos_combine.html)
with a TopologyException. Repair is attempted, and measurably must
happen in PLANAR mode:
[`st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
under spherical geometry repaired only 44 of 49 state polygons, against
all 49 with s2 disabled. The s2 setting is saved and restored.

**Trap 3: an empty result is reported as an empty cohort.** Filtering a
subspecialty by a label the data does not use (`MIGS` where the artifact
says `MIG`) yields zero rows, and the original stopped with "no
physicians found", which reads as a real absence rather than a label
mismatch. This function refuses a zero-row input with a message that
says so.

## Examples

``` r
if (FALSE) { # interactive()
physicians <- sf::st_as_sf(
  data.frame(lon = -99.5 + 0:2, lat = 40.2 + (0:2) * 0.2),
  coords = c("lon", "lat"), crs = 4326)
basemap <- sf::st_sf(geometry = sf::st_sfc(
  sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
  crs = 4326))
mysterymaps_physician_dot_map(physicians, basemap)
}
```
