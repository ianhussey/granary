# v1.0.1

### Fixed

- Two source scripts in `data/brysbaert et al. 2024/raw/` (`Optimism/analysis optimism.R` and `Personality/analysis personality tests.R`) recorded a paper's provenance using a full ScienceDirect download link rather than its DOI. These links carry a long query string of AWS pre-signed request parameters, which automated secret-detection tooling flags as leaked credentials. The links are now truncated to the plain article URL. The parameters they contained were temporary download tokens issued by the publisher in June 2023, scoped to expire after five minutes, and had long since lapsed.

### Notes for existing users

- Removing the parameters from the published history required rewriting the repository's commit history, so all commit hashes have changed and the `v1.0.0` tag now points to a new hash. Existing clones and forks will not fast-forward — please re-clone rather than pull.
- No data files, harmonisation code, or analysis outputs were altered. The datasets released as v1.0.0 are byte-for-byte identical in v1.0.1, and results reported against v1.0.0 remain reproducible.
- Only the GitHub repository was rewritten. The Zenodo deposit archiving v1.0.0 is immutable, so the copy preserved there still contains the original links.
