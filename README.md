LT4-TSH-ML-prediction

Supplemental code and materials for:

FULL TITLE: Using supervised machine learning to predict and identify clinical features associated with suboptimal levothyroxine treatment

SHORT TITLE: Predictive modeling of suboptimal levothyroxine treatment

Pending submission.

Overview

This repository contains the analytic pipeline and supplemental materials accompanying the above project. We applied three supervised machine learning algorithms — elastic net penalized regression, random forest, and XGBoost — to predict TSH dysregulation outcomes in a large cohort of levothyroxine (LT4)-treated patients. The goal of this work is knowledge generation: identifying clinical features associated with suboptimal TSH control, framed for a clinical endocrinology audience.

Repository Contents
File	Description
ML_pipeline_04_for_repo.Rmd	Primary analytic pipeline (R Markdown). Contains all preprocessing, modeling, and SHAP interpretability code.
Figs PPTX.pptx	Editable PowerPoint file containing manuscript figures (Figures 2–4).
FIGURE LEGENDS.docx	Figure legends for main manuscript figures.
SUPPLEMENTAL FIGURE LEGENDS.docx	Figure legends for supplemental figures.
Table 1_revised.docx	Table 1: Baseline characteristics of the study cohort.
Table 2.docx	Table 2: Model performance metrics across outcomes and datasets.
online_supp_table1a.docx	Online Supplemental Table 1a
online_supp_table1b.docx	Online Supplemental Table 1b
online_supp_table2_revised.docx	Online Supplemental Table 2
online_supp_table3.docx	Online Supplemental Table 3
online_supp_table4.docx	Online Supplemental Table 4
online_supp_table5.docx	Online Supplemental Table 5
table comparing full and reduced datasets.xlsx	Comparison of predictor availability across comprehensive (N≈3,977) and reduced (N≈12,045) datasets.
Analytic Pipeline

The pipeline (ML_pipeline_04_for_repo.Rmd) is written in R and requires the following packages:

Modeling: caret, glmnet, ranger, xgboost
Interpretability: kernelshap, shapviz
Data wrangling: tidyverse, lubridate
Reporting/figures: flextable, officer, patchwork, cowplot, tableone
Parallelization: future, doParallel

Note on parallelization: SHAP value computation via kernelshap requires future::plan(multisession) for parallel execution. doParallel is not compatible with kernelshap and should not be used for this step.

Study Design

Two analytic datasets were used:

Comprehensive dataset (primary analysis): N ≈ 3,977 patients; 71 predictors including laboratory values and vitals
Reduced dataset (sensitivity analysis): N ≈ 12,045 patients; 48 predictors

Primary outcomes: TSH out of range (TSH_OOR_1), TSH high, TSH low
Sensitivity analyses: Wide TSH bounds, gap stratification (recent ≤90 days vs. distant >90 days)

AI Disclosure

The machine learning pipeline was developed with assistance from Claude (Anthropic, San Francisco, CA), a large language model-based AI tool, which contributed to pipeline architecture, code generation, and iterative debugging; all analytical decisions, model specifications, and interpretations were made by the authors (Resnik & Hosseini, 2026).

Financial Support

The study was supported by the National Institute of Diabetes and Digestive and Kidney Disease (NIDDK) of the National Institutes of Health (NIH) through the Diabetes Research and Training Center (DRTC) (DK020595) and the career development program (DK138262)


Contact

Matthew Ettleson, MD

University of Chicago

Matthew.Ettleson@uchicagomedicine.org
