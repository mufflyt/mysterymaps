# Default isochrone drive-time bands, in minutes

The four bands this package's isochrone-consuming map functions default
to: 30, 60, 120, and 180 minutes. Centralized so every function that
takes a `bands_minutes` argument shares one default instead of each
re-typing (and risking drift on) its own copy.

## Usage

``` r
MYSTERYMAPS_ISOCHRONE_BANDS_MINUTES
```

## Format

An integer vector, length 4.
