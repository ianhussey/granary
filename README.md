# Granary

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21454571.svg)](https://doi.org/10.5281/zenodo.21454571)

Granary is a large store of *granular*, item-level psychological measurement data, both self-report trait scales and attitude ratings. pooled from several public datasets into one harmonised, cleaned, and analysis-ready collection. The name is a play on the two things it is: a big **gran**ary (store) of **gran**ular item responses.

It exists to study the distributional properties of psychological measures — for example the ratio of a scale's maximum range to its observed standard deviation, and the plausibility bounds this places on standardised effect sizes — across a wide range of scales, samples, response formats, and construct types.

Every response is harmonised to a common long format and tagged with a `type`:

- **trait** — self-report personality / individual-differences scales (Bainbridge, Brysbaert, AIID scales).
- **attitude** — evaluations of specific attitude objects (AIID attitudes, not-so-simple-preferences).



## At a glance

The combined item-level dataset pools ~5.8 million item responses from ~264,900 participants across 337 scales/subscales drawn from 119 contributing samples:

| type | participants | scales | contributing samples | item responses |
|---|--:|--:|--:|--:|
| trait | ~201,800 | 135 | 104 | ~5,575,300 |
| attitude | ~109,300 | 202 | 16 | ~225,000 |
| **combined (distinct)** | **~264,900** | **337** | **119** | **~5,800,200** |

(Participant counts overlap: AIID respondents contribute to both trait and attitude records, so the distinct total is below the row sum.)



## Quick start

The dataset ships as [Apache Parquet](https://parquet.apache.org/) files under `data/combined/processed/`. You can pull them straight from GitHub without cloning the repo — the raw base URL is:

```
https://raw.githubusercontent.com/ianhussey/granary/main/data/combined/processed/
```

**Download from the shell** (`curl`; swap in `data_processed_participantlevel.parquet` / `data_processed_scalelevel.parquet` for the other levels, or a `codebook_*.xlsx` for the column dictionaries):

```sh
BASE="https://raw.githubusercontent.com/ianhussey/granary/main/data/combined/processed"
curl -L -O "$BASE/data_processed_itemlevel.parquet"
curl -L -O "$BASE/data_processed_participantlevel.parquet"
curl -L -O "$BASE/data_processed_scalelevel.parquet"
```

**R** — read directly from the URL (via [`arrow`](https://arrow.apache.org/docs/r/)); no local copy needed:

```r
library(arrow)
library(dplyr)

base <- "https://raw.githubusercontent.com/ianhussey/granary/main/data/combined/processed"

read_granary <- function(file) {
  tmp <- tempfile(fileext = ".parquet")
  download.file(file.path(base, file), tmp, mode = "wb")
  read_parquet(tmp)
}

items    <- read_granary("data_processed_itemlevel.parquet")
subjects <- read_granary("data_processed_participantlevel.parquet")
scales   <- read_granary("data_processed_scalelevel.parquet")

# e.g. all trait scales with acceptable internal consistency
scales |> filter(type == "trait", alpha >= 0.70)
```

**Python** — `pandas.read_parquet()` reads an HTTPS URL directly (needs `pyarrow` + `fsspec`):

```python
import pandas as pd

base = "https://raw.githubusercontent.com/ianhussey/granary/main/data/combined/processed"

items    = pd.read_parquet(f"{base}/data_processed_itemlevel.parquet")
subjects = pd.read_parquet(f"{base}/data_processed_participantlevel.parquet")
scales   = pd.read_parquet(f"{base}/data_processed_scalelevel.parquet")

# e.g. all trait scales with acceptable internal consistency
scales[(scales["type"] == "trait") & (scales["alpha"] >= 0.70)]
```

If you have cloned the repo instead, just point the readers at the local paths (`data/combined/processed/...`). The item-level file is large (~5.8M rows, ~11 MB); to avoid reading it all into memory, use `arrow::open_dataset()` in R or `pyarrow.parquet` with column/row-group filters in Python.

### Codebooks

Each file's columns are documented in its matching `codebook_*.xlsx`.



## Repository structure

```
granary/
├── README.md                     ← this file
├── code/
│   └── processing/
│       ├── aiid/                  ← per-source processing (AIID)
│       ├── bainbridge/            ← per-source processing (Bainbridge)
│       ├── brysbaert/             ← per-source processing (Brysbaert corpus)
│       └── combined/
│           └── processing.qmd     ← merges all sources → combined outputs
└── data/
    ├── AIID/                      ← raw/ + processed/ per source
    ├── bainbridge et al. 2022/
    ├── brysbaert et al. 2024/
    ├── not-so-simple-preferences/
    └── combined/
        └── processed/            ← the combined dataset + codebooks
```

Each source is processed independently under `code/processing/<source>/` into a harmonised long format, then merged by [`code/processing/combined/processing.qmd`](code/processing/combined/processing.qmd) into the combined dataset written to `data/combined/processed/`.



## Outputs

`processing.qmd` writes three parquet files to `data/combined/processed/`, each with an accompanying xlsx codebook describing its columns:

| file | grain | codebook |
|---|---|---|
| `data_processed_itemlevel.parquet` | one row per (participant, scale, item) response — the harmonised long format below | `codebook_itemlevel.xlsx` |
| `data_processed_participantlevel.parquet` | one row per (participant, scale, source): mean-projected sum score, POMP score, and Smithson-Verkuilen-transformed POMP score | `codebook_participantlevel.xlsx` |
| `data_processed_scalelevel.parquet` | one row per (scale, source): n, Cronbach's alpha, logical/empirical min–max, mean, SD, skew, kurtosis, and POMP mean/SD (incl. proportion of the Bhatia-Davis, 2000, max SD) | `codebook_scalelevel.xlsx` |

Approximate sizes: item-level ~5.80M rows, participant-level ~488,400 rows, scale-level 419 rows (202 of which are single-item scales, whose alpha is `NA`).



### Harmonised long format (item level)

The item-level dataset uses the columns below. Not every source populates every column; missing values are filled with `NA` on binding. The xlsx codebooks are the authoritative column reference for each file.

| column | description |
|---|---|
| `id` | participant identifier (coerced to character across sources; unique within `source`) |
| `source` | dataset / contributing-sample label |
| `scale` | scale (or attitude object) name |
| `subscale` | subscale, where defined (Bainbridge only) |
| `item` | item number within the scale |
| `response` | numeric item response (reverse-keyed items already recoded upstream) |
| `min_response` / `max_response` | theoretical response-scale bounds |
| `age`, `sex` | demographics, where available (AIID only) |
| `type` | `trait` or `attitude` |



## Derived measures

The participant- and scale-level files add a handful of measures used in the distributional analyses. Briefly:

- **Sum score (mean-projected).** Each participant is scored as their *mean* answered item projected to the full scale length (`mean_response × n_items`). For complete responders this equals the raw sum; for partial responders (who must clear the completeness gate below) it projects the partial mean to the full-scale total rather than under-counting.
- **POMP mean** (Percentage Of Maximum Possible). The sum score rescaled to `[0, 1]` as a proportion of the scale's logical range: `(score − logical_min) / (logical_max − logical_min)`.
- **Smithson-Verkuilen transformation.** `(y·(n−1) + 0.5) / n`, which nudges POMP mean scores off the exact 0/1 limits so they are admissible for Beta-based modelling.
- **POMP SD (Bhatia-Davis, 2000).** The scale's SD expressed as a proportion of the local Bhatia-Davis (2000) maximum SD given the observed mean, `SD / sqrt((max − m)(m − min))` — the tightest distribution-free ceiling on SD for a bounded scale at a given mean. Population-form SD is used in these ratios so each is bounded by 1; the reportable Bessel-corrected SD is retained separately.



## Completeness requirement

During combining, each (participant, scale) record that answered fewer than **80%** of the scale's items is dropped, applied uniformly across all sources. Because item-level missingness is stored as absent rows, completeness is measured by counting answered items per participant against the scale's item count (taken as the median answered count = full-scale length). This stops sparse partial responses from distorting sum scores, SDs, and alpha. (The Brysbaert pipeline also applies the same 80% gate upstream; re-applying it here covers Bainbridge and AIID too.)



## Reproducing the dataset

The pipeline is R, orchestrated through Quarto/R Markdown documents:

1. Run each per-source document under `code/processing/<source>/` to regenerate that source's processed files in `data/<source>/processed/`. (Raw inputs live in `data/<source>/raw/`; see each source below for provenance.)
2. Render [`code/processing/combined/processing.qmd`](code/processing/combined/processing.qmd) to merge the sources, apply the completeness gate, compute the derived measures, and write the three parquet files and their xlsx codebooks to `data/combined/processed/`.

Key R dependencies: `tidyverse`, `arrow`, `psych`, `writexl` (combined step), plus `haven` and `readxl` for reading the raw Brysbaert files.



## Sources

| source | type | participants | scales | item responses | license |
|---|---|--:|--:|--:|---|
| AIID (scales) | trait | ~46,300 | 10 | ~668,000 | CC0 |
| AIID (attitudes) | attitude | ~108,800 | 187 | ~217,600 | CC0 |
| Bainbridge et al. (2022) | trait | 1,027 | 54 | ~433,900 | CC BY 4.0 |
| Brysbaert et al. (2024) | trait | ~154,500 | 71 | ~4,473,600 | CC BY-NC-SA 4.0 |
| not-so-simple-preferences | attitude | 489 | 15 | ~7,300 | CC BY 4.0 |



### AIID — Attitudes, Identities, and Individual Differences

- **Type:** both traits (`aiid_scales`) and attitudes (`aiid_attitudes`).
- **Description:** A large web-based study run through Project Implicit, in which participants completed explicit and implicit measures of their attitudes towards a wide range of objects, alongside a battery of individual-differences scales and demographics. This project uses the confirmatory subset.
- **Split into two derived datasets:**
  - `aiid_scales` — individual-differences trait scales (~46,300 participants, 10 scales, ~668,000 item responses). Scales include RSE (self-esteem), NFC (need for cognition), RWA (authoritarianism), PNS (need for structure), BIDR (socially desirable responding), and others.
  - `aiid_attitudes` — single-target attitude ratings (~108,800 participants, 187 attitude objects, ~217,600 responses). Objects range across brands, people, social groups, and concepts (e.g. Apple, Astrology, African Americans, Atheism).
- **Files:** `data/AIID/raw/AIID_subset_confirmatory.RData`; processed parquet files under `data/AIID/processed/`.
- **Source:** https://osf.io/pcjwf
- **Reference:** Hussey, I., Nosek, B. et al. (2019). The Attitudes, Identities, and Individual Differences (AIID) dataset: A massively multivariate dataset of implicit and explicit measures. https://osf.io/pcjwf
- **License:** CC0.



### Bainbridge et al. (2022)

- **Type:** trait.
- **Description:** Item-level responses to a large battery of commonly used psychological trait scales, collected to evaluate the Big Five as an organising framework for personality measurement. ~1,027 participants across 54 scales/subscales (~433,900 item responses), including the BFI and IPIP Big Five domains plus scales such as grit, hope, optimism, self-control, self-esteem, empathy subscales, and the Dark Triad.
- **Files:** raw `s1.csv`, `s2.csv`, `s3.csv` (post-exclusion data from Bainbridge et al.'s own processing), `label.rds` (scale items), and `scalenames.rds` (scale abbreviations → full names), all extracted from the authors' archives. See `data/bainbridge et al. 2022/raw/notes.txt`.
- **Source:** Files downloaded from OSF: <https://osf.io/f9hmg/>.
- **Reference:** Bainbridge, T. F., Ludeke, S. G., & Smillie, L. D. (2022). Evaluating the Big Five as an organizing framework for commonly used psychological trait scales. *Journal of Personality and Social Psychology*. doi: https://doi.org/10.1037/pspp0000395
- **License:** CC BY 4.0.



### Brysbaert et al. (2024)

- **Type:** trait.
- **Description:** A large, curated collection of raw datasets for many individual-differences questionnaires, contributed by numerous labs and gathered to study measurement properties across scales and samples. In this project it contributes ~154,500 participants across 71 scales (~4.47 million item responses) — the largest source by far. The catalog (`data/brysbaert et al. 2024/processed/brysbaert_catalog.csv`) lists 135 contributing data files spanning constructs such as BIS/BAS, DASS-21, depression (BDI-II), DERS emotion regulation, FFMQ mindfulness, impulsivity (UPPS/BIS), moral foundations, optimism, perfectionism, self-control, and time perspective, among others.
- **Source:** https://osf.io/e3dmh
- **Note on `source`:** unlike the other datasets, the `source` column here labels the *contributing sample/author* (e.g. Binter, Racine, Panayiotou) rather than a single "Brysbaert" label, reflecting the multi-lab structure of the collection.
- **Exclusions:** the Brysbaert corpus catalogs 135 contributing data files, but not all survive processing (see `code/processing/brysbaert/extract_brysbaert_functions.R`, and the `brysbaert_load_log.csv` / `brysbaert_range_check.csv` diagnostics). Three filters are applied, in order:
  1. **Datasets marked invalid in the catalog (10 files, dropped before loading).** These could not be reliably parsed or mapped to a known scale — e.g. an item structure that couldn't be resolved, a file duplicating another source, or a response format that didn't match the instrument. The excluded files are: `Beliefs_Barnby.csv` (Beliefs), `Bainbridge_s2_IRI.csv` (Emotional intelligence — duplicate of the Bainbridge source), `austria.sav` (FFMQ), `Estudillo_2021_PI20_JCP.csv` and `Estudillo_2021_PI20_PEERJ.csv` (Face recognition), `Dragan_handedness.dat` (Handedness), `Steiner.xlsx` (Impulsivity), `Perfectionism_Kacar-Basaran.sav` (Perfectionism), `data_RIASEC_openpsychometrics.csv` (Personality/RIASEC), and `RST_Sozer.sav` (Reinforcement sensitivity).
  2. **Per-participant quality gate.** Within each remaining dataset, obvious missing-data sentinels (values >10 outside the response range, e.g. -99/999) are set to missing; a participant with any *plausible-but-out-of-range* response (e.g. a 6 on a 1–5 scale, signalling a different scale variant) is then dropped from that dataset. Additionally, a participant is scored on a (sub)scale only if they answered ≥80% of its items (`MIN_ITEM_COMPLETENESS`), matching the completeness requirement used across all sources.
  3. **Whole-dataset quality gate (21 files, dropped at write time).** A dataset is discarded entirely if ≥10% of its participants tripped the out-of-range check above — a strong signal that the catalog's recorded response range is wrong for that file, so its scores aren't comparable. The dropped files include `ICD11_Carnovale` (100% out-of-range), `Satchell_RST-PQ` (99%), `MoralF_Harper` (97%), `validation_sample_Wuellhorst` (97%), `EI_Robinson` (92%), both `BSC_Sjastad1`/`BSC_Sjastad2` self-control samples (~85%), `Final_COVIDiSTRESS_Vol2_cleaned` (85%), `Lardone` and `Weinstein` (loneliness), `MAIA_Randelovic`, `AES_Demetrovics`/`AES_Demetrovics2`, `Big_Five_Mezquita`, `Martingano_IRI`, `Optimism_Coelho_Bra`/`Optimism_Coelho_UK`, `Eben2020`, `SDI-2_Jones`, `QEWB_Ishii`, and `EI_Brienza` (see `brysbaert_load_log.csv` for the full list and exact proportions).
  - **Net effect on scales:** most affected constructs retain coverage from other contributing samples (e.g. moral foundations survives via `Zakharin` after `Harper` is dropped). A few constructs are removed entirely because their only contributing dataset was dropped: **Beliefs** and **RIASEC** (invalid), and **COVIDiSTRESS Covid-19 stress**, **QEWB eudaimonic wellbeing**, **SDI-2 sexual desire**, and **PiCD personality disorders** (whole-dataset quality gate). After all filters, the item-level parquet retains **102 contributing samples across 71 scales/subscales**.
- **Reference:** Brysbaert, M., et al. (2024). Questioning the exclusive focus on the Hu and Bentler norms in factor analysis: Practice-oriented Likert scale indicators based on an analysis of 161 datasets. https://doi.org/10.31234/osf.io/m72w8
- **License:** CC BY-NC-SA 4.0 (Attribution–NonCommercial–ShareAlike). See `data/brysbaert et al. 2024/license.txt`. Reuse must credit the creators, is restricted to non-commercial purposes, and derivatives must be shared under the same terms.



### not-so-simple-preferences

- **Type:** attitude.
- **Description:** Replication, and extension of Balcetis & Dunning (2010) Study 3b pretest as a maximum positive control, to study very large Cohen's d between two attitude objects (e.g., chocolate vs. poop). A study of evaluative ratings of attitude objects on 1–7 scales, including the "classic" poop and chocolate targets plus objects such as pedophile, love, murder, vacation, racist, honest/dishonest, and several paired stereotype items, alongside embedded attention checks. 489 participants after exclusions. Each rated object is treated as its own single-item scale in the combined data.
- **Files:** `data/not-so-simple-preferences/processed/data_processed_after_exclusions.csv`.
- **Source:** <https://github.com/ianhussey/not-so-simple-preferences>
- **Reference:** Hussey, I., & Cummins, J. (2025). (Not so) simple preferences. https://github.com/ianhussey/not-so-simple-preferences
- **License:** CC BY 4.0.



## Notes and caveats

- **`type` collapses a lot of heterogeneity.** "trait" spans everything from Big Five domains to clinical symptom checklists; "attitude" spans single-item object ratings. Filter on `scale` / `source` for anything finer.
- **Single-item attitude scales have no internal consistency.** They get `alpha = NA` at the scale level and their SD-relative measures should be read accordingly.
- **Positive-control items.** The not-so-simple-preferences source carries its two attention-check items into the combined dataset (as single-item "attitude" scales), matching the upstream processing. These are included as maximum positive-control variables. Remove them if they should not be treated as attitude variables for your study.
- **Reverse keying.** Items are stored already correctly keyed (Brysbaert items are reverse-scored empirically upstream; Bainbridge and AIID arrive correctly keyed), so a plain sum score / alpha is meaningful.



## Citing Granary

If you use this compiled dataset, please cite the original sources for the data you use (see each source above) in addition to Granary itself. Because the combined dataset embeds Brysbaert et al. (2024) data, the compilation as a whole inherits its CC BY-NC-SA 4.0 terms.

Suggested citation:

Hussey, I. (2026). Granary: A very large item-level open dataset of psychological traits and attitudes. https://github.com/ianhussey/granary doi: [10.5281/zenodo.21454571](https://doi.org/10.5281/zenodo.21454571)



## Licensing

(c) Ian Hussey (2026)

All code is MIT licensed.

All text and images are CC-BY 4.0 (see above suggested citation).

Licensing of data varies by source dataset. The source datasets carry different licenses (CC0, CC BY 4.0, and CC BY-NC-SA 4.0, as listed per source above). The combined dataset is a derivative that includes the Brysbaert corpus, so redistribution of the combined product must honour the most restrictive terms in the mix, i.e., **CC BY-NC-SA 4.0**: attribute the creators, non-commercial use only, and share derivatives under the same license. Citations for the individual datasets are above. If you need broader terms, work only with the individual sources whose licenses permit it (e.g. the CC0 AIID data).

