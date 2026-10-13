# Data specification

The pipeline (`ML_pipeline_07_for_repo.Rmd`) needs two CSV files, **`ds.full.csv`** and **`ds.reduced.csv`**. The original patient-level data cannot be shared (see README, *Data availability*). This document describes the exact format required so the pipeline can be run on your own data.

To see a working example, run `make_synthetic_data.R`. It writes correctly formatted files filled with random numbers to `synthetic_data/`.

The pipeline checks this specification when it starts (`validate_dataset()` in the *configuration* chunk) and stops with a plain-language error for the problems that would otherwise fail obscurely or, worse, run silently with wrong values.

---

## 1. General requirements

| Requirement | Detail |
|---|---|
| Files | `ds.full.csv` and `ds.reduced.csv`, UTF-8, comma-separated, header row |
| Location | Same folder as the Rmd, or set `Sys.setenv(LT4_DATA_DIR = "path/to/folder")` before running |
| Unit of observation | **One row per patient** (one index TSH measurement each). The train/test split is by *row*; repeated patients could leak across the split. A warning is raised if `patientid` is duplicated. |
| Same schema | Both files use the same column names and coding. The *full* file additionally contains laboratory and vital-sign predictors (section 4). |
| Missing data | **No imputation is performed.** Supply complete cases. Missing outcomes are an error; missing predictors raise a warning. |
| Column names | Exactly as in the tables below (case-sensitive) |

> **Every column that is not listed as "excluded" or an outcome is treated as a predictor.** If your file contains extra columns that should *not* be model inputs (names, free text, dates, secondary identifiers), either remove them from the CSV or add them to `BASE_EXCLUDE` in the configuration chunk.

---

## 2. Required columns that are *not* model inputs

These must be present (the code selects them by name), but are dropped before modelling.

| Column | Type | Description |
|---|---|---|
| `patientid` | text | Patient identifier (duplicates trigger a warning) |
| `index_date` | date / text | Date of the index TSH |
| `age_cat` | text | Categorised age (any coding) |
| `ZIP` | text / number | ZIP code (any coding) |
| `levo_dose_cat` | text | Categorised LT4 dose (any coding) |
| `gap` | **numeric** | Days between the LT4 order and the TSH draw. **Used** for the gap-stratified sensitivity analyses (≤ 90 vs > 90 days) but never as a predictor in those analyses. |
| `n_comorbidities` | number | Count of comorbidities (derived; excluded) |
| `n_medications` | number | Count of medications (derived; excluded) |
| `comorbid_cat` | text | Categorised comorbidity count |
| `med_cat` | text | Categorised medication count |

## 3. Outcome columns (all required, all coded 0 / 1, no missing values)

| Column | Used in | Definition (see manuscript Methods for the exact thresholds) |
|---|---|---|
| `TSH_OOR_1` | Primary | TSH out of range (labelled "OOR (0.4–aaULN)" in the output tables) |
| `TSH_high` | Primary | TSH above range |
| `TSH_low` | Primary | TSH below range |
| `TSH_OOR_2` | Wide-bounds sensitivity | TSH outside 0.1–10.0 mIU/L |
| `TSH_10` | Wide-bounds sensitivity | TSH > 10.0 mIU/L |
| `TSH_0.1` | Wide-bounds sensitivity | TSH < 0.1 mIU/L |
| `TSH_value` | (excluded) | Raw TSH result, numeric. Never used as a predictor. |

The pipeline only needs the 0/1 coding; **the outcomes are defined upstream, in your own data preparation.** If your thresholds differ from the manuscript's, also edit the hard-coded display labels (`outcome_labels`, `outcome_labels_wide`, and the table/figure titles) so the output text matches your definitions.

Outcomes with an event rate below 5% in a training split are automatically class-weighted (see README), so a rare outcome is allowed, but each outcome needs enough events for 10-fold cross-validation and an 80/20 split (see section 7).

## 4. Predictor columns

### 4a. Demographic / treatment predictors (categorical)

| Column | Type | Notes |
|---|---|---|
| `PAT_SEX` | text | Nominal. Manuscript levels: `Female`, `Male` |
| `PAT_RACE` | text | Nominal. Manuscript levels: `White`, `Black`, `Other/Unknown` |
| `ETHNIC` | text | Nominal. Manuscript levels: `Not Hispanic`, `Hispanic`, `Other/Unknown` |
| `year` | text | Nominal (period of index date). Manuscript levels: `2014-2019`, `2020-2023` |
| `gap_cat` | text | **Ordered, and the four level strings are fixed (hard requirement):** `42-90 days`, `91-180 days`, `181-270 days`, `271-365 days`. Any other value is an error. This implies the cohort was restricted to gaps of 42–365 days. |

Other level names for the four nominal variables will run, but the figures will then show unrelabelled variable names (labels are set in the `feature_labels` vector, which you can edit).

### 4b. Numeric predictors

`TSH_age` (years) and `levo_dose` (LT4 dose; same unit throughout), plus, in `ds.full.csv` only, the laboratory and vital-sign columns used in the manuscript:

