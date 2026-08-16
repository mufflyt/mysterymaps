# Every exported function must appear in the pkgdown reference index.
#
# pkgdown itself warns about topics missing from the index and then builds the
# site anyway. A function absent from the reference page is a function readers
# will never find, which is indistinguishable from not shipping it.

ns <- readLines("NAMESPACE", warn = FALSE)
exported <- sub("^export\\((.*)\\)$", "\\1",
                grep("^export\\(", ns, value = TRUE))
exported <- gsub('"', "", exported, fixed = TRUE)

yml <- readLines("_pkgdown.yml", warn = FALSE)
listed <- trimws(sub("^\\s*-\\s*", "", grep("^\\s*-\\s", yml, value = TRUE)))

missing <- exported[!exported %in% listed]

if (length(missing)) {
  cat("Exported but absent from _pkgdown.yml reference index:\n")
  cat(paste0("  - ", missing, collapse = "\n"), "\n")
  for (m in missing) {
    writeLines(sprintf("::error::`%s` is exported but not in the pkgdown reference index", m))
  }
  quit(status = 1)
}

# The reverse: an index entry naming a topic that no longer exists breaks the
# build on the next pkgdown release rather than this one.
rd <- tools::file_path_sans_ext(list.files("man", pattern = "\\.Rd$"))
stale <- setdiff(intersect(listed, listed), c(rd, "canonical-functions"))
stale <- stale[grepl("^mysterymaps_", stale)]
if (length(stale)) {
  cat("Listed in _pkgdown.yml but has no man/*.Rd:\n")
  cat(paste0("  - ", stale, collapse = "\n"), "\n")
  for (s in stale) {
    writeLines(sprintf("::error::`%s` is in the pkgdown index but has no Rd topic", s))
  }
  quit(status = 1)
}

cat(sprintf("All %d exported functions appear in the pkgdown reference index.\n",
            length(exported)))
