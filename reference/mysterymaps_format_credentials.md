# Format provider credentials for display after a name

Turns free-form NPPES credential text into a short, canonical suffix:
`"C.N.M."` and `"RN, CNM"` both become `"CNM"`, and `"CNM, WHNP-BC"` is
kept whole.

## Usage

``` r
mysterymaps_format_credentials(x, keep = .MM_CRED_KEEP, max_n = 3L)
```

## Arguments

- x:

  `character`: raw credential text, e.g. `"RN, CNM"`.

- keep:

  `character`: credentials to display. Defaults to midwifery,
  women's-health nurse-practitioner and physician credentials.

- max_n:

  `integer(1)`: most credentials to show; extras are dropped rather than
  allowed to overrun a popup line.

## Value

[character](https://rdrr.io/r/base/character.html) the same length as
`x`; `NA` where nothing survives.

## Details

NPPES credential text is entered by the provider and is not controlled
vocabulary. Across 18,760 midwives it appears as `CNM`, `C.N.M.`,
`C.N.M`, `RN, CNM`, `APRN-CNM`, `CNM, WHNP-BC`, `MSN, CNM` and dozens
more. Rendering it verbatim in a popup shows the data-entry variation
rather than the credential.

Selection is a KEEP-list, not a drop-list. The text is unbounded, so an
exclusion list quietly admits whatever new string appears next; an
inclusion list fails closed. Degrees and licences that are not
credentials in the honorific sense (`RN`, `APRN`, `ARNP`, `MSN`, `DNP`,
`PhD`) are therefore not shown by default – pass `keep` to change that.

Order follows the source string, so a provider who lists `CNM, WHNP-BC`
keeps that order rather than having one imposed.

## See also

Other text:
[`mysterymaps_place_title_case()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_place_title_case.md),
[`mysterymaps_pluralize()`](https://mufflyt.github.io/mysterymaps/reference/mysterymaps_pluralize.md)

## Examples

``` r
mysterymaps_format_credentials("C.N.M.")        # "CNM"
#> [1] "CNM"
mysterymaps_format_credentials("RN, CNM")       # "CNM"
#> [1] "CNM"
mysterymaps_format_credentials("CNM, WHNP-BC")  # "CNM, WHNP-BC"
#> [1] "CNM, WHNP-BC"
mysterymaps_format_credentials("RN")            # NA
#> [1] NA
```
