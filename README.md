# Estimating TSH Out-of-Range in Levothyroxine-Treated Patients: Machine Learning Pipeline

Code accompanying:

> Ettleson MD, et al. *Using supervised machine learning to 
  classify and identify clinical features associated with suboptimal 
  levothyroxine treatment.* Journal of Clinical Endocrinology & Metabolism (submitted). DOI once available

The pipeline uses supervised machine learning (elastic net, random forest, XGBoost) to classify TSH dysregulation in levothyroxine (LT4)-treated patients from routinely collected EHR data, and uses SHAP to interpret the models. The framing is knowledge generation and clinical discrimination in a cross-sectional design (predictors are concurrent with the index TSH draw), not prospective forecasting or deployment.

## Data availability

The patient-level datasets (`ds.full.csv`, `ds.reduced.csv`) come from the University of Chicago Medicine electronic health record and **cannot be shared** because of patient privacy regulations. Researchers interested in data access should contact the corresponding author.

The code is nonetheless fully reproducible *with your own data*: [`DATA_SPECIFICATION.md`](DATA_SPECIFICATION.md) describes the exact format, the pipeline validates the input on startup, and [`make_synthetic_data.R`](make_synthetic_data.R) generates correctly formatted random data for testing.

## Repository contents

| File | Description |
|---|---|
| `ML_pipeline_07_for_repo.Rmd` | The complete analysis pipeline (primary + sensitivity analyses, tables, figures) |
| `DATA_SPECIFICATION.md` | Required input format (columns, coding, hard-coded assumptions, checklist) |
| `make_synthetic_data.R` | Generates synthetic `ds.full.csv` / `ds.reduced.csv` for testing (random numbers; no patient information) |
| `install_packages.R` | Installs the required R packages |
| `Table_1_revised.docx` | Baseline characteristics (generated separately; not produced by the pipeline) |
| *(supplemental tables and figures)* | Online supplemental material for the manuscript |
| `LICENSE` | MIT |

## Study design in brief

| | |
|---|---|
| **Outcomes** | TSH out of range (`TSH_OOR_1`), above range (`TSH_high`), below range (`TSH_low`) |
| **Primary dataset** | *Comprehensive* (`ds.full`; N = 3,977; 71 predictors incl. laboratory values and vital signs) |
| **Sensitivity datasets** | *Reduced* (`ds.reduced`; N = 12,045; 48 predictors) |
| **Other sensitivity analyses** | Wide TSH bounds (0.1–10.0 mIU/L); stratification by time from LT4 order to TSH draw (≤ 90 vs > 90 days) in both datasets |
| **Models** | Elastic net (`glmnet` via `caret`), random forest (`ranger`), XGBoost |
| **Interpretability** | SHAP: `kernelshap` for elastic net and random forest (sampling-based approximation); exact TreeSHAP for XGBoost |
| **Model comparison** | Pairwise DeLong tests on AUC (3 pairs × 3 outcomes) with Holm correction |

Methodological choices worth knowing about:

- **Locked decision thresholds.** The Youden-optimal threshold is derived from held-out cross-validation predictions on the *training* set and applied unchanged to the test set, avoiding circularity.
- **Conditional class weighting.** Every model type applies inverse-frequency weighting if, and only if, the event rate in that training split is below 5% (`CLASS_WEIGHT_THRESHOLD`). Brier scores for weighted cells are corrected with post-hoc Platt scaling; AUC and sensitivity/specificity are unaffected.
- **Single seed, single split.** An 80/20 stratified split with seed 42; results on small test-set event counts have correspondingly wide confidence intervals.

## Quick start

### 1. Install

Requires R and RStudio (or `rmarkdown`).

```r
source("install_packages.R")
```

### 2a. Try it on synthetic data (recommended first step)

```r
source("make_synthetic_data.R")                 # writes ./synthetic_data/
Sys.setenv(LT4_DATA_DIR = "synthetic_data")     # point the pipeline at it
```

In `ML_pipeline_07_for_repo.Rmd`, set `DEV_MODE <- TRUE` in the *configuration* chunk (fewer CV folds, smaller SHAP samples) and run the chunks top to bottom. Results from synthetic data are meaningless (model performance will be near chance); this only confirms that your environment works.

