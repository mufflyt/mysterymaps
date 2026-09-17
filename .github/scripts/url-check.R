# Every URL in the package must resolve, except the ones that cannot.
#
# urlchecker reports 404s from private repositories exactly as it reports dead
# links, because from an anonymous checker they are the same response. They are
# not the same problem, so the private ones are listed explicitly in
# .github/allowed-urls.txt with a reason.

allowed_file <- ".github/allowed-urls.txt"
allowed <- if (file.exists(allowed_file)) {
  x <- trimws(readLines(allowed_file, warn = FALSE))
  x[nzchar(x) & !startsWith(x, "#")]
} else character(0)

res <- urlchecker::url_check(".")

# ---------------------------------------------------------------------------
# urlchecker does not read _pkgdown.yml, and that is where the site says where
# it lives.
#
# On 2026-08-18 https://mufflyt.github.io/mysterymaps returned 404 -- the
# canonical URL on line 1 of _pkgdown.yml, dead. Every pkgdown run had been
# green: the site built, deployed to gh-pages, and reported success. GitHub
# Pages had simply never been enabled on the repository, so nothing served it.
# This gate did not notice because urlchecker::url_check() covers Rd,
# DESCRIPTION and README -- not the site config.
#
# The URL a package publishes as its own home is the one most likely to be
# read and the one nobody re-checks. It belongs in the same gate as the rest.
# ---------------------------------------------------------------------------
extra_files <- c("_pkgdown.yml", "CITATION.cff", "codemeta.json")
extra_files <- extra_files[file.exists(extra_files)]
# NOT unlist(lapply(...)): that flattens the data frames to an atomic vector
# and rbind then fails with "second argument must be a list". Same mistake was
# made in pkgdown-integrity.R; keeping the list intact is the fix in both.
extra <- lapply(extra_files, function(f) {
  txt <- readLines(f, warn = FALSE)
  m <- regmatches(txt, gregexpr("https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+", txt))
  u <- unique(sub("[.,;:)\"'>]+$", "", unlist(m)))
  if (!length(u)) return(NULL)
  data.frame(File = f, URL = u, stringsAsFactors = FALSE)
})
extra <- do.call(rbind, Filter(Negate(is.null), extra))

if (!is.null(extra) && NROW(extra)) {
  already <- if (NROW(res)) as.data.frame(res)$URL else character(0)
  extra <- extra[!extra$URL %in% already, , drop = FALSE]
}

if (!is.null(extra) && NROW(extra)) {
  cat(sprintf("Checking %d additional URL(s) from %s ...\n",
              NROW(extra), paste(unique(extra$File), collapse = ", ")))
  status <- vapply(extra$URL, function(u) {
    h <- tryCatch(curlGetHeaders(u, redirect = TRUE, timeout = 20),
                  error = function(e) NULL)
    if (is.null(h)) return(NA_integer_)
    code <- attr(h, "status")
    if (is.null(code)) NA_integer_ else as.integer(code)
  }, integer(1), USE.NAMES = FALSE)
  extra$Status <- status
  extra$Message <- ifelse(is.na(status), "no response", paste("HTTP", status))
  failed <- extra[is.na(extra$Status) | extra$Status >= 400, , drop = FALSE]
  if (NROW(failed)) {
    res <- rbind(
      if (NROW(res)) as.data.frame(res)[, c("File", "URL", "Status", "Message")] else NULL,
      failed[, c("File", "URL", "Status", "Message")])
  } else {
    cat("  all resolved.\n")
  }
}

if (!NROW(res)) {
  cat("Every URL resolved.\n")
  quit(status = 0)
}

res <- as.data.frame(res)
is_allowed <- res$URL %in% allowed

if (any(is_allowed)) {
  cat("Known-unreachable URLs (allowlisted):\n")
  print(res[is_allowed, c("URL", "Status", "Message"), drop = FALSE])
  cat("\n")
}

bad <- res[!is_allowed, , drop = FALSE]
if (!NROW(bad)) {
  cat("All remaining URLs resolved.\n")
  quit(status = 0)
}

cat("Unreachable URLs:\n")
print(bad)
for (i in seq_len(NROW(bad))) {
  writeLines(sprintf("::error file=%s::%s -> %s",
                     bad$File[i], bad$URL[i], bad$Message[i]))
}
quit(status = 1)
