# ==============================================================================
# make_synthetic_data.R
#
# Generates SYNTHETIC ds.full.csv and ds.reduced.csv that follow the format in
# DATA_SPECIFICATION.md. Use them to (a) check your environment, and
# (b) see the exact structure your own data must have.
#
# THE DATA ARE RANDOM NUMBERS. They contain no patient information and the
# model results obtained from them have no clinical meaning.
#
# Usage (from the repository root):
#   Rscript make_synthetic_data.R                  # writes ./synthetic_data/
#   Sys.setenv(LT4_DATA_DIR = "synthetic_data")    # then run the pipeline
#   # (set DEV_MODE <- TRUE in the pipeline for a fast test run)
# ==============================================================================

set.seed(2026)
out_dir <- "synthetic_data"
dir.create(out_dir, showWarnings = FALSE)

N_FULL    <- 1500
N_REDUCED <- 3500

# Column blocks. NOTE the order: the pipeline selects the binary blocks BY
# POSITION (HTN:BONE and ANDROGENS:VITAMIN), so each block must be contiguous
# with these first/last columns.
dx_cols  <- c("HTN", "OBESITY", "GI", "CVD", "CANCER", "SLEEP", "ANEMIA",
              "JOINT", "LIVER", "RENAL_URINARY", "BONE")
med_cols <- c("ANDROGENS", "STEROID", "ANTIHTN", "PPI_ANTACID", "ANTIDEP_ANXIETY",
              "ANTIHISTAMINE", "SUPPLEMENT", "IRON", "ANTIPLT", "HEPARIN",
              "ANTINEOPLASTIC", "BENZO", "NONOPIOID_PAINMED", "ANTIARRHYTHMIC",
              "ANTIPSYCH", "ANTISEIZURE", "ABX", "VITAMIN")
lab_cols <- c("Alb", "GFR", "Cl", "Hct", "Hgb", "Creat", "Calc", "Na", "AlkPhos",
              "AST", "ALT", "Tbil", "Plt", "WBC", "K", "Gluc", "BUN")
vit_cols <- c("WT", "TEMP", "SBP", "DBP", "HR")

# Plausible (mean, sd) for continuous variables
cont_params <- list(
  Alb = c(4.0, .4), GFR = c(80, 20), Cl = c(102, 3), Hct = c(39, 4), Hgb = c(13, 1.5),
  Creat = c(1.0, .3), Calc = c(9.4, .4), Na = c(140, 2.5), AlkPhos = c(85, 30),
  AST = c(25, 10), ALT = c(25, 12), Tbil = c(.6, .25), Plt = c(250, 60),
  WBC = c(7, 2), K = c(4.2, .4), Gluc = c(105, 25), BUN = c(16, 6),
  WT = c(80, 20), TEMP = c(98.2, .5), SBP = c(125, 16), DBP = c(76, 10), HR = c(76, 11)
)

make_ds <- function(n, with_labs) {
  levo_dose <- round(pmax(25, rnorm(n, 100, 40)))
  TSH_age   <- round(pmin(95, pmax(18, rnorm(n, 58, 16))))
  gap       <- sample(42:365, n, replace = TRUE)

  # --- latent TSH: mostly in/near range, a small "over-replaced" component ---
  over   <- rbinom(n, 1, plogis(-2.6 + 0.012 * (levo_dose - 100)))
  logTSH <- 0.9 - 0.004 * (levo_dose - 100) + 0.004 * (TSH_age - 58) +
            0.002 * (gap - 200) + rnorm(n, 0, 0.8) - 3 * over
  TSH_value <- round(exp(logTSH), 3)

  aaULN <- 4.5 + 0.03 * (TSH_age - 40)          # illustrative age-adjusted ULN

  d <- tibble::tibble(
    patientid       = sprintf("SYN%06d", seq_len(n)),
    index_date      = as.character(as.Date("2014-01-01") + sample(0:3500, n, TRUE)),
    PAT_SEX         = sample(c("Female", "Male"), n, TRUE, prob = c(.8, .2)),
    PAT_RACE        = sample(c("White", "Black", "Other/Unknown"), n, TRUE, prob = c(.5, .35, .15)),
    ETHNIC          = sample(c("Not Hispanic", "Hispanic", "Other/Unknown"), n, TRUE, prob = c(.85, .08, .07)),
    ZIP             = sprintf("%05d", sample(60601:60660, n, TRUE)),
    TSH_age         = TSH_age,
    age_cat         = as.character(cut(TSH_age, c(0, 40, 65, Inf), labels = c("<40", "40-64", "65+"), right = FALSE)),
    levo_dose       = levo_dose,
    levo_dose_cat   = as.character(cut(levo_dose, c(0, 75, 100, 125, Inf), labels = c("<=75", "76-100", "101-125", ">125"))),
    gap             = gap,
    gap_cat         = as.character(cut(gap, c(41, 90, 180, 270, 365),
                                        labels = c("42-90 days", "91-180 days", "181-270 days", "271-365 days"))),
    year            = sample(c("2014-2019", "2020-2023"), n, TRUE, prob = c(.6, .4))
  )

  if (with_labs) {
    for (v in c(lab_cols, vit_cols))
      d[[v]] <- round(rnorm(n, cont_params[[v]][1], cont_params[[v]][2]), 2)
  }

  # Binary predictors coded 0/1 (1/2 coding is also accepted by the pipeline)
  for (v in dx_cols)  d[[v]] <- rbinom(n, 1, runif(1, .05, .35))
  for (v in med_cols) d[[v]] <- rbinom(n, 1, runif(1, .05, .30))

  d$n_comorbidities <- rowSums(d[, dx_cols]  == 1)
  d$n_medications   <- rowSums(d[, med_cols] == 1)
  d$comorbid_cat    <- as.character(cut(d$n_comorbidities, c(-1, 1, 3, Inf), labels = c("0-1", "2-3", "4+")))
  d$med_cat         <- as.character(cut(d$n_medications,   c(-1, 2, 5, Inf), labels = c("0-2", "3-5", "6+")))

  # --- outcomes, all derived from the same TSH value, coded 0/1 ---
  d$TSH_value <- TSH_value
  d$TSH_low   <- as.integer(TSH_value < 0.4)
  d$TSH_high  <- as.integer(TSH_value > aaULN)
  d$TSH_OOR_1 <- as.integer(d$TSH_low == 1 | d$TSH_high == 1)
  d$TSH_0.1   <- as.integer(TSH_value < 0.1)
  d$TSH_10    <- as.integer(TSH_value > 10)
  d$TSH_OOR_2 <- as.integer(d$TSH_0.1 == 1 | d$TSH_10 == 1)
  d
}

ds.full    <- make_ds(N_FULL,    with_labs = TRUE)
ds.reduced <- make_ds(N_REDUCED, with_labs = FALSE)

readr::write_csv(ds.full,    file.path(out_dir, "ds.full.csv"))
readr::write_csv(ds.reduced, file.path(out_dir, "ds.reduced.csv"))

cat(sprintf("Wrote %s/ds.full.csv (%d x %d) and %s/ds.reduced.csv (%d x %d)\n",
            out_dir, nrow(ds.full), ncol(ds.full), out_dir, nrow(ds.reduced), ncol(ds.reduced)))
cat("\nEvent rates (full):\n")
print(round(colMeans(ds.full[, c("TSH_OOR_1", "TSH_high", "TSH_low", "TSH_OOR_2", "TSH_10", "TSH_0.1")]), 3))
