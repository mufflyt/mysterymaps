# Fail the job on any R CMD check NOTE that is not explicitly allowed.
#
# r-lib/actions/check-r-package can fail on notes, but that is all-or-nothing:
# a handful of NOTEs on a CI runner are environmental rather than defects
# ("unable to verify current time" behind a proxy, the mtime skew note on a
# fresh checkout). Setting error-on to "note" therefore makes a nightly that is
# permanently red, which is a nightly nobody reads.
#
# So: allow those by pattern, fail on everything else. New allowances go in
# .github/allowed-notes.txt with a comment saying why, which forces the
# question "is this really environmental?" to be answered in a review.

allowed_file <- ".github/allowed-notes.txt"
allowed <- if (file.exists(allowed_file)) {
  pat <- readLines(allowed_file, warn = FALSE)
  pat <- trimws(pat)
  pat[nzchar(pat) & !startsWith(pat, "#")]
} else {
  character(0)
}

# check-r-package writes to check/ by default; the matrix job may use a
# different directory name, so take whatever *.Rcheck exists.
roots <- c("check", ".")
dirs <- unlist(lapply(roots, function(r) {
  if (!dir.exists(r)) return(character(0))
  list.files(r, pattern = "\\.Rcheck$", full.names = TRUE)
}))
dirs <- dirs[dir.exists(dirs)]

if (!length(dirs)) {
  cat("No .Rcheck directory found; nothing to gate.\n")
  quit(status = 0)
}

logs <- file.path(dirs, "00check.log")
logs <- logs[file.exists(logs)]
if (!length(logs)) {
  cat("No 00check.log found; nothing to gate.\n")
  quit(status = 0)
}

# Split the log into check entries. Each begins with "* checking ..." and the
# result line ends "... NOTE" / "... WARNING" / "... OK".
notes <- character(0)
for (log in logs) {
  txt <- readLines(log, warn = FALSE)
  starts <- grep("^\\* ", txt)
  for (i in seq_along(starts)) {
    from <- starts[i]
    to <- if (i < length(starts)) starts[i + 1L] - 1L else length(txt)
    block <- txt[from:to]
    if (grepl("\\.\\.\\. NOTE\\s*$", block[1]) || identical(trimws(block[1]), "* checking ... NOTE")) {
      notes <- c(notes, paste(block, collapse = "\n"))
    } else if (any(grepl("^NOTE$", trimws(block)))) {
      notes <- c(notes, paste(block, collapse = "\n"))
    }
  }
}

if (!length(notes)) {
  cat("R CMD check produced no NOTEs.\n")
  quit(status = 0)
}

is_allowed <- function(note) {
  any(vapply(allowed, function(p) grepl(p, note, perl = TRUE), logical(1)))
}

verdicts <- vapply(notes, is_allowed, logical(1))
unexpected <- notes[!verdicts]

cat(sprintf("R CMD check produced %d NOTE(s); %d allowed, %d unexpected.\n\n",
            length(notes), sum(verdicts), length(unexpected)))

if (sum(verdicts)) {
  cat("--- Allowed (environmental) ---\n")
  cat(paste(notes[verdicts], collapse = "\n\n"), "\n\n")
}

if (length(unexpected)) {
  cat("--- UNEXPECTED ---\n")
  cat(paste(unexpected, collapse = "\n\n"), "\n")
  writeLines(sprintf("::error::%d unexpected R CMD check NOTE(s)", length(unexpected)))
  quit(status = 1)
}

cat("Every NOTE is on the allowlist.\n")
