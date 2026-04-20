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

## Experimental Design

The experiment contains two versions:

| Group | Version | Button Text |
|---|---|---|
| Control | Version A | `Load Demo Dataset` |
| Treatment | Version B | `Try Demo Dataset Instantly` |

Users are assigned to one of the two versions at the session level. For manual testing, the version can also be forced using URL parameters:

```text
?group=A
?group=B

The only experimental variable is the demo CTA button wording. Other app components, including dataset choices, upload flow, data preview, cleaning tools, feature engineering tools, and EDA outputs, remain unchanged.

---

## Metrics

The primary metric is:

- **Demo CTA click rate**, measured by whether users click the demo dataset button.

Secondary metrics include:

- number of sessions,
- total events,
- average events per session,
- average clicks per session,
- demo dataset loaded events,
- and downstream user actions.

Google Analytics 4 was used to collect event-level user interaction data. The data was then exported and analyzed in Python at the session level.

---

## Repository Structure

```text
.
├── app.R
├── README.md
├── ab_metrics.csv
├── ab_session_summary.csv
├── ab_event_counts_by_variant.csv
├── ab_test_summary_by_variant.csv
├── ab_test_analysis.ipynb
├── 1.png
├── 2.png
├── 3.png
├── 4.png
├── 5.png
├── 6.png
├── 7.png
└── 8.png

## Analysis Workflow

The analysis workflow includes:

1. Load the exported A/B testing data.
2. Check missing values and duplicated rows.
3. Aggregate event-level data to the session level.
4. Compare Version A and Version B using the primary and secondary metrics.
5. Conduct statistical testing.
6. Create figures and summary tables for the final report.

---

## Key Findings

The project successfully implemented a Shiny-based A/B testing framework 
and collected user interaction data through Google Analytics 4. The experiment 
compared the original CTA wording, **“Load Demo Dataset,”** with the revised wording, 
**“Try Demo Dataset Instantly.”**

Because the sample size may be limited and some sessions may come from development 
testing, the results should be interpreted as exploratory rather than fully conclusive.

---

## Limitations and Future Work

This project focuses on one interface change: the demo dataset CTA button text.
While this helps isolate the wording effect, other design factors such as button color, position, 
layout, and instructions were not tested. Future work should collect more real user sessions over 
a longer period, filter out developer testing sessions more carefully, and track more downstream 
actions such as data preview, cleaning, feature engineering, and EDA.