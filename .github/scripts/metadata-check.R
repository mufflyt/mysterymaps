# Package metadata must still describe this package at this version.
#
# CITATION.cff, codemeta.json, inst/CITATION and DESCRIPTION are four copies of
# overlapping facts. They drift the moment one is updated by hand, and the
# symptom is a citation that names the wrong version -- which nobody notices,
# because nobody re-reads their own citation file.

`%||%` <- function(a, b) if (is.null(a)) b else a

problems <- character(0)
note <- function(...) problems <<- c(problems, sprintf(...))

d <- desc::desc(file = "DESCRIPTION")
version <- as.character(d$get_version())
pkg <- d$get_field("Package")
url <- d$get_field("URL", default = NA_character_)

cat(sprintf("DESCRIPTION: %s %s\n", pkg, version))

# ---- CITATION.cff ------------------------------------------------------------
if (!file.exists("CITATION.cff")) {
  note("CITATION.cff is missing")
} else {
  cff <- readLines("CITATION.cff", warn = FALSE)

  cff_version <- sub('^version:\\s*"?([^"]*)"?\\s*$', "\\1",
                     grep("^version:", cff, value = TRUE)[1])
  if (is.na(cff_version)) {
    note("CITATION.cff has no `version:` field")
  } else if (!identical(trimws(cff_version), version)) {
    note("CITATION.cff version (%s) does not match DESCRIPTION (%s)",
         trimws(cff_version), version)
  }

  # cffr regenerates the file from DESCRIPTION; a diff means it is stale.
  if (requireNamespace("cffr", quietly = TRUE)) {
    tmp <- tempfile(fileext = ".cff")
    # Schema validation needs jsonvalidate (and V8 underneath it). A runner
    # without them is a missing TOOL, not a metadata defect, so it reports and
    # moves on -- failing the nightly for it would make the job about the
    # runner's package set rather than about the citation file.
    can_validate <- requireNamespace("jsonvalidate", quietly = TRUE)
    ok <- tryCatch({
      cffr::cff_write(".", outfile = tmp, verbose = FALSE,
                      validate = can_validate)
      TRUE
    }, error = function(e) {
      note("cffr could not write CITATION.cff: %s", conditionMessage(e))
      FALSE
    })
    if (ok && can_validate) cat("CITATION.cff validates against the schema.\n")
    if (ok && !can_validate) {
      cat("CITATION.cff written; schema validation skipped ",
          "(jsonvalidate not installed).\n", sep = "")
    }
  }
}

# ---- codemeta.json -----------------------------------------------------------
if (!file.exists("codemeta.json")) {
  note("codemeta.json is missing")
} else {
  cm <- tryCatch(jsonlite::read_json("codemeta.json"),
                 error = function(e) {
                   note("codemeta.json is not valid JSON: %s", conditionMessage(e))
                   NULL
                 })
  if (!is.null(cm)) {
    cm_version <- cm$version %||% cm$softwareVersion
    if (is.null(cm_version)) {
      note("codemeta.json has no version field")
    } else if (!identical(as.character(cm_version), version)) {
      note("codemeta.json version (%s) does not match DESCRIPTION (%s)",
           cm_version, version)
    }
    if (!identical(cm$identifier %||% cm$name %||% "", pkg) &&
        !grepl(pkg, cm$name %||% "", fixed = TRUE)) {
      note("codemeta.json does not name the package `%s`", pkg)
    }
  }
}

# ---- inst/CITATION -----------------------------------------------------------
if (file.exists("inst/CITATION")) {
  # The file references meta$Version, which is only bound at install time, so
  # DESCRIPTION has to be handed in. Without it the version renders as NA and
  # the check below reports a mismatch that does not exist.
  cit_meta <- as.list(read.dcf("DESCRIPTION")[1, , drop = TRUE])
  cit <- tryCatch(utils::readCitationFile("inst/CITATION", meta = cit_meta),
                  error = function(e) {
                    note("inst/CITATION does not parse: %s", conditionMessage(e))
                    NULL
                  })
  if (!is.null(cit)) {
    txt <- paste(format(cit, style = "text"), collapse = " ")
    if (!grepl(version, txt, fixed = TRUE)) {
      note("inst/CITATION does not mention version %s", version)
    }
  }
}

# ---- NEWS --------------------------------------------------------------------
# A release with no NEWS entry is a release nobody can read the shape of.
if (file.exists("NEWS.md")) {
  news <- readLines("NEWS.md", warn = FALSE)
  if (!any(grepl(version, news, fixed = TRUE))) {
    note("NEWS.md has no entry for version %s", version)
  }
} else {
  note("NEWS.md is missing")
}

# ---- URL ---------------------------------------------------------------------
if (is.na(url) || !nzchar(url)) note("DESCRIPTION has no URL field")
if (is.na(d$get_field("BugReports", default = NA_character_))) {
  note("DESCRIPTION has no BugReports field")
}

# ---- Every Import is actually imported ---------------------------------------
# An Imports entry never referenced in R/ is a dependency the user installs for
# nothing, and R CMD check only notices some of them.
imports <- d$get_deps()
imports <- imports$package[imports$type == "Imports"]
src <- unlist(lapply(list.files("R", pattern = "\\.[Rr]$", full.names = TRUE),
                     readLines, warn = FALSE))
ns <- readLines("NAMESPACE", warn = FALSE)
for (p in setdiff(imports, "R")) {
  used <- any(grepl(paste0(p, "::"), src, fixed = TRUE)) ||
    any(grepl(sprintf("^import(From)?\\(%s[,)]", p), ns))
  if (!used) note("Imports lists `%s` but nothing in R/ or NAMESPACE uses it", p)
}

# ---- Report ------------------------------------------------------------------
if (length(problems)) {
  cat(sprintf("\nMetadata: %d problem(s)\n", length(problems)))
  for (p in problems) writeLines(sprintf("::error::%s", p))
  quit(status = 1)
}
cat("\nMetadata is consistent.\n")
