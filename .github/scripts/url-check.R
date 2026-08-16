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
