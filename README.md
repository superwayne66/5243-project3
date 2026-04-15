# Data Explorer — Project 3 A/B Testing Experiment

## Overview
This repository contains our **Project 3** submission for **Designing and Conducting an Experiment (A/B Test)**. We adapted our Shiny web application from the previous project into an experimental framework and tested whether changing the wording of the main demo-dataset call-to-action (CTA) button affects early user engagement.

The application still allows users to:
- upload and preview datasets,
- clean and preprocess data,
- engineer features,
- perform exploratory data analysis,
- use interactive visualizations,
- and edit `.txt` files directly in the app.

For this project, we introduced an A/B testing layer while keeping the underlying app functionality unchanged.

---

## Research Question
**Does changing the demo dataset CTA button text increase early user engagement in the Data Loading tab of the Shiny app?**

More specifically, we test whether a more action-oriented CTA leads to more users beginning interaction with the app.

---

## Hypothesis
### Null Hypothesis (H0)
Changing the CTA button text has **no effect** on early user engagement.

### Alternative Hypothesis (H1)
Changing the CTA button text from **"Load Demo Dataset"** to **"Try Demo Dataset Instantly"** **increases early user engagement**.

---

## Experimental Design
We implemented a **two-group A/B test** in the **Data Loading** tab.

### Control Group (A)
Button text shown:

`Load Demo Dataset`

### Treatment Group (B)
Button text shown:

`Try Demo Dataset Instantly`

### Experimental Variable
The **only modified interface variable** is the text shown on the primary demo CTA button.

### Controlled Elements
All other parts of the app remain identical across groups, including:
- layout,
- dataset choices,
- app functionality,
- data preview behavior,
- upload flow,
- cleaning tools,
- feature engineering,
- EDA outputs,
- and visual styling.


This ensures that observed differences can be attributed as directly as possible to the CTA wording.

## Justification for the Experimental Factor
We selected the demo CTA button text as the experimental factor because it is a simple and isolated interface change that may influence whether a user begins interacting with the app. This allows us to test an interface-design hypothesis while keeping all other functionality unchanged.

---

## Random Assignment Method
Users are assigned to one of the two groups at the **session level**.

### Default behavior
If no group is specified in the URL, the app randomly assigns the user to:
- **Group A**, or
- **Group B**

### Manual testing option
To make testing reproducible, a version can also be forced through URL parameters:
- `?group=A` → Control version
- `?group=B` → Treatment version

This makes it easy to verify both versions manually and supports reproducibility.

---

## Metrics Collected
To align the experiment with the rubric and project instructions, we log structured A/B testing events for each session.

### Primary Metric
- **Demo CTA click-through / demo dataset start rate**
  - measured by the event: `demo_button_clicked`

### Secondary Metrics
- **Demo dataset successfully loaded**
  - event: `demo_dataset_loaded`
- **Time to first action**
  - measured as `seconds_from_start` at the first `first_action_completed` event
- **General user navigation / engagement**
  - event: `tab_viewed`
- **Alternative first interaction via upload**
  - event: `file_uploaded`
- **Session start and CTA exposure**
  - events: `session_started`, `demo_cta_impression`

These metrics allow us to evaluate both direct response to the CTA and broader early engagement behavior.

---

## Member 1 Implementation Scope
This repository supports Member 1 responsibilities by:
- creating two app versions through control and treatment CTA wording,
- preserving identical functionality across both versions,
- implementing session-level random assignment,
- organizing the project in a reproducible GitHub repository,
- and documenting how to run and test the experiment.

## Logged Data Schema
The app exports session-level A/B metrics as a CSV file.

Each record includes:
- `session_id` — unique session identifier
- `event` — event type
- `condition` — `Control A` or `Treatment B`
- `button_text` — text shown to the user
- `dataset` — associated dataset name, if any
- `tab` — tab where the event occurred
- `seconds_from_start` — elapsed time since session start
- `timestamp` — event timestamp

This structure supports later statistical analysis and documentation of data quality.

---

## Deployment / Execution Note
The app is designed to run locally as a fully reproducible Shiny application. Both experimental conditions can be reproduced either through random session assignment or manually through URL parameters (`?group=A` and `?group=B`).

## Repository Structure
```text
.
├── app1.R
└── README.md