`Alb, GFR, Cl, Hct, Hgb, Creat, Calc, Na, AlkPhos, AST, ALT, Tbil, Plt, WBC, K, Gluc, BUN` (labs) and `WT, TEMP, SBP, DBP, HR` (vitals).

Any further numeric column you include is simply treated as an additional numeric predictor.

### 4c. Binary predictors — **coding and column order matter**

Diagnosis and medication indicators are stored in two **contiguous blocks selected by position**:

| Block | First column | Last column | Contains |
|---|---|---|---|
| Diagnoses | `HTN` | `BONE` | everything between them, in file order |
| Medications | `ANDROGENS` | `VITAMIN` | everything between them, in file order |

Requirements:

1. `HTN` must come **before** `BONE`, and `ANDROGENS` before `VITAMIN`, with only binary columns between them.
2. **Coding may be `0/1` or `1/2`** (either is accepted; the manuscript data are 0/1). Anything else (for example a third value, or text labels) is rejected.
3. No other column type may sit between the endpoints of a block.

*Note on the `- 1` in the code.* `prep_model_df()` subtracts 1 from these columns (it was written for 1/2-coded indicators), so 0/1-coded input becomes -1/0 internally. This is a constant shift of a binary variable, and the models are invariant to it: the elastic net centres and scales its inputs, and tree-based models split identically. We verified this on synthetic data: elastic net and random forest test-set probabilities were identical (maximum difference 0) for the same data coded 0/1 versus 1/2. The shift is retained unchanged so that the reported analysis reproduces exactly. It affects only the internal coding, not any result. (This check was run for the elastic net and random forest; the XGBoost argument is by construction, since tree splits depend only on the ordering of values, but it was not run here.)

Columns used in the manuscript — diagnoses: `HTN, OBESITY, GI, CVD, CANCER, SLEEP, ANEMIA, JOINT, LIVER, RENAL_URINARY, BONE`; medications: `ANDROGENS, STEROID, ANTIHTN, PPI_ANTACID, ANTIDEP_ANXIETY, ANTIHISTAMINE, SUPPLEMENT, IRON, ANTIPLT, HEPARIN, ANTINEOPLASTIC, BENZO, NONOPIOID_PAINMED, ANTIARRHYTHMIC, ANTIPSYCH, ANTISEIZURE, ABX, VITAMIN`. (In your data the blocks may contain additional or fewer columns; only the endpoints are fixed.)

---

## 5. What the pipeline does with the data (so you can anticipate the effect of your own coding)

- 80/20 stratified train/test split on the outcome (`createDataPartition`, seed 42), separately for every outcome × dataset combination.
- Numeric predictors are centred/scaled for the elastic net only. Random forest and XGBoost use the raw values.
- Nominal variables are dummy-encoded (reference level dropped). `gap_cat` is an ordered factor (polynomial contrasts in model fitting; integer ordinal in the SHAP encoding).
- Decision thresholds (Youden) are chosen from held-out cross-validation predictions on the training data only, then applied unchanged to the test set.
- Gap-stratified analyses split on `gap ≤ 90` vs `gap > 90` days.

## 6. Settings that are hard-coded and may need editing for different data

| Setting | Where | Why you may change it |
|---|---|---|
| `BASE_EXCLUDE`, `ALL_OUTCOME_COLS`, `NOMINAL_COLS`, `ORDERED_COLS` | *configuration* chunk | Different column names or extra non-predictor columns |
| `GAP_CAT_LEVELS` | *configuration* chunk | Different follow-up intervals (also edit the `gap ≤ 90` cut-points in the stratified chunks) |
| `CLASS_WEIGHT_THRESHOLD` (0.05) | *configuration* chunk | Different rare-event cut-off |
| `CV_FOLDS`, `ENET_TUNE`, `RF_TUNE`, `XGB_NROUNDS_MAX`, `SHAP_*` | *configuration* chunk (`DEV_MODE` block) | Compute budget |
| XGBoost hyperparameters (`eta`, `max_depth`, …) | `fit_xgb()` | Different data size |
| `outcome_labels*`, `feature_labels`, figure titles | label-map and figure chunks | Output text matching your definitions |

## 7. Practical sample-size guidance

The pipeline has a pre-flight event-count check in the stratified analyses, but nothing prevents you from running an outcome with very few events. As a rough guide, you want at least a few dozen events in the **test** set (20% of the data) for the AUC and Youden-threshold estimates to mean anything, and enough in each CV fold for stable fitting. Interpret AUCs from small event counts with the wide confidence intervals they imply.

## 8. Pre-flight checklist

- [ ] Both CSVs present, same column names, one row per patient
- [ ] All six outcome columns coded 0/1, no missing
- [ ] `HTN…BONE` and `ANDROGENS…VITAMIN` blocks contiguous, in that order, binary-coded (0/1 or 1/2)
- [ ] `gap` numeric; `gap_cat` uses exactly the four required strings
- [ ] No missing predictor values
- [ ] No extra non-predictor columns (or added to `BASE_EXCLUDE`)
- [ ] Run once with `DEV_MODE <- TRUE` before the full run
