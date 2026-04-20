# Data Explorer — Project 3 A/B Testing Experiment

## Overview
This repository contains our **Project 3** submission for **Designing and Conducting an Experiment (A/B Test)**. We extended our Shiny web application into a controlled A/B testing framework to evaluate whether changing the wording of the main demo-dataset call-to-action (CTA) button affects early user engagement.

The application supports:
- uploading and previewing datasets,
- cleaning and preprocessing data,
- engineering features,
- exploratory data analysis,
- interactive visualizations,
- and direct `.txt` file editing inside the app.

For this project, we introduced an A/B testing layer while keeping the rest of the app behavior unchanged.

---

## Research Question
**Does changing the demo dataset CTA button text increase early user engagement in the Data Loading tab of the Shiny app?**

More specifically, we test whether a more action-oriented CTA leads to stronger early interaction with the app.

---

## Hypotheses
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
- upload flow,
- data preview behavior,
- cleaning tools,
- feature engineering,
- EDA outputs,
- interactive EDA behavior,
- and overall visual styling.

This design helps ensure that observed differences can be attributed as directly as possible to CTA wording.

### Justification for the Experimental Factor
We selected the demo CTA button text because it is a simple, isolated, high-visibility interface change that may influence whether a user begins interacting with the app. It is therefore an appropriate factor for a low-cost, high-clarity A/B test.

---

## Random Assignment Method
Users are assigned to one of the two groups at the **session level**.

### Default behavior
If no group is specified in the URL, the app randomly assigns the session to:
- **Group A**, or
- **Group B**

### Manual testing option
To make testing reproducible, a version can also be forced through URL parameters:
- `?group=A` → control version
- `?group=B` → treatment version

This makes both versions easy to verify manually and supports reproducibility.

---

## Metrics Collected
To align the experiment with the rubric and project instructions, the app logs structured A/B testing events for each session.

### Core A/B events
- `session_started`
- `demo_cta_impression`
- `demo_button_clicked`
- `demo_dataset_loaded`
- `demo_load_failed`
- `first_action_completed`
- `tab_viewed`
- `file_uploaded`
- `file_upload_details`

### Additional engagement events
The current app also logs deeper interaction events, including:
- `cleaning_options_applied`
- `feature_engineering_reset`
- `feature_math_created`
- `feature_bin_created`
- `feature_interaction_created`
- `feature_column_renamed`
- `feature_columns_dropped`
- `eda_plot_generated`
- `eda_plot_generated_detail`
- `interactive_eda_download`

### Primary outcome for the A/B test
- **Demo CTA engagement**, measured through `demo_button_clicked`

### Secondary outcomes
- **Demo dataset successfully loaded**, measured through `demo_dataset_loaded`
- **Time to first action**, measured through `seconds_from_start` at the first `first_action_completed` event
- **Broader early engagement**, measured through `tab_viewed`, `file_uploaded`, and related interaction logs

---

## Logged Data Schema
The app writes structured A/B metrics to a local CSV log and also emits browser analytics events.

Each local event record includes:
- `session_id` — unique session identifier
- `event` — event type
- `condition` — `Control A` or `Treatment B`
- `button_text` — text shown to the user
- `dataset` — associated dataset name, if any
- `tab` — tab where the event occurred
- `seconds_from_start` — elapsed time since session start
- `timestamp` — event timestamp

This schema supports later statistical analysis and documentation of data quality.

---

## Running the App Locally
Open an R session in the project root and run:

```r
options(shiny.launch.browser = TRUE)
shiny::runApp("app.R")
```

Or from a shell:

```bash
R -e "shiny::runApp('app.R')"
```

Both experimental conditions can be reproduced through random session assignment or manually through URL parameters (`?group=A` and `?group=B`).

---

## Analytics Integrations
The current code supports **three analytics paths** in addition to the local CSV log:
- Datadog Browser RUM
- Google Analytics 4
- PostHog

### 1. Local CSV logging (always available)
The app always writes A/B event logs to:

```text
logs/ab_metrics_log.csv
```

relative to the app directory.

### 2. Datadog Browser RUM
Datadog Browser RUM is enabled when both of the following are non-empty:
- `DD_APPLICATION_ID`
- `DD_CLIENT_TOKEN`

The current `app.R` uses these environment variables:
- `DD_APPLICATION_ID` (default currently set in code)
- `DD_CLIENT_TOKEN` (default currently set in code)
- `DD_SITE` (default `us5.datadoghq.com`)
- `DD_SERVICE` (default `data-explorer-shiny`)
- `DD_ENV` (default `development`)
- `DD_VERSION` (default `1.0.0`)

Example:

```bash
export DD_APPLICATION_ID=b7e2907d-f502-4a58-aba3-c54042e80855
export DD_CLIENT_TOKEN=pubb78f2da86de4160cd3bbf6e70ab86830
export DD_SITE=us5.datadoghq.com
export DD_SERVICE=data-explorer-shiny
export DD_ENV=development
export DD_VERSION=1.0.0
R -e "shiny::runApp('app.R')"
```

### 3. Google Analytics 4
GA4 is enabled when `GA_MEASUREMENT_ID` is non-empty. The current code uses:
- `GA_MEASUREMENT_ID` (default currently set in code as `G-3L7WXSWEK7`)

Example:

```bash
export GA_MEASUREMENT_ID=G-3L7WXSWEK7
R -e "shiny::runApp('app.R')"
```

### 4. PostHog
PostHog tracking is enabled when:
- `POSTHOG_API_KEY` is set

The current code uses:
- `POSTHOG_API_KEY`
- `POSTHOG_HOST` (default `https://us.i.posthog.com`)

Example:

```bash
export POSTHOG_API_KEY=phc_your_project_key
export POSTHOG_HOST=https://us.i.posthog.com
R -e "shiny::runApp('app.R')"
```

If `POSTHOG_API_KEY` is not set, the app still runs and PostHog tracking stays disabled.

---

## Where to Check Datadog Data
After launching the app and interacting with it, Datadog data can be inspected in:

- `Digital Experience > RUM Explorer`
  - Select the `abtest` application.
  - For browser/session activity, inspect Sessions, Views, Resources, Long Tasks, and Errors.
  - For custom experiment actions, switch the event type to `Actions` and filter events such as:
    - `session_started`
    - `demo_cta_impression`
    - `demo_button_clicked`
    - `demo_dataset_loaded`
    - `first_action_completed`
    - `tab_viewed`
    - `file_upload_details`
    - `cleaning_options_applied`
- `Digital Experience > Session Replay`
  - Review browser sessions and automatically captured interactions.
- `Application Management > Generate Metrics`
  - Create long-lived metrics from RUM action events if needed.

---

## Repository Structure
```text
.
├── app.R
├── README.md
└── logs/
    └── ab_metrics_log.csv   # created after the app is run
```

---

## Reproducibility Notes
This repository is designed to support reproducibility by providing:
- a single main Shiny app file,
- built-in control/treatment assignment,
- local event logging,
- optional analytics integrations,
- and documented instructions for testing both versions.

For manual verification, launch the app with:
- `?group=A` for control
- `?group=B` for treatment

This allows both versions to be reproduced consistently during grading or QA.

