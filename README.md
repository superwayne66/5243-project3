# Data Explorer — Project 3 A/B Testing Experiment

## Project Information

**Course:** STAT5243  
**Project:** Project 3  
**Team:** Team 15  

| Name | UNI |
|---|---|
| Baixuan Chen | bc3212 |
| Lucas Meadows | lm3774 |
| Shengbo Yi | sy3302 |
| Wenyang Zu | wz2744 |

**GitHub Repository:**  
[https://github.com/superwayne66/5243-project3](https://github.com/superwayne66/5243-project3)

**Deployed Shiny App:**  
[https://baixuanchen5243.shinyapps.io/5243-project3/](https://baixuanchen5243.shinyapps.io/5243-project3/)

---

## Overview

This project implements an A/B testing framework in a Shiny-based Data Explorer application. The app supports data loading, cleaning, feature engineering, exploratory data analysis, and interactive EDA.

For the A/B test, we changed only one interface element: the demo dataset call-to-action button text in the Data Loading tab. All other app behavior and layout were kept the same across groups.

---

## Research Question

Does changing the demo CTA text from **“Load Demo Dataset”** to **“Try Demo Dataset Instantly”** increase user engagement and encourage more downstream user actions in the Shiny app?

---

## How to Run the Shiny App Locally

### 1. Open the project folder

Clone or download this repository, then open the project folder in RStudio.

```bash
git clone https://github.com/superwayne66/5243-project3.git
cd 5243-project3
```

### 2. Install required R packages

Run the following code in R or RStudio:

```r
install.packages(c(
  "shiny",
  "shinydashboard",
  "shinyjs",
  "bslib",
  "DT",
  "plotly",
  "ggplot2",
  "dplyr",
  "tidyr",
  "readr",
  "readxl",
  "jsonlite",
  "tools"
))
```

Some systems may already have part of these packages installed.

### 3. Run the app

In RStudio, open `app.R` and click **Run App**.

Alternatively, run:

```r
shiny::runApp("app.R")
```

Or from the terminal:

```bash
R -e "shiny::runApp('app.R')"
```

### 4. Test A/B assignment manually

To force Version A or Version B during testing, add one of the following URL parameters after the app URL:

```text
?group=A
?group=B
```

For example:

```text
http://127.0.0.1:xxxx/?group=A
http://127.0.0.1:xxxx/?group=B
```

Version A shows:

```text
Load Demo Dataset
```

Version B shows:

```text
Try Demo Dataset Instantly
```

---

## How to Reproduce the A/B Test Analysis

The statistical analysis is contained in:

```text
ab_test_analysis.ipynb
```

### 1. Open the notebook

Open `ab_test_analysis.ipynb` in Jupyter Notebook, JupyterLab, VS Code, or another Python notebook environment.

### 2. Install required Python packages

If needed, install the following packages:

```bash
pip install pandas numpy matplotlib seaborn scipy
```

### 3. Make sure the input CSV is available

The main input file is:

```text
ab_metrics.csv
```

This file should be in the same folder as `ab_test_analysis.ipynb`.

### 4. Run the notebook from top to bottom

The notebook performs the following workflow:

```text
1. Load the raw A/B testing event data.
2. Inspect the raw data and column names.
3. Aggregate event-level data into session-level indicators.
4. Create summary tables by variant.
5. Calculate primary and secondary metrics.
6. Run Fisher's exact test for binary outcomes.
7. Save output CSV files for the final report.
```

The notebook generates the following output files:

```text
ab_session_summary.csv
ab_test_summary_by_variant.csv
ab_event_counts_by_variant.csv
```

---

## Analysis Workflow

The full analysis workflow is:

```text
1. Run the Shiny app and collect user interaction data.
2. Track user events using Google Analytics 4.
3. Export or process the event-level data into ab_metrics.csv.
4. Convert event-level records into session-level indicators.
5. Compare Version A and Version B using the primary and secondary metrics.
6. Use Fisher's exact test because the outcomes are binary and the sample size is relatively small.
7. Generate summary tables and figures for the final report.
```

---

## Key Results

The final session-level analysis included:

```text
Variant      Sessions    Demo Loaded    Demo Load Rate
Version A   20          5              25.0%
Version B   24          21             87.5%
```

The primary metric was **demo dataset load rate**. Version B had a much higher demo dataset load rate than Version A. Fisher's exact test gave a p-value of approximately:

```text
3.18e-05
```

This provides statistical evidence that Version B significantly improved the demo dataset load rate.

For secondary metrics, Version B also had higher click-through rate and first action completion rate. However, downstream engagement remained low and was not statistically significant.

---

## Limitations and Future Work

This project focuses on one interface change: the demo dataset CTA button text. While this helps isolate the wording effect, other design factors such as button color, button placement, layout, and onboarding instructions were not tested.

The sample size was also limited, so future work should collect more real user sessions over a longer period. Future analyses could also filter out developer testing sessions more carefully and track additional downstream actions such as data preview, data cleaning, feature engineering, and interactive EDA usage.

---

## Reproducibility Notes

To reproduce the project:

```text
1. Run app.R to launch the Shiny application.
2. Use the app normally or force a version using ?group=A or ?group=B.
3. Collect or use the provided A/B testing data in ab_metrics.csv.
4. Run ab_test_analysis.ipynb.
5. Review the generated CSV files and final report.
```

The main files needed for reproduction are:

```text
app.R
ab_metrics.csv
ab_test_analysis.ipynb
README.md
```