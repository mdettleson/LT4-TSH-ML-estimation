# ==============================================================================
# install_packages.R -- install the R packages used by the pipeline
#
#   Rscript install_packages.R
#
# For exact version pinning (recommended for reproducibility), use renv:
#   install.packages("renv")
#   renv::init()        # once, in the repository folder
#   source("install_packages.R")
#   # ... run the pipeline successfully ...
#   renv::snapshot()    # writes renv.lock; commit it
# Others then restore your exact versions with renv::restore().
# ==============================================================================

pkgs <- c(
  # core modelling
  "tidyverse", "caret", "glmnet", "ranger", "xgboost", "pROC", "e1071",
  # interpretability
  "shapviz", "kernelshap",
  # output / figures
  "flextable", "officer", "patchwork", "cowplot", "scales",
  # parallelization
  "parallelly", "foreach", "doParallel", "future",
  # rendering
  "rmarkdown", "knitr"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing)
} else {
  message("All required packages are already installed.")
}
