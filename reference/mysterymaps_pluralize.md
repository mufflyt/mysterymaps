# Agree a noun with its count

Returns a count and noun that agree in number: `1 midwife`,
`13 midwives`.

## Usage

``` r
mysterymaps_pluralize(
  n,
  singular,
  plural = NULL,
  big_mark = TRUE,
  include_n = TRUE
)
```

## Arguments

- n:

  `numeric`: the count. `NA` returns `NA_character_`.

- singular:

  `character(1)`: noun in its singular form.

- plural:

  `character(1)|NULL`: plural form. Defaults to `paste0(singular, "s")`.

- big_mark:

  `logical(1)`: comma-group counts of 1,000 or more.

- include_n:

  `logical(1)`: when `FALSE`, return only the agreed noun.

## Value

[character](https://rdrr.io/r/base/character.html) the same length as
`n`.

## Details

Written because map labels built with `sprintf("%d midwives", n)` render
"1 midwives" whenever a county holds exactly one provider – visible on
every single-provider county of a national choropleth, which is most of
the rural ones.

English plurals are irregular often enough that appending `"s"` is only
a default, never an assumption: pass `plural` for anything that does not
take it. `0` takes the plural ("0 midwives"), which is what English
does.

## See also

Other text:
[`mysterymaps_format_credentials()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_format_credentials.md),
[`mysterymaps_place_title_case()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_place_title_case.md)

## Examples

``` r
mysterymaps_pluralize(1, "midwife", "midwives")   # "1 midwife"
#> [1] "1 midwife"
mysterymaps_pluralize(13, "midwife", "midwives")  # "13 midwives"
#> [1] "13 midwives"
mysterymaps_pluralize(0, "midwife", "midwives")   # "0 midwives"
#> [1] "0 midwives"
mysterymaps_pluralize(2400, "birth")              # "2,400 births"
#> [1] "2,400 births"
mysterymaps_pluralize(1, "midwife", "midwives", include_n = FALSE)  # "midwife"
#> [1] "midwife"
```
