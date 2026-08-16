# Source hygiene sweep.
#
# Each rule below exists because the corresponding mistake is easy to make,
# invisible in review, and expensive later. Failures print the offending file
# and line so the fix is obvious without opening the log twice.

problems <- character(0)
note <- function(...) problems <<- c(problems, sprintf(...))

r_files <- list.files("R", pattern = "\\.[Rr]$", full.names = TRUE)
test_files <- list.files("tests", pattern = "\\.[Rr]$", full.names = TRUE,
                         recursive = TRUE)
all_code <- c(r_files, test_files)

# ---- 1. Non-ASCII in executable code -----------------------------------------
# R CMD check flags non-ASCII in *code*, and this repo has already had to fix it
# once (commit 5b436e1); a literal en dash in a string is a portability problem
# on a non-UTF-8 locale, so those become \uXXXX escapes. Roxygen and ordinary
# comments are exempt: the package declares Encoding: UTF-8, R CMD check does
# not object, and forcing escapes into prose makes the prose unreadable.
for (f in r_files) {
  lines <- readLines(f, warn = FALSE)
  code <- sub("#.*$", "", lines)          # crude, but comments are what we skip
  bad <- which(grepl("[^\x01-\x7f]", code, useBytes = FALSE))
  for (i in bad) {
    note("%s:%d non-ASCII character in code; use a \\uXXXX escape\n    %s",
         f, i, trimws(lines[i]))
  }
}

# ---- 2. Debugging leftovers --------------------------------------------------
for (f in all_code) {
  lines <- readLines(f, warn = FALSE)
  for (pat in c("\\bbrowser\\(\\)", "\\bdebugonce\\(", "^\\s*debug\\(")) {
    for (i in grep(pat, lines)) {
      note("%s:%d debugging call left in source: %s", f, i, trimws(lines[i]))
    }
  }
}

# ---- 3. print()/cat() as logging in exported code ----------------------------
# Messages belong on the message connection so a caller can suppress them.
# cat() writes to stdout and cannot be silenced with suppressMessages().
for (f in r_files) {
  lines <- readLines(f, warn = FALSE)
  for (i in grep("^\\s*cat\\(", lines)) {
    note("%s:%d cat() used for output; use message() so callers can suppress it\n    %s",
         f, i, trimws(lines[i]))
  }
}

# ---- 4. Tabs -----------------------------------------------------------------
for (f in all_code) {
  lines <- readLines(f, warn = FALSE)
  for (i in grep("\t", lines)) {
    note("%s:%d tab character; the rest of the package uses spaces", f, i)
  }
}

# ---- 5. Trailing whitespace and missing final newline ------------------------
for (f in all_code) {
  raw <- readChar(f, file.size(f), useBytes = TRUE)
  if (nzchar(raw) && !endsWith(raw, "\n")) {
    note("%s has no trailing newline", f)
  }
  lines <- readLines(f, warn = FALSE)
  for (i in grep("[ \t]+$", lines)) {
    note("%s:%d trailing whitespace", f, i)
  }
}

# ---- 6. T / F instead of TRUE / FALSE ---------------------------------------
# T and F are ordinary variables and can be rebound; TRUE and FALSE cannot.
for (f in all_code) {
  lines <- readLines(f, warn = FALSE)
  for (i in grep("(^|[^A-Za-z0-9._])[TF]([^A-Za-z0-9._]|$)", lines)) {
    txt <- lines[i]
    if (grepl("#", txt) && regexpr("#", txt)[1] < regexpr("[^A-Za-z0-9._][TF][^A-Za-z0-9._]", txt)[1]) next
    if (grepl("(=|,|\\(|\\s)\\s*[TF]\\s*(,|\\)|$)", txt)) {
      note("%s:%d bare T/F used as a logical; write TRUE/FALSE\n    %s",
           f, i, trimws(txt))
    }
  }
}

# ---- 7. Every exported function has a test file ------------------------------
# Not proof of testing, but a missing test file is proof of its absence.
if (file.exists("NAMESPACE")) {
  ns <- readLines("NAMESPACE", warn = FALSE)
  exported <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
  test_src <- unlist(lapply(
    list.files("tests/testthat", pattern = "^test-.*\\.[Rr]$", full.names = TRUE),
    readLines, warn = FALSE))
  untested <- exported[!vapply(exported, function(fn) {
    any(grepl(fn, test_src, fixed = TRUE))
  }, logical(1))]
  for (fn in untested) {
    note("exported function `%s` is never named in tests/testthat/", fn)
  }
}

# ---- 8. Oversized source files ----------------------------------------------
for (f in r_files) {
  n <- length(readLines(f, warn = FALSE))
  if (n > 600) note("%s is %d lines; consider splitting", f, n)
}

# ---- Report ------------------------------------------------------------------
if (length(problems)) {
  cat(sprintf("Source hygiene: %d problem(s)\n\n", length(problems)))
  for (p in problems) {
    cat(" - ", p, "\n", sep = "")
    writeLines(sprintf("::error::%s", gsub("\n.*", "", p)))
  }
  quit(status = 1)
}

cat("Source hygiene: clean.\n")
