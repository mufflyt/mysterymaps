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
  crs = 5070
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