### 2b. Run on your own data

1. Prepare `ds.full.csv` and `ds.reduced.csv` per [`DATA_SPECIFICATION.md`](DATA_SPECIFICATION.md) and place them next to the Rmd (or set `LT4_DATA_DIR`).
2. Run with `DEV_MODE <- TRUE` first to check everything works end to end.
3. Set `DEV_MODE <- FALSE` for the full analysis.

The pipeline is meant to be run **interactively, chunk by chunk, top to bottom**: later chunks (tables, figures, Word output) depend on objects created by earlier model-fitting chunks. If the CSVs are absent, knitting the document renders the code only.

### Runtime

The full run is computationally heavy. SHAP estimation for the elastic net and random forest dominates; on an Apple M4 Max with parallelization it takes on the order of hours. Fitted models and SHAP values are cached, so an interrupted run resumes without refitting. Delete the cache directory to force a refit (for example after changing the seed, the data, or any hyperparameter).

## Outputs

Written to the working directory:

| Output | Content |
|---|---|
| `manuscript_ML_results.docx`, `ROC_curves_primary.docx`, `supplemental_SHAP.docx` | Primary analysis tables and figures |
| `DeLong_AUC_comparisons.docx` | Pairwise AUC comparisons with Holm-adjusted p-values |
| `supplemental_gap_stratification.docx` | Reduced-dataset stratified analysis |
| `sensitivity_wide_bounds.docx` | Wide-bounds analysis |
| `Figures_2_3_4_v2.docx`, `Supplemental_Figures_v2.docx`, `Supplemental_Tables_3_4_5.docx` | Manuscript figures and supplemental tables |
| `Figure_2_ROC.png`, `Figure_3_SHAP_bar.png`, `Figure_4_SHAP_beeswarm.png`, `SuppFig*.png` | Individual figure files (300 dpi) |

## Reproducibility notes

- **Package versions.** `sessionInfo()` is printed at the end of the pipeline. For exact pinning, use `renv` (instructions in `install_packages.R`).
- **Random seeds.** A seed (42) is set before each fitting call. However, caret's parallel backend does not give workers reproducible seeds, so re-fitting from scratch (random forest in particular) may differ from the reported values in the later decimal places.
- **Parallelization.** `kernelshap` parallelizes through the `future` package (`plan(multisession)`); `doParallel` has no effect on it. On Windows the caret cluster uses PSOCK instead of FORK.
- **Fonts.** Figures use Arial. If it is not installed, ggplot2 substitutes a default font and figure appearance will differ.
- **Privacy.** Cached model objects (`cache/`, `cache_dev/`) embed the training data. They are excluded by `.gitignore`; never commit them or share them outside your data-governance boundary.
- **Development runs.** `DEV_MODE` writes to `cache_dev/` so a fast validation run can never be loaded into a reported run.

## Testing status

Stated plainly so users know what has been verified:

- **Full pipeline, from cached results (authors' data).** The complete pipeline, including the thresholding, evaluation, DeLong/Holm tests, tables, SHAP figures and Word outputs, was run end to end without errors on the manuscript data, loading the saved model and SHAP objects from the manuscript analysis. Table 2 reproduced the manuscript values.
- **Input validation and model fitting (synthetic data).** The input checks, data preparation, train/test splitting, class-weight logic, elastic net and random forest fitting (including the class-weighted path), threshold-locking and Platt recalibration were exercised against synthetic data. The validator was confirmed to reject malformed input.
- **Not independently re-run.** Fitting the XGBoost models and computing SHAP values from scratch were not repeated for this release; those stages are unchanged from the analysis used for the manuscript. Because caret's parallel backend does not seed workers (see above), a from-scratch refit may differ from the reported values in the later decimal places.

## AI disclosure

This pipeline was developed with assistance from Claude (Anthropic, San Francisco, CA), a large language model-based AI tool, which contributed to pipeline architecture, code generation, and iterative debugging. All analytical decisions, model specifications, and interpretations were made by the authors (Resnik & Hosseini, 2026, *Accountability in Research*, doi:10.1080/08989621.2025.2481949).

## License

MIT. See `LICENSE`.

## Contact

Matthew Ettleson, MD. <Matthew.Ettleson@uchicagomedicine.org>
