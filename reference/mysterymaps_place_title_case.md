# Title-case a place name without mangling it

`EADS, CO` becomes `Eads, CO`. Written for popups that display upstream
data held in all caps, where
[`stringr::str_to_title()`](https://stringr.tidyverse.org/reference/case.html)
alone produces `Eads, Co` and `Mcallen`.

## Usage

``` r
mysterymaps_place_title_case(x)
```

## Arguments

- x:

  `character`: place names, e.g. `"EADS"` or `"EADS, CO"`.

## Value

[character](https://rdrr.io/r/base/character.html) the same length as
`x`.

## Details

Handles the cases that actually appear in US place and provider data:

- a trailing two-letter state or territory code stays upper case;

- `Mc` and `Mac` prefixes capitalise the following letter (`MCALLEN` -\>
  `McAllen`);

- hyphenated and apostrophied names capitalise each part
  (`WINSTON-SALEM`, `O'FALLON`);

- small words stay lower case inside a name but not at its start
  (`ISLE OF PALMS` -\> `Isle of Palms`);

- directional and ordinal tokens keep their conventional form (`NW`,
  `US`, `ST`, `3RD`).

Input that is already mixed case is left alone: it is likelier to be
correct than a blind re-case would be.

## See also

Other text:
[`mysterymaps_format_credentials()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_format_credentials.md),
[`mysterymaps_pluralize()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pluralize.md)

## Examples

``` r
mysterymaps_place_title_case("EADS, CO")        # "Eads, CO"
#> [1] "Eads, CO"
mysterymaps_place_title_case("MCALLEN, TX")     # "McAllen, TX"
#> [1] "McAllen, TX"
mysterymaps_place_title_case("WINSTON-SALEM")   # "Winston-Salem"
#> [1] "Winston-Salem"
mysterymaps_place_title_case("ISLE OF PALMS")   # "Isle of Palms"
#> [1] "Isle of Palms"
```
