# Regenerate the processed Brysbaert parquets with reverse-keying applied.
# Mirrors the write logic in processing.Rmd. Run from this directory.
suppressMessages(suppressWarnings(source("extract_brysbaert_functions.R")))
suppressMessages({library(dplyr); library(arrow); library(tidyr)})

out_dir <- file.path(dirname(base_dir), "processed")

clean_sources <- brysbaert_load_log |>
  dplyr::mutate(prop_excluded = dplyr::if_else(
    is.na(n_total) | n_total == 0L, NA_real_, n_excluded / n_total)) |>
  dplyr::filter(ok, !is.na(prop_excluded), prop_excluded < 0.10) |>
  dplyr::pull(source) |>
  unique()

sumscores_out <- dplyr::filter(dat_brysbaert_sumscores, source %in% clean_sources)
clean_sources_short <- vapply(clean_sources, clean_source, character(1), USE.NAMES = FALSE)
long_out <- dplyr::filter(dat_brysbaert_long, source %in% clean_sources_short)

arrow::write_parquet(sumscores_out,
  file.path(out_dir, "data_processed_brysbaert_sumscores.parquet"))
arrow::write_parquet(long_out,
  file.path(out_dir, "data_processed_brysbaert_itemlevel_long.parquet"))

cat("wrote sumscores:", nrow(sumscores_out), "rows; long:", nrow(long_out), "rows\n\n")

# Spot-check: scales that were broken before should now have positive item
# correlations / high alpha in the regenerated long data.
chk <- function(scale_, source_) {
  w <- long_out |> dplyr::filter(scale == scale_, source == source_) |>
    dplyr::select(id, item, response) |>
    tidyr::pivot_wider(names_from = item, values_from = response) |> dplyr::select(-id)
  a <- suppressWarnings(psych::alpha(as.data.frame(w), warnings = FALSE))$total$raw_alpha
  cat(sprintf("  %-26s %-12s alpha(raw, no check.keys) = %.3f\n", scale_, source_, a))
}
cat("post-reversal alpha (computed WITHOUT check.keys; should be high now):\n")
chk("TIPI extraversion", "Coelho_UK")
chk("TIPI neuroticism", "Coelho_UK")
chk("BFI-2 extraversion", "Gallardo-Pujol")
chk("STAI-T trait anxiety", "Sundelin")
chk("SDO social dominance", "Perkins")
chk("BDI-II depression", "Smith")   # no reverse items: should be unchanged/high
