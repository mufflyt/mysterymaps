test_that("count and noun agree", {
  # The bug: sprintf("%d midwives", n) renders "1 midwives", which is visible on
  # every single-provider county of a national map -- most of the rural ones.
  expect_equal(mysterymaps_pluralize(1, "midwife", "midwives"), "1 midwife")
  expect_equal(mysterymaps_pluralize(13, "midwife", "midwives"), "13 midwives")
  # Zero takes the plural, as English does.
  expect_equal(mysterymaps_pluralize(0, "midwife", "midwives"), "0 midwives")
  # The sign belongs to the number, not the noun.
  expect_equal(mysterymaps_pluralize(-1, "midwife", "midwives"), "-1 midwife")
})

test_that("plural defaults to +s but is never assumed for irregulars", {
  expect_equal(mysterymaps_pluralize(2, "birth"), "2 births")
  expect_equal(mysterymaps_pluralize(1, "birth"), "1 birth")
  # Appending "s" would give "midwifes"; the caller must supply the real plural.
  expect_equal(mysterymaps_pluralize(2, "midwife", "midwives"), "2 midwives")
})

test_that("counts are comma-grouped, and NA stays NA", {
  expect_equal(mysterymaps_pluralize(2400, "birth"), "2,400 births")
  expect_equal(mysterymaps_pluralize(2400, "birth", big_mark = FALSE), "2400 births")
  expect_true(is.na(mysterymaps_pluralize(NA, "midwife", "midwives")))
})

test_that("include_n returns the agreed noun alone", {
  expect_equal(mysterymaps_pluralize(1, "midwife", "midwives", include_n = FALSE), "midwife")
  expect_equal(mysterymaps_pluralize(4, "midwife", "midwives", include_n = FALSE), "midwives")
})

test_that("pluralize is vectorised", {
  expect_equal(mysterymaps_pluralize(c(1, 2), "midwife", "midwives"),
               c("1 midwife", "2 midwives"))
})

test_that("place names title-case without mangling", {
  expect_equal(mysterymaps_place_title_case("EADS, CO"), "Eads, CO")
  # str_to_title() alone gives "Eads, Co" and "Mcallen" -- both wrong.
  expect_equal(mysterymaps_place_title_case("MCALLEN, TX"), "McAllen, TX")
  expect_equal(mysterymaps_place_title_case("WINSTON-SALEM"), "Winston-Salem")
  expect_equal(mysterymaps_place_title_case("O'FALLON, MO"), "O'Fallon, MO")
  expect_equal(mysterymaps_place_title_case("ISLE OF PALMS"), "Isle of Palms")
  expect_equal(mysterymaps_place_title_case("ST. LOUIS, MO"), "St. Louis, MO")
})

test_that("already mixed-case input is left alone", {
  # Existing correct casing beats a blind re-case.
  expect_equal(mysterymaps_place_title_case("Los Angeles"), "Los Angeles")
  expect_equal(mysterymaps_place_title_case("DeKalb"), "DeKalb")
})

test_that("state and directional codes stay upper case", {
  expect_equal(mysterymaps_place_title_case("WASHINGTON, DC"), "Washington, DC")
  expect_match(mysterymaps_place_title_case("NW HARBOR"), "^NW ")
})

test_that("ordinals keep their form", {
  expect_equal(mysterymaps_place_title_case("3RD STREET"), "3rd Street")
})

test_that("empty and NA input pass through", {
  expect_equal(mysterymaps_place_title_case(character(0)), character(0))
  expect_true(is.na(mysterymaps_place_title_case(NA_character_)))
})

test_that("credential variants collapse to a canonical form", {
  # The four spellings of one credential seen across 18,760 midwives.
  expect_equal(mysterymaps_format_credentials("CNM"), "CNM")
  expect_equal(mysterymaps_format_credentials("C.N.M."), "CNM")
  expect_equal(mysterymaps_format_credentials("C.N.M"), "CNM")
  expect_equal(mysterymaps_format_credentials("RN, CNM"), "CNM")
})

test_that("a hyphen is resolved by trying the whole token first", {
  # WHNP-BC is ONE credential; APRN-CNM is two packed together. Splitting
  # unconditionally breaks the first; never splitting loses the second.
  expect_equal(mysterymaps_format_credentials("WHNP-BC"), "WHNP-BC")
  # APRN-CNM is a credential in its own right and is shown as written.
  expect_equal(mysterymaps_format_credentials("APRN-CNM"), "APRN-CNM")
  expect_equal(mysterymaps_format_credentials("APRN, CNM"), "APRN, CNM")
  expect_equal(mysterymaps_format_credentials("CNM, WHNP-BC"), "CNM, WHNP-BC")
})

test_that("selection is a keep-list, so unknown text fails closed", {
  # NPPES credential text is free-form; a drop-list would admit whatever new
  # string appears next.
  expect_true(is.na(mysterymaps_format_credentials("RN")))
  expect_true(is.na(mysterymaps_format_credentials("MIDWIFE")))
  expect_true(is.na(mysterymaps_format_credentials("SOMETHING NEW")))
  expect_equal(mysterymaps_format_credentials("MSN, CNM"), "CNM")
  expect_equal(mysterymaps_format_credentials("DNP, CNM"), "CNM")
})

test_that("source order is preserved and duplicates collapse", {
  expect_equal(mysterymaps_format_credentials("LM, CPM"), "LM, CPM")
  expect_equal(mysterymaps_format_credentials("CPM, LM"), "CPM, LM")
  expect_equal(mysterymaps_format_credentials("CNM, C.N.M."), "CNM")
})

test_that("max_n bounds the popup line, and keep is overridable", {
  expect_equal(mysterymaps_format_credentials("CNM, WHNP-BC, MD", max_n = 2L),
               "CNM, WHNP-BC")
  expect_equal(mysterymaps_format_credentials("RN", keep = c("RN")), "RN")
})

test_that("empty, NA and blank input yield NA", {
  expect_true(is.na(mysterymaps_format_credentials(NA_character_)))
  expect_true(is.na(mysterymaps_format_credentials("")))
  expect_equal(mysterymaps_format_credentials(character(0)), character(0))
})
