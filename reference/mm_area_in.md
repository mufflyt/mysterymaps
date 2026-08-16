# Measure area on the globe, not in whatever CRS the caller stored it in

The idiom this replaces is `as.numeric(sf::st_area(x)) / 1e6`, and it is
wrong in two independent ways that both produce a plausible number.

## Usage

``` r
mm_area_in(x, unit = "km^2")
```

## Arguments

- x:

  `sf|sfc`: geometry to measure. Areas are summed across features.

- unit:

  `character(1)`: the unit to return, as `units` spells it – `"km^2"`,
  `"m^2"`, `"mi^2"`.

## Value

`numeric(1)`: total area in `unit`. Zero for empty input.

## The unit belongs to the CRS, not to the metre

[`sf::st_area()`](https://r-spatial.github.io/sf/reference/geos_measures.html)
returns a `units` object in the linear unit the CRS declares, so
dividing by `1e6` yields square kilometres only when that unit happens
to be the metre. Several US state plane systems are in US survey feet.
EPSG:2232, NAD83 / Colorado Central, is an ordinary choice for a
Colorado study, and there a polygon of 147,582 km2 measures 1,588,550 –
a factor of 10.76, with no warning, because the arithmetic is valid and
only the unit is wrong.

## A conformal projection preserves shape, not area

Worse, because unit conversion cannot see it. In EPSG:3857 the same
polygon measures roughly 1.8x its true size at latitude 42 – in metres,
from a metre-declaring CRS. Web Mercator is the default of every slippy
map, so a surface arriving straight off a web tile pipeline carries this
silently.

Both are avoided by not measuring in the caller's CRS at all: the
geometry is transformed to EPSG:4326 and measured geodesically, which is
correct everywhere rather than inside one projection's zone. That
matters here –
[`mysterymaps_guard_water_masks()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_guard_water_masks.md)
is handed Alaska and Hawaii, so no single projected CRS (EPSG:5070 is
CONUS) would do.

## Why s2 is forced on

With `sf_use_s2(FALSE)`,
[`sf::st_area()`](https://r-spatial.github.io/sf/reference/geos_measures.html)
routes geodetic area through `lwgeom`, a Suggests that is absent on a
bare runner – so the measurement would not merely differ with the
caller's session state, it would error on exactly the machines where
nothing is installed. s2's authalic sphere reads about 0.15% under the
ellipsoid on a state-sized polygon, which is immaterial to a 5x
threshold and to a number in a popup; depending on what the caller ran
first is not. The setting is restored on exit.

Geometry with no CRS errors rather than defaulting. Coordinates with an
unknown unit are not a reason to assume metres, and assuming is the
whole failure above.

## See also

Other geospatial:
[`mm_honeycomb_counts()`](https://mufflyt.github.io/mysterymaps/reference/mm_honeycomb_counts.md),
[`validate_sf_inputs()`](https://mufflyt.github.io/mysterymaps/reference/validate_sf_inputs.md)
