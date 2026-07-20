# Derive reverse-key positions for each Brysbaert dataset.
#
# The Brysbaert lab analysis scripts mostly do NOT reverse-code (they run CFA on
# raw items and let loadings be negative); only a few reverse explicitly and
# idiosyncratically. So reverse keys here are derived EMPIRICALLY per
# (data_file, subscale) by iterative item-rest sign analysis, anchored so the
# majority (forward) items stay positive, then cross-checked against canonical
# published keys and against the lab scripts where they do reverse.
#
# Output: for each data_file, the union of positions WITHIN THE SLICED ITEM
# COLUMNS that should be reverse-scored (the coordinate system used by
# SUBSCALE_MAPPINGS and the planned REVERSE_KEYS). Printed as R literals plus a
# per-subscale diagnostic table.

suppressMessages(suppressWarnings(
  source("extract_brysbaert_functions.R")
))
suppressMessages({library(dplyr)})

# Optimal internal keying. Seed with the sign of each item's first-principal-
# component loading (robust even at a 50/50 split, where greedy item-rest keying
# gets frustrated), then refine by flipping any item whose corrected item-rest
# correlation is negative, iterating to a fixed point. The result is the
# alpha-maximising key (matches psych::alpha(check.keys=TRUE)); its global sign
# is anchored forward-majority but direction is irrelevant to SD/alpha.
derive_key <- function(m) {
  m <- as.matrix(m)
  p <- ncol(m)
  pc <- tryCatch(prcomp(m, scale. = TRUE, center = TRUE)$rotation[, 1],
                 error = function(e) rep(1, p))
  if (sum(pc > 0) < sum(pc < 0)) pc <- -pc       # forward-majority anchor
  key <- ifelse(pc < 0, -1L, 1L)
  for (iter in 1:50) {                            # refine PC1 seed to optimum
    changed <- FALSE
    tot <- as.numeric(m %*% key)
    for (j in seq_len(p)) {
      rest <- tot - key[j] * m[, j]
      r <- suppressWarnings(cor(key[j] * m[, j], rest, use = "pairwise.complete.obs"))
      if (is.finite(r) && r < 0) { key[j] <- -key[j]; changed <- TRUE }
    }
    if (!changed) break
  }
  key
}

raw_alpha <- function(m) {
  m <- as.matrix(m); p <- ncol(m)
  v <- var(m, use = "pairwise.complete.obs")
  (p / (p - 1)) * (1 - sum(diag(v)) / sum(v))
}

active <- subset(brysbaert_catalog, valid)
rows <- list(); klist <- list()

for (i in seq_len(nrow(active))) {
  row <- active[i, ]
  gi <- tryCatch(get_dataset_items(row$scale_folder, row$data_file, reverse = FALSE),
                 error = function(e) NULL)
  if (is.null(gi)) next
  items <- gi$items
  mapping <- SUBSCALE_MAPPINGS[[row$data_file]]
  if (is.null(mapping)) {
    mapping <- setNames(list(seq_len(ncol(items))),
                        resolve_instrument(row$scale_folder, row$data_file))
  }
  rev_slice <- integer(0)
  for (sub in names(mapping)) {
    pos <- mapping[[sub]]
    m <- items[, pos, drop = FALSE]
    # need complete-ish columns; drop rows with any NA for the keying math
    mc <- m[stats::complete.cases(m), , drop = FALSE]
    if (nrow(mc) < 10 || ncol(mc) < 2) next
    a_raw <- raw_alpha(mc)
    key <- derive_key(mc)
    flipped_local <- which(key == -1L)
    if (length(flipped_local) == 0) {
      rows[[length(rows)+1]] <- data.frame(data_file=row$data_file, subscale=sub,
        n_items=ncol(mc), a_raw=round(a_raw,3), a_keyed=round(a_raw,3),
        n_flip=0L, flip_local="", flip_slice="", apply=FALSE)
      next
    }
    mk <- mc; mk[, flipped_local] <- (gi$min_response + gi$max_response) - mk[, flipped_local]
    a_key <- raw_alpha(mk)
    apply_it <- (a_key - a_raw) > 0.005
    flip_slice <- pos[flipped_local]
    rows[[length(rows)+1]] <- data.frame(data_file=row$data_file, subscale=sub,
      n_items=ncol(mc), a_raw=round(a_raw,3), a_keyed=round(a_key,3),
      n_flip=length(flipped_local),
      flip_local=paste(flipped_local, collapse=","),
      flip_slice=paste(sort(flip_slice), collapse=","),
      apply=apply_it)
    if (apply_it) rev_slice <- c(rev_slice, flip_slice)
  }
  rev_slice <- sort(unique(rev_slice))
  if (length(rev_slice) > 0) klist[[row$data_file]] <- rev_slice
}

diag <- dplyr::bind_rows(rows)
write.csv(diag, "/tmp/derived_keys_diag.csv", row.names = FALSE)

saveRDS(klist, "/tmp/klist.rds")
lit <- c("REVERSE_KEYS <- list(",
         vapply(names(klist), function(df)
           sprintf('  "%s" = c(%s),', df, paste(klist[[df]], collapse = ", ")),
           character(1)))
lit[length(lit)] <- sub(",$", "", lit[length(lit)])   # drop trailing comma
lit <- c(lit, ")")
writeLines(lit, "/tmp/reverse_keys_generated.R")

cat("\n================ REVERSE_KEYS (R literals) ================\n")
for (df in names(klist)) {
  cat(sprintf('  "%s" = c(%s),\n', df, paste(klist[[df]], collapse = ", ")))
}
cat("\n# datasets needing reversal:", length(klist), "\n")
cat("\n=== subscales where keying flipped >0 but NOT applied (alpha guard) ===\n")
print(subset(diag, n_flip > 0 & !apply)[, c("data_file","subscale","n_items","a_raw","a_keyed","n_flip")], row.names=FALSE)
