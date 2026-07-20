# Validate derived REVERSE_KEYS: for every (scale, source), apply the keys to
# the raw slice, rebuild per-subscale sumscores, and check that the keyed
# alpha equals the psych::alpha(check.keys=TRUE) optimum (i.e. the keying is
# internally optimal -> the SD is correct, direction aside). Also check that
# every item-rest correlation is >= a small negative tolerance.

suppressMessages(suppressWarnings(source("extract_brysbaert_functions.R")))
suppressMessages({library(dplyr)})
klist <- readRDS("/tmp/klist.rds")

raw_alpha <- function(m) {
  m <- as.matrix(m); p <- ncol(m)
  v <- var(m, use = "pairwise.complete.obs")
  (p / (p - 1)) * (1 - sum(diag(v)) / sum(v))
}
min_item_rest <- function(m) {
  m <- as.matrix(m); p <- ncol(m); tot <- rowSums(m)
  min(vapply(seq_len(p), function(j)
    suppressWarnings(cor(m[, j], tot - m[, j], use = "pairwise.complete.obs")),
    numeric(1)), na.rm = TRUE)
}

active <- subset(brysbaert_catalog, valid)
rows <- list()
for (i in seq_len(nrow(active))) {
  row <- active[i, ]
  gi <- tryCatch(get_dataset_items(row$scale_folder, row$data_file, reverse = FALSE),
                 error = function(e) NULL)
  if (is.null(gi)) next
  items <- gi$items
  rev_pos <- klist[[row$data_file]]
  if (!is.null(rev_pos)) {
    items[, rev_pos] <- (gi$min_response + gi$max_response) - items[, rev_pos]
  }
  mapping <- SUBSCALE_MAPPINGS[[row$data_file]]
  if (is.null(mapping))
    mapping <- setNames(list(seq_len(ncol(items))),
                        resolve_instrument(row$scale_folder, row$data_file))
  for (sub in names(mapping)) {
    m <- items[, mapping[[sub]], drop = FALSE]
    mc <- m[stats::complete.cases(m), , drop = FALSE]
    if (nrow(mc) < 10 || ncol(mc) < 2) next
    a_keyed <- raw_alpha(mc)
    a_opt <- suppressWarnings(psych::alpha(as.data.frame(mc), check.keys = TRUE,
                                           warnings = FALSE))$total$raw_alpha
    rows[[length(rows) + 1]] <- data.frame(
      data_file = row$data_file, subscale = sub, n_items = ncol(mc),
      a_keyed = round(a_keyed, 3), a_opt = round(a_opt, 3),
      gap = round(a_opt - a_keyed, 3),
      min_ir = round(min_item_rest(mc), 3))
  }
}
res <- dplyr::bind_rows(rows)
cat("subscales validated:", nrow(res), "\n")
cat("alpha matches optimum (gap < 0.01):", sum(res$gap < 0.01), "/", nrow(res), "\n")
cat("all item-rest >= -0.05:", sum(res$min_ir >= -0.05), "/", nrow(res), "\n\n")
cat("=== FAILURES: alpha gap >= 0.01 (keying not optimal) ===\n")
print(subset(res, gap >= 0.01)[order(-subset(res, gap >= 0.01)$gap), ], row.names = FALSE)
cat("\n=== FAILURES: min item-rest < -0.05 (a reverse item slipped through) ===\n")
print(subset(res, min_ir < -0.05)[, c("data_file","subscale","n_items","a_keyed","min_ir")], row.names = FALSE)
