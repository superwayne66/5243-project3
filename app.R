# =============================================================================
# Project 2: Data Explorer — R Shiny Web Application
# =============================================================================
# Student 1: App Skeleton, Data Loading, User Guide
# Student 2: Data Cleaning
# Student 3: Feature Engineering + EDA summary/correlation
# Student 4: Interactive EDA + Grouped summaries + Downloads + Polish
# =============================================================================

# ---- Packages ----------------------------------------------------------------
library(shiny)
library(bslib)
library(DT)
library(readxl)
library(jsonlite)
library(tools)
library(plotly)

# ---- Global Options ----------------------------------------------------------
options(shiny.maxRequestSize = 30 * 1024^2)  # 30 MB upload limit

# ---- Helper: Read uploaded file by extension ---------------------------------
read_uploaded_file <- function(file_path, file_name) {
  ext <- tolower(file_ext(file_name))
  switch(ext,
         "csv"  = read.csv(file_path, stringsAsFactors = FALSE),
         "xlsx" = as.data.frame(read_excel(file_path)),
         "xls"  = as.data.frame(read_excel(file_path)),
         "json" = {
           result <- fromJSON(file_path, flatten = TRUE)
           if (!is.data.frame(result)) {
             stop("JSON file must contain a flat array of objects (tabular data).")
           }
           result
         },
         "rds"  = {
           result <- readRDS(file_path)
           if (!is.data.frame(result)) {
             stop("RDS file must contain a data.frame.")
           }
           result
         },
         stop(paste0("Unsupported file format: .", ext,
                     ". Please upload CSV, Excel, JSON, or RDS."))
  )
}

# ---- ADDED: helper functions (Student 2 Part) --------------------------------------
standardize_text_column <- function(x, trim_ws = TRUE, to_lower = FALSE, blank_to_na = TRUE) {
  if (!is.character(x)) return(x)
  
  y <- x
  
  if (trim_ws) {
    y <- trimws(y)
  }
  
  if (blank_to_na) {
    normalized <- tolower(trimws(y))
    na_like_tokens <- c("", "na", "n/a", "null", "none", "missing", "unknown")
    y[normalized %in% na_like_tokens] <- NA_character_
  }
  
  if (to_lower) {
    y <- tolower(y)
  }
  
  y
}

canonicalize_common_labels <- function(x, use_lowercase = FALSE) {
  if (!is.character(x)) return(x)
  
  y <- trimws(x)
  y_lower <- tolower(y)
  
  male_label <- if (use_lowercase) "male" else "Male"
  female_label <- if (use_lowercase) "female" else "Female"
  yes_label <- if (use_lowercase) "yes" else "Yes"
  no_label <- if (use_lowercase) "no" else "No"
  active_label <- if (use_lowercase) "active" else "Active"
  inactive_label <- if (use_lowercase) "inactive" else "Inactive"
  
  y[y_lower %in% c("male", "m")] <- male_label
  y[y_lower %in% c("female", "f")] <- female_label
  y[y_lower %in% c("yes", "y", "true", "t")] <- yes_label
  y[y_lower %in% c("no", "n", "false")] <- no_label
  y[y_lower %in% c("active", "act")] <- active_label
  y[y_lower %in% c("inactive", "inact")] <- inactive_label
  
  y
}

try_parse_numeric_column <- function(x) {
  if (!is.character(x)) return(x)
  
  y <- trimws(x)
  non_missing <- !is.na(y) & y != ""
  if (!any(non_missing)) return(x)
  
  cleaned <- gsub(",", "", y)
  cleaned <- gsub("\\$", "", cleaned)
  cleaned <- gsub("USD", "", cleaned, ignore.case = TRUE)
  cleaned <- gsub("%", "", cleaned)
  cleaned <- trimws(cleaned)
  
  parsed <- suppressWarnings(as.numeric(cleaned))
  success_rate <- mean(!is.na(parsed[non_missing]))
  digit_ratio <- mean(grepl("[0-9]", y[non_missing]))
  
  if (!is.na(success_rate) && !is.na(digit_ratio) && success_rate >= 0.8 && digit_ratio >= 0.8) {
    return(parsed)
  }
  
  x
}

try_standardize_date_column <- function(x) {
  if (!is.character(x)) return(x)
  
  y <- trimws(x)
  non_missing <- !is.na(y) & y != ""
  if (!any(non_missing)) return(x)
  
  formats <- c(
    "%Y-%m-%d", "%Y/%m/%d",
    "%m/%d/%Y", "%d/%m/%Y",
    "%m-%d-%Y", "%d-%m-%Y"
  )
  
  best_parsed <- NULL
  best_success_rate <- 0
  
  for (fmt in formats) {
    parsed <- as.Date(y, format = fmt)
    success_rate <- mean(!is.na(parsed[non_missing]))
    
    if (!is.na(success_rate) && success_rate > best_success_rate) {
      best_success_rate <- success_rate
      best_parsed <- parsed
    }
  }
  
  if (!is.null(best_parsed) && best_success_rate >= 0.8) {
    return(best_parsed)
  }
  
  x
}

winsorize_vector <- function(x, probs = c(0.05, 0.95)) {
  if (!is.numeric(x)) return(x)
  q <- quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  if (any(!is.finite(q))) return(x)
  x[x < q[1]] <- q[1]
  x[x > q[2]] <- q[2]
  x
}

cap_vector <- function(x, probs = c(0.01, 0.99)) {
  if (!is.numeric(x)) return(x)
  q <- quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  if (any(!is.finite(q))) return(x)
  x[x < q[1]] <- q[1]
  x[x > q[2]] <- q[2]
  x
}

# ---- Demo dataset choices ----------------------------------------------------
demo_choices <- c(
  "Select a dataset..." = "none",
  "mtcars (Motor Trend Cars)" = "mtcars",
  "iris (Fisher's Iris)" = "iris"
)

# ---- Custom CSS --------------------------------------------------------------
custom_css <- "
body {
  background-color: #f5f7fa;
  font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
}
.navbar {
  background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%) !important;
  box-shadow: 0 2px 12px rgba(0,0,0,0.15);
  padding: 0.5rem 1rem;
}
.navbar-brand {
  font-weight: 700;
  font-size: 1.3rem;
  letter-spacing: 0.5px;
}
.navbar .nav-link {
  color: rgba(255,255,255,0.85) !important;
  font-weight: 500;
  transition: color 0.2s ease, background 0.2s ease;
  border-radius: 6px;
  margin: 0 2px;
  padding: 0.5rem 1rem !important;
}
.navbar .nav-link:hover,
.navbar .nav-link.active {
  color: #fff !important;
  background: rgba(255,255,255,0.15);
}
.hero-banner {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 16px;
  padding: 3rem 2rem;
  margin-bottom: 2rem;
  text-align: center;
  box-shadow: 0 8px 30px rgba(102, 126, 234, 0.3);
}
.hero-banner h1 {
  font-weight: 800;
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
}
.hero-banner .lead {
  color: rgba(255,255,255,0.9);
  font-size: 1.15rem;
  max-width: 600px;
  margin: 0 auto;
}
.step-card {
  border: none;
  border-radius: 14px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.06);
  transition: transform 0.25s ease, box-shadow 0.25s ease;
  overflow: hidden;
  height: 100%;
  background: white;
}
.step-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0,0,0,0.1);
}
.step-icon-circle {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  color: white;
  flex-shrink: 0;
}
.step-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 1.25rem 1.25rem 0.75rem;
  font-weight: 700;
  font-size: 1.05rem;
}
.step-body {
  padding: 0 1.25rem 1.25rem;
  font-size: 0.92rem;
  color: #555;
}
.step-body ul {
  padding-left: 1.1rem;
  margin-bottom: 0;
}
.step-body li {
  margin-bottom: 0.3rem;
}
.tips-card {
  border: none;
  border-radius: 14px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.06);
  background: white;
}
.tips-card .card-header {
  background: transparent;
  border-bottom: 1px solid #eee;
  font-weight: 700;
  font-size: 1.05rem;
  color: #333;
}
.upload-section {
  background: white;
  border-radius: 14px;
  padding: 1.5rem;
  box-shadow: 0 4px 15px rgba(0,0,0,0.06);
  height: 100%;
}
.upload-section h4 {
  font-weight: 700;
  font-size: 1.1rem;
  color: #2c3e50;
  margin-bottom: 1rem;
}
.upload-section hr {
  border-color: #eee;
}
.section-divider {
  display: flex;
  align-items: center;
  text-align: center;
  color: #aaa;
  font-size: 0.85rem;
  font-weight: 600;
  margin: 1.25rem 0;
}
.section-divider::before,
.section-divider::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid #e0e0e0;
}
.section-divider::before { margin-right: 0.75rem; }
.section-divider::after  { margin-left: 0.75rem; }
.stat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-top: 1rem;
}
.stat-box {
  background: #f8f9fa;
  border-radius: 10px;
  padding: 0.75rem;
  text-align: center;
  border: 1px solid #e9ecef;
}
.stat-box .stat-value {
  font-size: 1.4rem;
  font-weight: 700;
  color: #2c3e50;
  display: block;
}
.stat-box .stat-label {
  font-size: 0.75rem;
  color: #888;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.status-banner {
  border-radius: 12px;
  padding: 1rem 1.25rem;
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 500;
  margin-bottom: 1.25rem;
}
.status-info {
  background: #eef2ff;
  color: #4361ee;
  border: 1px solid #c7d2fe;
}
.status-success {
  background: #ecfdf5;
  color: #059669;
  border: 1px solid #a7f3d0;
}
.preview-card {
  background: white;
  border-radius: 14px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.06);
  padding: 1.5rem;
}
.preview-card h5 {
  font-weight: 700;
  color: #2c3e50;
  margin-bottom: 1rem;
}
.placeholder-tab {
  text-align: center;
  padding: 4rem 2rem;
}
.placeholder-tab .placeholder-icon {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: #eef2ff;
  color: #667eea;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 2rem;
  margin-bottom: 1rem;
}
.placeholder-tab h3 {
  font-weight: 700;
  color: #333;
}
.placeholder-tab p {
  color: #888;
  max-width: 500px;
  margin: 0.5rem auto;
}
.app-footer {
  text-align: center;
  padding: 1.5rem;
  margin-top: 3rem;
  color: #aaa;
  font-size: 0.85rem;
  border-top: 1px solid #e9ecef;
}
.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
  border-radius: 8px;
  font-weight: 600;
  padding: 0.6rem 1.25rem;
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.btn-primary:hover {
  opacity: 0.9;
  transform: translateY(-1px);
}
.form-control, .shiny-input-container .form-control {
  border-radius: 8px;
  border: 1.5px solid #dee2e6;
}
.form-control:focus {
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.15);
}
"

# =============================================================================
# UI
# =============================================================================
ui <- navbarPage(
  title = span(icon("chart-line"), " Data Explorer"),
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$head(tags$style(HTML(custom_css))),
  
  tabPanel(
    "User Guide",
    icon = icon("book"),
    fluidPage(
      class = "mt-4 px-3",
      div(
        class = "hero-banner",
        h1("Welcome to Data Explorer"),
        p(class = "lead",
          "Upload, clean, transform, and visualize your datasets — all from one interactive dashboard.")
      ),
      fluidRow(
        column(6, class = "mb-4",
               div(class = "step-card",
                   div(class = "step-header",
                       span(class = "step-icon-circle",
                            style = "background: linear-gradient(135deg, #4361ee, #3a86ff);",
                            icon("upload")),
                       span("Step 1: Load Your Data")
                   ),
                   div(class = "step-body",
                       p("Head to the ", strong("Data Loading"), " tab to get started."),
                       tags$ul(
                         tags$li("Upload CSV, Excel (.xlsx/.xls), JSON, or RDS files (up to 30 MB)."),
                         tags$li("Or pick a built-in demo dataset to explore the app instantly."),
                         tags$li("Preview your data in an interactive, searchable table.")
                       )
                   ))
        ),
        column(6, class = "mb-4",
               div(class = "step-card",
                   div(class = "step-header",
                       span(class = "step-icon-circle",
                            style = "background: linear-gradient(135deg, #059669, #34d399);",
                            icon("broom")),
                       span("Step 2: Clean & Preprocess")
                   ),
                   div(class = "step-body",
                       p("Use the ", strong("Data Cleaning"), " tab to prepare your data."),
                       tags$ul(
                         tags$li("Handle missing values with drop or imputation strategies."),
                         tags$li("Remove duplicate rows and standardize formats."),
                         tags$li("Scale, normalize, and encode categorical variables."),
                         tags$li("Detect and handle outliers.")
                       )
                   ))
        ),
        column(6, class = "mb-4",
               div(class = "step-card",
                   div(class = "step-header",
                       span(class = "step-icon-circle",
                            style = "background: linear-gradient(135deg, #f59e0b, #fbbf24);",
                            icon("wrench")),
                       span("Step 3: Engineer Features")
                   ),
                   div(class = "step-body",
                       p("Visit the ", strong("Feature Engineering"), " tab to create new variables."),
                       tags$ul(
                         tags$li("Build new columns from math expressions, binning, or interactions."),
                         tags$li("Rename or drop existing columns."),
                         tags$li("See before-and-after previews of every change.")
                       )
                   ))
        ),
        column(6, class = "mb-4",
               div(class = "step-card",
                   div(class = "step-header",
                       span(class = "step-icon-circle",
                            style = "background: linear-gradient(135deg, #8b5cf6, #a78bfa);",
                            icon("chart-bar")),
                       span("Step 4: Explore & Visualize")
                   ),
                   div(class = "step-body",
                       p("Go to the ", strong("EDA"), " and ", strong("Interactive EDA"), " tabs to uncover insights."),
                       tags$ul(
                         tags$li("Use the EDA tab for summary statistics, correlation matrices, and the correlation heatmap."),
                         tags$li("Use the Interactive EDA tab for histograms, boxplots, scatter plots, bar charts, and dynamic row filtering."),
                         tags$li("Explore grouped summaries, filtered data previews, and plot-specific insights interactively.")
                       )
                   )
                   )
        )
      ),
      card(
        class = "tips-card mt-2",
        card_header(span(icon("lightbulb"), " Tips for Best Results")),
        card_body(
          tags$ul(
            tags$li("Start with the ", strong("Data Loading"), " tab — all other tabs depend on having a dataset loaded."),
            tags$li("Work through the tabs left to right: Load → Clean → Engineer → Explore.")
          )
        )
      ),
      card(
        class = "tips-card mt-3",
        card_header(span(icon("star"), " New in This Version")),
        card_body(
          tags$ul(
            tags$li("Use the ", strong("Interactive EDA"), " tab for plotly-based histograms, boxplots, scatter plots, row filters, and plot-specific insights."),
            tags$li("Use the expanded ", strong("Data Cleaning"), " tab for format standardization, label harmonization, numeric/date parsing, additional outlier treatment, and real-time feedback.")
          )
        )
      ),
      div(class = "app-footer", "Data Explorer — Applied Data Science, Spring 2026")
    )
  ),
  
  tabPanel(
    "Data Loading",
    icon = icon("upload"),
    fluidPage(
      class = "mt-4 px-3",
      fluidRow(
        column(3,
               div(class = "upload-section",
                   h4(icon("file-arrow-up"), " Upload a File"),
                   fileInput(
                     "file_upload", NULL,
                     accept = c(".csv", ".xlsx", ".xls", ".json", ".rds"),
                     placeholder = "CSV, Excel, JSON, or RDS"
                   ),
                   helpText("Supported: .csv, .xlsx, .xls, .json, .rds", br(), "Max size: 30 MB"),
                   div(class = "section-divider", "OR"),
                   h4(icon("database"), " Demo Dataset"),
                   selectInput("demo_data", NULL, choices = demo_choices),
                   actionButton("load_demo", "Load Demo Dataset", class = "btn-primary w-100", icon = icon("play")),
                   uiOutput("data_summary_panel")
               )
        ),
        column(9,
               uiOutput("load_status"),
               div(class = "preview-card",
                   h5(icon("table"), " Data Preview"),
                   DTOutput("data_preview")
               )
        )
      ),
      div(class = "app-footer", "Data Explorer — Applied Data Science, Spring 2026")
    )
  ),
  
  tabPanel(
    "Data Cleaning",
    icon = icon("broom"),
    sidebarLayout(
      sidebarPanel(
        h4("Cleaning Options"),
        selectInput("missing_method", "Handle Missing Values:",
                    choices = c("None", "Drop", "Mean", "Median", "Mode")),
        checkboxInput("remove_dup", "Remove duplicates"),
        selectInput("scaling", "Scaling:",
                    choices = c("None", "Standardize", "Normalize")),
        selectInput("encoding", "Encoding:",
                    choices = c("None", "Label", "One-hot")),
        checkboxInput("remove_outliers", "Remove Outliers"),
        tags$hr(),
        h5("Format Standardization"),
        checkboxInput("trim_text", "Trim whitespace in text columns", TRUE),
        checkboxInput("lowercase_text", "Convert text to lowercase", FALSE),
        checkboxInput("blank_to_na", "Convert blank / NA-like strings to missing", TRUE),
        checkboxInput("standardize_common_labels", "Standardize common categorical labels", TRUE),
        checkboxInput("parse_numeric_like", "Convert numeric-like text columns to numeric", TRUE),
        checkboxInput("try_parse_dates", "Standardize date-like text columns", TRUE),
        selectInput("extra_outlier_treatment", "Additional Outlier Treatment:",
                    choices = c("None", "Winsorize (5th/95th Percentile)", "Cap (1st/99th Percentile)"))
      ),
      mainPanel(
        h4("Cleaned Data Preview"),
        DTOutput("cleaned_preview"),
        br(),
        h4("Cleaning Feedback"),
        DTOutput("cleaning_feedback"),
        br(),
        h4("Type Changes"),
        DTOutput("cleaning_type_changes"),
        br(),
        verbatimTextOutput("cleaning_actions"),
        br(),
        downloadButton("download_cleaned_data", "Download Cleaned Data", class = "btn-primary")
      )
    )
  ),
  
  tabPanel(
    "Feature Engineering",
    icon = icon("wrench"),
    sidebarLayout(
      sidebarPanel(
        h4("Feature Engineering"),
        radioButtons(
          "fe_action",
          "Choose Action:",
          choices = c(
            "Create Math Feature" = "math",
            "Create Binned Feature" = "bin",
            "Create Interaction Feature" = "interaction",
            "Rename Column" = "rename",
            "Drop Columns" = "drop"
          ),
          selected = "math"
        ),
        conditionalPanel(
          condition = "input.fe_action == 'math'",
          textInput("fe_new_col_math", "New Column Name:", "new_feature"),
          selectInput("fe_math_col1", "Column 1:", choices = NULL),
          selectInput("fe_math_operator", "Operator:", choices = c("+", "-", "*", "/")),
          selectInput("fe_math_col2", "Column 2:", choices = NULL),
          actionButton("apply_math_feature", "Create Math Feature", class = "btn-primary")
        ),
        conditionalPanel(
          condition = "input.fe_action == 'bin'",
          selectInput("fe_bin_col", "Numeric Column to Bin:", choices = NULL),
          numericInput("fe_bin_k", "Number of Bins:", value = 4, min = 2, max = 20),
          textInput("fe_bin_new_col", "New Binned Column Name:", "binned_feature"),
          actionButton("apply_bin_feature", "Create Binned Feature", class = "btn-primary")
        ),
        conditionalPanel(
          condition = "input.fe_action == 'interaction'",
          textInput("fe_inter_new_col", "New Interaction Column Name:", "interaction_feature"),
          selectInput("fe_inter_col1", "Numeric Column 1:", choices = NULL),
          selectInput("fe_inter_col2", "Numeric Column 2:", choices = NULL),
          actionButton("apply_interaction_feature", "Create Interaction Feature", class = "btn-primary")
        ),
        conditionalPanel(
          condition = "input.fe_action == 'rename'",
          selectInput("fe_rename_old", "Column to Rename:", choices = NULL),
          textInput("fe_rename_new", "New Column Name:", ""),
          actionButton("apply_rename_column", "Rename Column", class = "btn-primary")
        ),
        conditionalPanel(
          condition = "input.fe_action == 'drop'",
          selectInput("fe_drop_cols", "Columns to Drop:", choices = NULL, multiple = TRUE),
          actionButton("apply_drop_columns", "Drop Selected Columns", class = "btn-primary")
        ),
        hr(),
        actionButton("reset_engineering", "Reset to Cleaned Data", icon = icon("rotate-left"))
      ),
      mainPanel(
        fluidRow(
          column(6, h4("Before"), DTOutput("fe_before_preview")),
          column(6, h4("After"), DTOutput("fe_after_preview"))
        ),
        br(),
        h4("Engineering Log"),
        verbatimTextOutput("fe_log"),
        br(),
        h4("Feature Change Summary"),
        DTOutput("fe_change_summary"),
        br(),
        downloadButton("download_engineered_data", "Download Engineered Data", class = "btn-primary")
      )
    )
  ),
  
  tabPanel(
    "EDA",
    icon = icon("chart-bar"),
    sidebarLayout(
      sidebarPanel(
        h4("EDA Controls"),
        selectInput("eda_columns", "Columns to Include:", choices = NULL, multiple = TRUE),
        checkboxInput("eda_show_summary", "Show Summary Statistics", TRUE),
        checkboxInput("eda_show_corr", "Show Correlation Matrix", TRUE)
      ),
      mainPanel(
        conditionalPanel(
          condition = "input.eda_show_summary == true",
          h4("Summary Statistics"),
          DTOutput("eda_summary_table"),
          br()
        ),
        conditionalPanel(
          condition = "input.eda_show_corr == true",
          h4("Correlation Matrix"),
          DTOutput("eda_corr_table"),
          br(),
          h4("Correlation Heatmap"),
          plotOutput("eda_corr_heatmap", height = "500px")
        )
      )
    )
  )
  ,
  tabPanel(
    "Interactive EDA",
    icon = icon("chart-line"),
    fluidPage(
      class = "mt-4 px-3",
      fluidRow(
        column(
          3,
          div(
            class = "upload-section",
            h4(icon("sliders-h"), " Interactive Controls"),
            selectInput("viz_columns", "Columns to Include:", choices = NULL, multiple = TRUE),
            tags$hr(),
            h4(icon("filter"), " Row Filter"),
            selectInput("viz_filter_col", "Filter Column:", choices = c("None")),
            uiOutput("viz_filter_value_ui"),
            tags$hr(),
            h4(icon("chart-line"), " Plot Settings"),
            selectInput("viz_plot_type", "Plot Type:",
                        choices = c("Histogram", "Boxplot", "Scatter Plot", "Bar Chart"),
                        selected = "Histogram"),
            selectInput("viz_x_var", "X Variable:", choices = NULL),
            conditionalPanel(
              condition = "input.viz_plot_type == 'Scatter Plot' || input.viz_plot_type == 'Boxplot'",
              selectInput("viz_y_var", "Y Variable:", choices = NULL)
            ),
            selectInput("viz_color_var", "Color By:", choices = c("None")),
            conditionalPanel(
              condition = "input.viz_plot_type == 'Histogram'",
              numericInput("viz_bins", "Histogram Bins:", value = 20, min = 5, max = 100, step = 1)
            ),
            conditionalPanel(
              condition = "input.viz_plot_type == 'Scatter Plot'",
              checkboxInput("viz_add_trendline", "Add Linear Trend Line", FALSE)
            ),
            tags$hr(),
            h4(icon("table"), " Grouped Summary"),
            selectInput("viz_group_var", "Group By:", choices = c("None")),
            selectInput("viz_metric_var", "Numeric Metric:", choices = c("None")),
            br(),
            downloadButton("download_viz_data", "Download Filtered Data", class = "btn-primary w-100")
          )
        ),
        column(
          9,
          div(
            class = "preview-card",
            h5(icon("chart-line"), " Interactive Visualization"),
            plotlyOutput("viz_plot", height = "550px")
          ),
          br(),
          div(
            class = "preview-card",
            h5(icon("chart-pie"), " Filtered Dataset Overview"),
            uiOutput("viz_overview")
          ),
          br(),
          div(
            class = "preview-card",
            h5(icon("info-circle"), " Dynamic Plot Insights"),
            verbatimTextOutput("viz_dynamic_insights")
          ),
          br(),
          div(
            class = "preview-card",
            h5(icon("table"), " Grouped Summary Table"),
            DTOutput("viz_group_summary")
          ),
          br(),
          div(
            class = "preview-card",
            h5(icon("table"), " Filtered Data Preview"),
            DTOutput("viz_preview")
          )
        )
      ),
      div(class = "app-footer", "Data Explorer — Applied Data Science, Spring 2026")
    )
  )
)

# =============================================================================
# SERVER
# =============================================================================
server <- function(input, output, session) {
  
  # ---- Shared reactive dataset ------------------------------------------------
  current_data <- reactiveVal(NULL)
  data_name <- reactiveVal(NULL)
  
  # ---- ADDED: helper functions (Student 4 Part) -------------------------------------
  keep_or_default <- function(current, choices, default_index = 1) {
    current <- normalize_input_vector(current)
    if (length(current) > 0 && current[1] %in% choices) {
      return(current[1])
    }
    if (length(choices) >= default_index) {
      return(choices[default_index])
    }
    if (length(choices) > 0) {
      return(choices[1])
    }
    character(0)
  }
  
  plot_formula <- function(var_name) {
    as.formula(paste0("~`", var_name, "`"))
  }
  
  normalize_input_vector <- function(x) {
    if (is.null(x)) {
      return(character(0))
    }
    if (is.list(x)) {
      x <- unlist(x, use.names = FALSE)
    }
    as.character(x)
  }
  
  get_numeric_cols <- function(df) {
    if (is.null(df) || ncol(df) == 0) {
      return(character(0))
    }
    flags <- vapply(df, is.numeric, logical(1))
    names(df)[flags]
  }
  
  get_categorical_cols <- function(df) {
    if (is.null(df) || ncol(df) == 0) {
      return(character(0))
    }
    flags <- vapply(df, function(x) is.character(x) || is.factor(x), logical(1))
    names(df)[flags]
  }
  
  get_date_cols <- function(df) {
    if (is.null(df) || ncol(df) == 0) {
      return(character(0))
    }
    flags <- vapply(df, inherits, logical(1), what = "Date")
    names(df)[flags]
  }

  # ---- Data loading: file upload ---------------------------------------------
  observeEvent(input$file_upload, {
    req(input$file_upload)
    
    tryCatch({
      df <- read_uploaded_file(
        input$file_upload$datapath,
        input$file_upload$name
      )
      current_data(df)
      data_name(input$file_upload$name)
      updateSelectInput(session, "demo_data", selected = "none")
      
      showNotification(
        paste0("Successfully loaded '", input$file_upload$name,
               "' (", nrow(df), " rows, ", ncol(df), " columns)"),
        type = "message", duration = 5
      )
    }, error = function(e) {
      current_data(NULL)
      data_name(NULL)
      showNotification(
        paste("Error reading file:", e$message),
        type = "error", duration = 8
      )
    })
  })
  
  # ---- Data loading: demo dataset --------------------------------------------
  observeEvent(input$load_demo, {
    req(input$demo_data != "none")
    
    df <- switch(input$demo_data,
                 "mtcars" = mtcars,
                 "iris" = iris)
    
    if (!is.null(df)) {
      current_data(df)
      data_name(input$demo_data)
      showNotification(
        paste0("Loaded demo dataset '", input$demo_data,
               "' (", nrow(df), " rows, ", ncol(df), " columns)"),
        type = "message", duration = 5
      )
    }
  })
  
  # ---- Status banner ----------------------------------------------------------
  output$load_status <- renderUI({
    if (is.null(current_data())) {
      div(
        class = "status-banner status-info",
        icon("info-circle"),
        span("No dataset loaded yet. Upload a file or select a demo dataset from the sidebar to get started.")
      )
    } else {
      div(
        class = "status-banner status-success",
        icon("check-circle"),
        span(paste0("Dataset loaded: ", data_name(),
                    " — ", nrow(current_data()), " rows, ",
                    ncol(current_data()), " columns"))
      )
    }
  })
  
  # ---- Summary panel ----------------------------------------------------------
  output$data_summary_panel <- renderUI({
    req(current_data())
    df <- current_data()
    
    num_cols <- sum(sapply(df, is.numeric))
    char_cols <- sum(sapply(df, is.character))
    factor_cols <- sum(sapply(df, is.factor))
    missing <- sum(is.na(df))
    
    tagList(
      hr(),
      h4(icon("chart-pie"), " Summary"),
      div(class = "stat-grid",
          div(class = "stat-box",
              span(class = "stat-value", nrow(df)),
              span(class = "stat-label", "Rows")),
          div(class = "stat-box",
              span(class = "stat-value", ncol(df)),
              span(class = "stat-label", "Columns")),
          div(class = "stat-box",
              span(class = "stat-value", num_cols),
              span(class = "stat-label", "Numeric")),
          div(class = "stat-box",
              span(class = "stat-value", char_cols + factor_cols),
              span(class = "stat-label", "Categorical")),
          div(class = "stat-box",
              span(class = "stat-value", missing),
              span(class = "stat-label", "Missing"))
      )
    )
  })
  
  # ---- Data preview -----------------------------------------------------------
  output$data_preview <- renderDT({
    req(current_data())
    datatable(
      current_data(),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        language = list(emptyTable = "No data to display")
      ),
      rownames = FALSE,
      filter = "top"
    )
  })
  
  # =============================================================================
  # DATA CLEANING SERVER LOGIC
  # =============================================================================
  cleaned_data <- reactive({
    req(current_data())
    df <- current_data()
  
      # ---- ADDED: standardization block ------------------------------
    if (isTRUE(input$trim_text) || isTRUE(input$lowercase_text) || isTRUE(input$blank_to_na) ||
        isTRUE(input$standardize_common_labels) || isTRUE(input$parse_numeric_like) ||
        isTRUE(input$try_parse_dates)) {
      df[] <- lapply(df, function(x) {
        if (is.factor(x)) {
          x <- as.character(x)
        }
        
        x <- standardize_text_column(
          x,
          trim_ws = isTRUE(input$trim_text),
          to_lower = isTRUE(input$lowercase_text),
          blank_to_na = isTRUE(input$blank_to_na)
        )
        
        if (isTRUE(input$standardize_common_labels)) {
          x <- canonicalize_common_labels(x, use_lowercase = isTRUE(input$lowercase_text))
        }
        
        if (isTRUE(input$parse_numeric_like)) {
          x <- try_parse_numeric_column(x)
        }
        
        if (isTRUE(input$try_parse_dates) && !inherits(x, "Date")) {
          x <- try_standardize_date_column(x)
        }
        
        x
      })
    }
    
    if (!is.null(input$missing_method) && input$missing_method != "None") {
      if (input$missing_method == "Drop") {
        df <- na.omit(df)
        
      } else if (input$missing_method == "Mean") {
        num_cols <- sapply(df, is.numeric)
        df[num_cols] <- lapply(df[num_cols], function(x) {
          x[is.na(x)] <- mean(x, na.rm = TRUE)
          x
        })
        
      } else if (input$missing_method == "Median") {
        num_cols <- sapply(df, is.numeric)
        df[num_cols] <- lapply(df[num_cols], function(x) {
          x[is.na(x)] <- median(x, na.rm = TRUE)
          x
        })
        
      } else if (input$missing_method == "Mode") {
        mode_func <- function(x) {
          x_non_na <- x[!is.na(x)]
          if (length(x_non_na) == 0) return(NA)
          ux <- unique(x_non_na)
          ux[which.max(tabulate(match(x_non_na, ux)))]
        }
        
        df[] <- lapply(df, function(x) {
          fill_value <- mode_func(x)
          x[is.na(x)] <- fill_value
          x
        })
      }
    }
    
    if (!is.null(input$remove_dup) && input$remove_dup) {
      df <- unique(df)
    }
    
    # ---- ADDED: additional outlier treatment -----------------------
    if (!is.null(input$extra_outlier_treatment) && input$extra_outlier_treatment != "None") {
      numeric_names <- names(df)[sapply(df, is.numeric)]
      if (length(numeric_names) > 0) {
        if (input$extra_outlier_treatment == "Winsorize (5th/95th Percentile)") {
          df[numeric_names] <- lapply(df[numeric_names], winsorize_vector)
        } else if (input$extra_outlier_treatment == "Cap (1st/99th Percentile)") {
          df[numeric_names] <- lapply(df[numeric_names], cap_vector)
        }
      }
    }
    
    if (!is.null(input$scaling) && input$scaling != "None") {
      num_cols <- sapply(df, is.numeric)
      
      if (any(num_cols)) {
        if (input$scaling == "Standardize") {
          scaled <- scale(df[num_cols])
          df[num_cols] <- as.data.frame(scaled)
          
        } else if (input$scaling == "Normalize") {
          df[num_cols] <- lapply(df[num_cols], function(x) {
            rng <- max(x, na.rm = TRUE) - min(x, na.rm = TRUE)
            if (is.na(rng) || rng == 0) {
              rep(0, length(x))
            } else {
              (x - min(x, na.rm = TRUE)) / rng
            }
          })
        }
      }
    }
    
    if (!is.null(input$encoding) && input$encoding != "None") {
      if (input$encoding == "Label") {
        df[] <- lapply(df, function(x) {
          if (is.character(x) || is.factor(x)) {
            as.numeric(as.factor(x))
          } else {
            x
          }
        })
        
      } else if (input$encoding == "One-hot") {
        df[] <- lapply(df, function(x) {
          if (is.character(x)) as.factor(x) else x
        })
        df <- as.data.frame(model.matrix(~ . - 1, data = df))
      }
    }
    
    if (!is.null(input$remove_outliers) && input$remove_outliers) {
      num_cols <- sapply(df, is.numeric)
      
      for (col in names(df)[num_cols]) {
        Q1 <- quantile(df[[col]], 0.25, na.rm = TRUE)
        Q3 <- quantile(df[[col]], 0.75, na.rm = TRUE)
        IQR_val <- Q3 - Q1
        
        if (!is.na(IQR_val) && IQR_val > 0) {
          lower <- Q1 - 1.5 * IQR_val
          upper <- Q3 + 1.5 * IQR_val
          keep <- is.na(df[[col]]) | (df[[col]] >= lower & df[[col]] <= upper)
          df <- df[keep, , drop = FALSE]
        }
      }
    }
    
    df
  })
  
  output$cleaned_preview <- renderDT({
    req(cleaned_data())
    datatable(
      cleaned_data(),
      options = list(pageLength = 10, scrollX = TRUE),
      rownames = FALSE,
      filter = "top"
    )
  })
  
  # ---- ADDED: feedback outputs ------------------------------------
  cleaning_feedback <- reactive({
    req(current_data(), cleaned_data())
    before <- current_data()
    after <- cleaned_data()
    
    data.frame(
      Metric = c("Rows", "Columns", "Missing Values", "Duplicate Rows", "Numeric Columns", "Categorical Columns", "Date Columns"),
      Before = c(
        nrow(before),
        ncol(before),
        sum(is.na(before)),
        sum(duplicated(before)),
        sum(sapply(before, is.numeric)),
        sum(sapply(before, function(x) is.character(x) || is.factor(x))),
        sum(sapply(before, inherits, what = "Date"))
      ),
      After = c(
        nrow(after),
        ncol(after),
        sum(is.na(after)),
        sum(duplicated(after)),
        sum(sapply(after, is.numeric)),
        sum(sapply(after, function(x) is.character(x) || is.factor(x))),
        sum(sapply(after, inherits, what = "Date"))
      ),
      stringsAsFactors = FALSE
    )
  })
  
  cleaning_type_changes <- reactive({
    req(current_data(), cleaned_data())
    before <- current_data()
    after <- cleaned_data()
    common_cols <- intersect(names(before), names(after))
    changes <- lapply(common_cols, function(col) {
      before_class <- class(before[[col]])[1]
      after_class <- class(after[[col]])[1]
      if (!identical(before_class, after_class)) {
        data.frame(
          Column = col,
          Before = before_class,
          After = after_class,
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
    })
    result <- do.call(rbind, changes)
    if (is.null(result) || nrow(result) == 0) {
      data.frame(Message = "No column type changes detected.", stringsAsFactors = FALSE)
    } else {
      result
    }
  })
  
  output$cleaning_feedback <- renderDT({
    req(cleaning_feedback())
    datatable(cleaning_feedback(), options = list(dom = "t"), rownames = FALSE)
  })
  
  output$cleaning_type_changes <- renderDT({
    req(cleaning_type_changes())
    datatable(cleaning_type_changes(), options = list(dom = "t", scrollX = TRUE), rownames = FALSE)
  })
  
  output$cleaning_actions <- renderText({
    actions <- c()
    
    if (isTRUE(input$trim_text)) {
      actions <- c(actions, "Trimmed whitespace in text columns")
    }
    if (isTRUE(input$lowercase_text)) {
      actions <- c(actions, "Converted text columns to lowercase")
    }
    if (isTRUE(input$blank_to_na)) {
      actions <- c(actions, "Converted blank / NA-like strings to missing values")
    }
    if (isTRUE(input$standardize_common_labels)) {
      actions <- c(actions, "Standardized common categorical labels")
    }
    if (isTRUE(input$parse_numeric_like)) {
      actions <- c(actions, "Converted numeric-like text columns to numeric when possible")
    }
    if (isTRUE(input$try_parse_dates)) {
      actions <- c(actions, "Attempted to standardize date-like text columns")
    }
    if (!is.null(input$missing_method) && input$missing_method != "None") {
      actions <- c(actions, paste("Missing-value method:", input$missing_method))
    }
    if (isTRUE(input$remove_dup)) {
      actions <- c(actions, "Removed duplicate rows")
    }
    if (!is.null(input$extra_outlier_treatment) && input$extra_outlier_treatment != "None") {
      actions <- c(actions, paste("Additional outlier treatment:", input$extra_outlier_treatment))
    }
    if (!is.null(input$scaling) && input$scaling != "None") {
      actions <- c(actions, paste("Scaling method:", input$scaling))
    }
    if (!is.null(input$encoding) && input$encoding != "None") {
      actions <- c(actions, paste("Encoding method:", input$encoding))
    }
    if (isTRUE(input$remove_outliers)) {
      actions <- c(actions, "Removed outliers using the IQR rule")
    }
    if (isTRUE(input$remove_outliers) && !is.null(input$extra_outlier_treatment) && input$extra_outlier_treatment != "None") {
      actions <- c(actions, "Note: both IQR removal and an additional outlier treatment are active.")
    }
    
    if (length(actions) == 0) {
      "No cleaning steps are currently selected."
    } else {
      paste("Active cleaning steps:\n-", paste(actions, collapse = "\n- "))
    }
  })
  
  
  output$download_cleaned_data <- downloadHandler(
    filename = function() {
      paste0("cleaned_data_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(cleaned_data())
      utils::write.csv(cleaned_data(), file, row.names = FALSE)
    }
  )
  
  # =============================================================================
  # FEATURE ENGINEERING SERVER LOGIC
  # =============================================================================
  engineered_data <- reactiveVal(NULL)
  fe_log <- reactiveVal("No feature engineering actions applied yet.")
  
  observe({
    req(cleaned_data())
    engineered_data(cleaned_data())
  })
  
  observe({
    req(engineered_data())
    df <- engineered_data()
    
    all_cols <- names(df)
    numeric_cols <- names(df)[sapply(df, is.numeric)]
    
    updateSelectInput(session, "fe_math_col1", choices = numeric_cols)
    updateSelectInput(session, "fe_math_col2", choices = numeric_cols)
    
    updateSelectInput(session, "fe_bin_col", choices = numeric_cols)
    
    updateSelectInput(session, "fe_inter_col1", choices = numeric_cols)
    updateSelectInput(session, "fe_inter_col2", choices = numeric_cols)
    
    updateSelectInput(session, "fe_rename_old", choices = all_cols)
    updateSelectInput(session, "fe_drop_cols", choices = all_cols)
    
    updateSelectInput(session, "eda_columns", choices = all_cols, selected = all_cols)
  })
  
  # ---- ADDED: selector synchronization -----------------------------
  observe({
    req(engineered_data())
    df <- engineered_data()
    all_cols <- names(df)
    selected_viz_cols <- all_cols
    
    if (!is.null(input$viz_columns)) {
      selected_viz_cols <- intersect(normalize_input_vector(input$viz_columns), all_cols)
      if (length(selected_viz_cols) == 0 && length(all_cols) > 0 && length(normalize_input_vector(input$viz_columns)) > 0) {
        selected_viz_cols <- all_cols
      }
    }
    
    updateSelectInput(session, "viz_columns", choices = all_cols, selected = selected_viz_cols)
    
    subset_df <- df
    if (length(selected_viz_cols) > 0) {
      subset_df <- df[, selected_viz_cols, drop = FALSE]
    } else {
      subset_df <- df[, 0, drop = FALSE]
    }
    
    subset_cols <- names(subset_df)
    numeric_cols <- get_numeric_cols(subset_df)
    categorical_cols <- get_categorical_cols(subset_df)
    
    updateSelectInput(
      session,
      "viz_filter_col",
      choices = c("None", subset_cols),
      selected = if (!is.null(input$viz_filter_col) && input$viz_filter_col %in% c("None", subset_cols)) {
        input$viz_filter_col
      } else {
        "None"
      }
    )
    
    updateSelectInput(
      session,
      "viz_color_var",
      choices = c("None", categorical_cols),
      selected = if (!is.null(input$viz_color_var) && input$viz_color_var %in% c("None", categorical_cols)) {
        input$viz_color_var
      } else {
        "None"
      }
    )
    
    updateSelectInput(
      session,
      "viz_group_var",
      choices = c("None", categorical_cols),
      selected = if (!is.null(input$viz_group_var) && input$viz_group_var %in% c("None", categorical_cols)) {
        input$viz_group_var
      } else {
        "None"
      }
    )
    
    updateSelectInput(
      session,
      "viz_metric_var",
      choices = c("None", numeric_cols),
      selected = if (!is.null(input$viz_metric_var) && input$viz_metric_var %in% c("None", numeric_cols)) {
        input$viz_metric_var
      } else {
        "None"
      }
    )
    
    plot_type <- input$viz_plot_type
    if (is.null(plot_type)) {
      plot_type <- "Histogram"
    }
    
    if (plot_type == "Histogram") {
      updateSelectInput(
        session,
        "viz_x_var",
        choices = numeric_cols,
        selected = keep_or_default(input$viz_x_var, numeric_cols, 1)
      )
      
      updateSelectInput(
        session,
        "viz_y_var",
        choices = character(0),
        selected = character(0)
      )
    }
    
    if (plot_type == "Boxplot") {
      x_choices <- c("All Data", categorical_cols)
      
      updateSelectInput(
        session,
        "viz_x_var",
        choices = x_choices,
        selected = keep_or_default(input$viz_x_var, x_choices, 1)
      )
      
      updateSelectInput(
        session,
        "viz_y_var",
        choices = numeric_cols,
        selected = keep_or_default(input$viz_y_var, numeric_cols, 1)
      )
    }
    
    if (plot_type == "Scatter Plot") {
      updateSelectInput(
        session,
        "viz_x_var",
        choices = numeric_cols,
        selected = keep_or_default(input$viz_x_var, numeric_cols, 1)
      )
      
      updateSelectInput(
        session,
        "viz_y_var",
        choices = numeric_cols,
        selected = keep_or_default(input$viz_y_var, numeric_cols, 2)
      )
    }
    
    if (plot_type == "Bar Chart") {
      updateSelectInput(
        session,
        "viz_x_var",
        choices = categorical_cols,
        selected = keep_or_default(input$viz_x_var, categorical_cols, 1)
      )
      
      updateSelectInput(
        session,
        "viz_y_var",
        choices = character(0),
        selected = character(0)
      )
    }
  })
  
  observeEvent(input$reset_engineering, {
    req(cleaned_data())
    engineered_data(cleaned_data())
    fe_log("Reset feature-engineered dataset back to cleaned data.")
    showNotification("Feature engineering reset to cleaned data.", type = "message")
  })
  
  observeEvent(input$apply_math_feature, {
    req(engineered_data(), input$fe_new_col_math, input$fe_math_col1, input$fe_math_col2)
    
    df <- engineered_data()
    new_col <- trimws(input$fe_new_col_math)
    
    if (new_col == "") {
      showNotification("Please provide a new column name.", type = "error")
      return()
    }
    
    if (new_col %in% names(df)) {
      showNotification("New column name already exists.", type = "error")
      return()
    }
    
    x <- df[[input$fe_math_col1]]
    y <- df[[input$fe_math_col2]]
    
    df[[new_col]] <- switch(
      input$fe_math_operator,
      "+" = x + y,
      "-" = x - y,
      "*" = x * y,
      "/" = ifelse(y == 0, NA, x / y)
    )
    
    engineered_data(df)
    fe_log(paste0("Created math feature '", new_col, "' using ",
                  input$fe_math_col1, " ", input$fe_math_operator, " ", input$fe_math_col2, "."))
    showNotification(paste("Created new feature:", new_col), type = "message")
  })
  
  observeEvent(input$apply_bin_feature, {
    req(engineered_data(), input$fe_bin_col, input$fe_bin_new_col)
    
    df <- engineered_data()
    new_col <- trimws(input$fe_bin_new_col)
    
    if (new_col == "") {
      showNotification("Please provide a new column name.", type = "error")
      return()
    }
    
    if (new_col %in% names(df)) {
      showNotification("New column name already exists.", type = "error")
      return()
    }
    
    if (!is.numeric(df[[input$fe_bin_col]])) {
      showNotification("Selected column must be numeric.", type = "error")
      return()
    }
    
    breaks <- unique(quantile(
      df[[input$fe_bin_col]],
      probs = seq(0, 1, length.out = input$fe_bin_k + 1),
      na.rm = TRUE
    ))
    
    if (length(breaks) <= 2) {
      showNotification("Not enough unique values to create bins.", type = "error")
      return()
    }
    
    df[[new_col]] <- cut(
      df[[input$fe_bin_col]],
      breaks = breaks,
      include.lowest = TRUE,
      dig.lab = 8
    )
    
    engineered_data(df)
    fe_log(paste0("Created binned feature '", new_col, "' from column '",
                  input$fe_bin_col, "' with ", input$fe_bin_k, " bins."))
    showNotification(paste("Created binned feature:", new_col), type = "message")
  })
  
  observeEvent(input$apply_interaction_feature, {
    req(engineered_data(), input$fe_inter_col1, input$fe_inter_col2, input$fe_inter_new_col)
    
    df <- engineered_data()
    new_col <- trimws(input$fe_inter_new_col)
    
    if (new_col == "") {
      showNotification("Please provide a new column name.", type = "error")
      return()
    }
    
    if (new_col %in% names(df)) {
      showNotification("New column name already exists.", type = "error")
      return()
    }
    
    df[[new_col]] <- df[[input$fe_inter_col1]] * df[[input$fe_inter_col2]]
    
    engineered_data(df)
    fe_log(paste0("Created interaction feature '", new_col, "' using ",
                  input$fe_inter_col1, " * ", input$fe_inter_col2, "."))
    showNotification(paste("Created interaction feature:", new_col), type = "message")
  })
  
  observeEvent(input$apply_rename_column, {
    req(engineered_data(), input$fe_rename_old, input$fe_rename_new)
    
    df <- engineered_data()
    new_name <- trimws(input$fe_rename_new)
    
    if (new_name == "") {
      showNotification("Please provide a new column name.", type = "error")
      return()
    }
    
    if (new_name %in% names(df)) {
      showNotification("New column name already exists.", type = "error")
      return()
    }
    
    names(df)[names(df) == input$fe_rename_old] <- new_name
    engineered_data(df)
    
    fe_log(paste0("Renamed column '", input$fe_rename_old, "' to '", new_name, "'."))
    showNotification(paste("Renamed", input$fe_rename_old, "to", new_name), type = "message")
  })
  
  observeEvent(input$apply_drop_columns, {
    req(engineered_data())
    
    df <- engineered_data()
    
    if (is.null(input$fe_drop_cols) || length(input$fe_drop_cols) == 0) {
      showNotification("Please select at least one column to drop.", type = "error")
      return()
    }
    
    if (length(input$fe_drop_cols) >= ncol(df)) {
      showNotification("Cannot drop all columns.", type = "error")
      return()
    }
    
    df <- df[, !(names(df) %in% input$fe_drop_cols), drop = FALSE]
    engineered_data(df)
    
    fe_log(paste0("Dropped column(s): ", paste(input$fe_drop_cols, collapse = ", "), "."))
    showNotification("Selected columns dropped.", type = "warning")
  })
  
  output$fe_before_preview <- renderDT({
    req(cleaned_data())
    datatable(cleaned_data(), options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
  })
  
  output$fe_after_preview <- renderDT({
    req(engineered_data())
    datatable(engineered_data(), options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
  })
  
  output$fe_log <- renderText({
    fe_log()
  })

  # ---- ADDED: Student 4 feature summary + download --------------------------
  fe_change_summary <- reactive({
    req(cleaned_data(), engineered_data())
    before <- cleaned_data()
    after <- engineered_data()
    new_cols <- setdiff(names(after), names(before))
    dropped_cols <- setdiff(names(before), names(after))
    
    data.frame(
      Metric = c("Rows Before", "Rows After", "Columns Before", "Columns After", "New Columns", "Dropped Columns"),
      Value = c(
        nrow(before),
        nrow(after),
        ncol(before),
        ncol(after),
        if (length(new_cols) == 0) "None" else paste(new_cols, collapse = ", "),
        if (length(dropped_cols) == 0) "None" else paste(dropped_cols, collapse = ", ")
      ),
      stringsAsFactors = FALSE
    )
  })
  
  output$fe_change_summary <- renderDT({
    req(fe_change_summary())
    datatable(fe_change_summary(), options = list(dom = "t", scrollX = TRUE), rownames = FALSE)
  })
  
  output$download_engineered_data <- downloadHandler(
    filename = function() {
      paste0("engineered_data_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(engineered_data())
      utils::write.csv(engineered_data(), file, row.names = FALSE)
    }
  )
  
  # =============================================================================
  # EDA SERVER LOGIC
  # =============================================================================
  eda_data <- reactive({
    req(engineered_data())
    df <- engineered_data()
    
    if (!is.null(input$eda_columns) && length(input$eda_columns) > 0) {
      df <- df[, input$eda_columns, drop = FALSE]
    }
    
    df
  })
  
  output$eda_summary_table <- renderDT({
    req(eda_data())
    df <- eda_data()
    
    summary_df <- data.frame(
      Column = names(df),
      Type = sapply(df, function(x) class(x)[1]),
      Missing = sapply(df, function(x) sum(is.na(x))),
      Unique_Values = sapply(df, function(x) length(unique(x))),
      stringsAsFactors = FALSE
    )
    
    numeric_cols <- sapply(df, is.numeric)
    
    summary_df$Mean <- NA
    summary_df$Median <- NA
    summary_df$SD <- NA
    summary_df$Min <- NA
    summary_df$Max <- NA
    
    if (any(numeric_cols)) {
      summary_df$Mean[numeric_cols]   <- sapply(df[numeric_cols], function(x) round(mean(x, na.rm = TRUE), 4))
      summary_df$Median[numeric_cols] <- sapply(df[numeric_cols], function(x) round(median(x, na.rm = TRUE), 4))
      summary_df$SD[numeric_cols]     <- sapply(df[numeric_cols], function(x) round(sd(x, na.rm = TRUE), 4))
      summary_df$Min[numeric_cols]    <- sapply(df[numeric_cols], function(x) round(min(x, na.rm = TRUE), 4))
      summary_df$Max[numeric_cols]    <- sapply(df[numeric_cols], function(x) round(max(x, na.rm = TRUE), 4))
    }
    
    datatable(summary_df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })
  
  output$eda_corr_table <- renderDT({
    req(eda_data())
    df <- eda_data()
    numeric_df <- df[, sapply(df, is.numeric), drop = FALSE]
    
    if (ncol(numeric_df) < 2) {
      return(
        datatable(
          data.frame(
            Message = "At least two numeric columns are required for a correlation matrix."
          ),
          options = list(dom = "t"),
          rownames = FALSE
        )
      )
    }
    
    corr_mat <- round(cor(numeric_df, use = "pairwise.complete.obs"), 4)
    corr_df <- data.frame(Variable = rownames(corr_mat), corr_mat, check.names = FALSE)
    
    datatable(
      corr_df,
      options = list(pageLength = 10, scrollX = TRUE),
      rownames = FALSE
    )
  })
  
  output$eda_corr_heatmap <- renderPlot({
    req(eda_data())
    df <- eda_data()
    numeric_df <- df[, sapply(df, is.numeric), drop = FALSE]
    
    if (ncol(numeric_df) < 2) {
      plot.new()
      text(0.5, 0.5, "At least two numeric columns are required for a correlation heatmap.")
      return()
    }
    
    corr_mat <- cor(numeric_df, use = "pairwise.complete.obs")
    
    op <- par(no.readonly = TRUE)
    on.exit(par(op))
    par(mar = c(8, 8, 3, 2))
    
    image(
      1:ncol(corr_mat),
      1:nrow(corr_mat),
      t(corr_mat[nrow(corr_mat):1, ]),
      axes = FALSE,
      xlab = "",
      ylab = "",
      main = "Correlation Heatmap"
    )
    
    axis(1, at = 1:ncol(corr_mat), labels = colnames(corr_mat), las = 2)
    axis(2, at = 1:nrow(corr_mat), labels = rev(rownames(corr_mat)), las = 2)
    
    for (i in 1:nrow(corr_mat)) {
      for (j in 1:ncol(corr_mat)) {
        text(j, nrow(corr_mat) - i + 1, labels = sprintf("%.2f", corr_mat[i, j]), cex = 0.8)
      }
    }
  })

# =============================================================================
  # INTERACTIVE EDA SERVER LOGIC
  # =============================================================================
  viz_data <- reactive({
    req(engineered_data())
    df <- engineered_data()
    
    viz_columns_selected <- normalize_input_vector(input$viz_columns)
    
    if (!is.null(input$viz_columns) && length(viz_columns_selected) > 0) {
      viz_columns_selected <- intersect(viz_columns_selected, names(df))
      if (length(viz_columns_selected) == 0) {
        viz_columns_selected <- names(df)
      }
      df <- df[, viz_columns_selected, drop = FALSE]
    } else if (!is.null(input$viz_columns) && length(viz_columns_selected) == 0) {
      df <- df[, 0, drop = FALSE]
    }
    
    df
  })
  
  filtered_viz_data <- reactive({
    req(viz_data())
    df <- viz_data()
    filter_col <- input$viz_filter_col
    
    if (is.null(filter_col) || filter_col == "None" || !(filter_col %in% names(df))) {
      return(df)
    }
    
    x <- df[[filter_col]]
    
    if (inherits(x, "Date")) {
      if (!is.null(input$viz_filter_date) && length(input$viz_filter_date) == 2) {
        start_date <- as.Date(input$viz_filter_date[1])
        end_date <- as.Date(input$viz_filter_date[2])
        keep <- !is.na(x) & x >= start_date & x <= end_date
        df <- df[keep, , drop = FALSE]
      }
    } else if (is.numeric(x)) {
      if (!is.null(input$viz_filter_num) && length(input$viz_filter_num) == 2) {
        keep <- !is.na(x) & x >= input$viz_filter_num[1] & x <= input$viz_filter_num[2]
        df <- df[keep, , drop = FALSE]
      }
    } else {
      if (!is.null(input$viz_filter_cat) && length(input$viz_filter_cat) > 0) {
        keep <- !is.na(x) & as.character(x) %in% input$viz_filter_cat
        df <- df[keep, , drop = FALSE]
      }
    }
    
    df
  })
  
  output$viz_filter_value_ui <- renderUI({
    req(viz_data())
    df <- viz_data()
    filter_col <- input$viz_filter_col
    
    if (is.null(filter_col) || filter_col == "None" || !(filter_col %in% names(df))) {
      return(NULL)
    }
    
    x <- df[[filter_col]]
    
    if (inherits(x, "Date")) {
      values <- x[!is.na(x)]
      if (length(values) == 0) {
        return(helpText("No non-missing dates are available for this filter."))
      }
      return(
        dateRangeInput(
          "viz_filter_date",
          "Date Range:",
          start = min(values),
          end = max(values)
        )
      )
    }
    
    if (is.numeric(x)) {
      rng <- range(x, na.rm = TRUE)
      if (!all(is.finite(rng))) {
        return(helpText("The selected numeric column does not have a usable range."))
      }
      if (rng[1] == rng[2]) {
        return(helpText("The selected numeric column has only one unique value."))
      }
      return(
        sliderInput(
          "viz_filter_num",
          "Numeric Range:",
          min = rng[1],
          max = rng[2],
          value = rng
        )
      )
    }
    
    choices <- sort(unique(as.character(x)))
    choices <- choices[!is.na(choices)]
    if (length(choices) == 0) {
      return(helpText("No non-missing values are available for this filter."))
    }
    selectInput(
      "viz_filter_cat",
      "Values:",
      choices = choices,
      selected = choices,
      multiple = TRUE
    )
  })
  
  output$viz_preview <- renderDT({
    req(filtered_viz_data())
    datatable(
      filtered_viz_data(),
      options = list(pageLength = 8, scrollX = TRUE),
      rownames = FALSE,
      filter = "top"
    )
  })
  
  output$viz_overview <- renderUI({
    req(filtered_viz_data())
    df <- filtered_viz_data()
    
    num_cols <- length(get_numeric_cols(df))
    categorical_cols <- length(get_categorical_cols(df))
    date_cols <- length(get_date_cols(df))
    missing_vals <- sum(is.na(df))
    
    div(
      class = "stat-grid",
      div(class = "stat-box",
          span(class = "stat-value", nrow(df)),
          span(class = "stat-label", "Rows")),
      div(class = "stat-box",
          span(class = "stat-value", ncol(df)),
          span(class = "stat-label", "Columns")),
      div(class = "stat-box",
          span(class = "stat-value", num_cols),
          span(class = "stat-label", "Numeric")),
      div(class = "stat-box",
          span(class = "stat-value", categorical_cols),
          span(class = "stat-label", "Categorical")),
      div(class = "stat-box",
          span(class = "stat-value", date_cols),
          span(class = "stat-label", "Date")),
      div(class = "stat-box",
          span(class = "stat-value", missing_vals),
          span(class = "stat-label", "Missing"))
    )
  })
  
  group_summary_data <- reactive({
    req(filtered_viz_data())
    df <- filtered_viz_data()
    group_var <- input$viz_group_var
    metric_var <- input$viz_metric_var
    
    if (is.null(group_var) || group_var == "None" || !(group_var %in% names(df)) ||
        is.null(metric_var) || metric_var == "None" || !(metric_var %in% names(df)) ||
        !is.numeric(df[[metric_var]])) {
      return(data.frame(
        Message = "Select a categorical group variable and a numeric metric to view grouped summaries.",
        stringsAsFactors = FALSE
      ))
    }
    
    temp <- data.frame(
      Group = as.character(df[[group_var]]),
      Metric = df[[metric_var]],
      stringsAsFactors = FALSE
    )
    temp <- temp[!is.na(temp$Group) & temp$Group != "", , drop = FALSE]
    
    if (nrow(temp) == 0) {
      return(data.frame(
        Message = "No grouped observations are available for the current filter settings.",
        stringsAsFactors = FALSE
      ))
    }
    
    split_metric <- split(temp$Metric, temp$Group)
    summary_df <- data.frame(
      Group = names(split_metric),
      Count = sapply(split_metric, function(x) sum(!is.na(x))),
      Mean = sapply(split_metric, function(x) round(mean(x, na.rm = TRUE), 4)),
      Median = sapply(split_metric, function(x) round(median(x, na.rm = TRUE), 4)),
      SD = sapply(split_metric, function(x) round(sd(x, na.rm = TRUE), 4)),
      Min = sapply(split_metric, function(x) round(min(x, na.rm = TRUE), 4)),
      Max = sapply(split_metric, function(x) round(max(x, na.rm = TRUE), 4)),
      stringsAsFactors = FALSE
    )
    
    summary_df[order(summary_df$Count, decreasing = TRUE), , drop = FALSE]
  })
  
  output$viz_group_summary <- renderDT({
    req(group_summary_data())
    datatable(group_summary_data(), options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
  })
  
  output$download_viz_data <- downloadHandler(
    filename = function() {
      paste0("interactive_eda_filtered_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(filtered_viz_data())
      utils::write.csv(filtered_viz_data(), file, row.names = FALSE)
    }
  )
  
  output$viz_dynamic_insights <- renderText({
    req(filtered_viz_data())
    df <- filtered_viz_data()
    
    if (nrow(df) == 0) {
      return("No rows are available after the current filter settings.")
    }
    
    plot_type <- input$viz_plot_type
    
    if (plot_type == "Histogram") {
      x_var <- input$viz_x_var
      if (is.null(x_var) || !(x_var %in% names(df)) || !is.numeric(df[[x_var]])) {
        return("Select a numeric X variable to view histogram insights.")
      }
      x <- df[[x_var]]
      complete_n <- sum(!is.na(x))
      missing_n <- sum(is.na(x))
      if (complete_n == 0) {
        return("The selected histogram variable has no non-missing values.")
      }
      return(paste(
        "Histogram insights",
        paste("Variable:", x_var),
        paste("Non-missing observations:", complete_n),
        paste("Missing values:", missing_n),
        paste("Mean:", round(mean(x, na.rm = TRUE), 4)),
        paste("Median:", round(median(x, na.rm = TRUE), 4)),
        paste("Standard deviation:", round(sd(x, na.rm = TRUE), 4)),
        paste("Minimum:", round(min(x, na.rm = TRUE), 4)),
        paste("Maximum:", round(max(x, na.rm = TRUE), 4)),
        sep = "\n"
      ))
    }
    
    if (plot_type == "Boxplot") {
      y_var <- input$viz_y_var
      x_var <- input$viz_x_var
      if (is.null(y_var) || !(y_var %in% names(df)) || !is.numeric(df[[y_var]])) {
        return("Select a numeric Y variable to view boxplot insights.")
      }
      y <- df[[y_var]]
      if (x_var == "All Data" || is.null(x_var) || !(x_var %in% names(df))) {
        return(paste(
          "Boxplot insights",
          paste("Variable:", y_var),
          paste("Median:", round(median(y, na.rm = TRUE), 4)),
          paste("Q1:", round(quantile(y, 0.25, na.rm = TRUE), 4)),
          paste("Q3:", round(quantile(y, 0.75, na.rm = TRUE), 4)),
          paste("IQR:", round(IQR(y, na.rm = TRUE), 4)),
          sep = "\n"
        ))
      }
      grouped <- aggregate(df[[y_var]], by = list(df[[x_var]]), FUN = median, na.rm = TRUE)
      names(grouped) <- c("Group", "Median")
      grouped <- grouped[order(grouped$Median, decreasing = TRUE), , drop = FALSE]
      top_text <- paste(utils::capture.output(print(head(grouped, 5), row.names = FALSE)), collapse = "\n")
      return(paste(
        "Boxplot insights",
        paste("Y variable:", y_var),
        paste("Grouping variable:", x_var),
        paste("Overall median:", round(median(y, na.rm = TRUE), 4)),
        "Top group medians:",
        top_text,
        sep = "\n"
      ))
    }
    
    if (plot_type == "Scatter Plot") {
      x_var <- input$viz_x_var
      y_var <- input$viz_y_var
      if (is.null(x_var) || is.null(y_var) || !(x_var %in% names(df)) || !(y_var %in% names(df))) {
        return("Select numeric X and Y variables to view scatter-plot insights.")
      }
      if (!is.numeric(df[[x_var]]) || !is.numeric(df[[y_var]])) {
        return("Scatter plot insights require numeric X and Y variables.")
      }
      complete_idx <- complete.cases(df[, c(x_var, y_var), drop = FALSE])
      complete_n <- sum(complete_idx)
      if (complete_n < 2) {
        return("At least two complete numeric observations are required for scatter-plot insights.")
      }
      fit_df <- data.frame(x = df[[x_var]][complete_idx], y = df[[y_var]][complete_idx])
      fit <- lm(y ~ x, data = fit_df)
      corr_val <- suppressWarnings(cor(fit_df$x, fit_df$y))
      slope_val <- unname(coef(fit)[2])
      intercept_val <- unname(coef(fit)[1])
      return(paste(
        "Scatter plot insights",
        paste("X variable:", x_var),
        paste("Y variable:", y_var),
        paste("Complete pairs:", complete_n),
        paste("Pearson correlation:", round(corr_val, 4)),
        paste("Linear slope:", round(slope_val, 4)),
        paste("Linear intercept:", round(intercept_val, 4)),
        sep = "\n"
      ))
    }
    
    if (plot_type == "Bar Chart") {
      x_var <- input$viz_x_var
      if (is.null(x_var) || !(x_var %in% names(df))) {
        return("Select a categorical X variable to view bar-chart insights.")
      }
      counts <- sort(table(as.character(df[[x_var]])), decreasing = TRUE)
      counts <- counts[names(counts) != "NA"]
      if (length(counts) == 0) {
        return("The selected bar-chart variable has no non-missing values.")
      }
      top_counts <- data.frame(
        Category = names(counts)[seq_len(min(5, length(counts)))],
        Count = as.integer(counts[seq_len(min(5, length(counts)))]),
        stringsAsFactors = FALSE
      )
      top_text <- paste(utils::capture.output(print(top_counts, row.names = FALSE)), collapse = "\n")
      return(paste(
        "Bar chart insights",
        paste("Variable:", x_var),
        paste("Distinct categories:", length(counts)),
        paste("Most frequent category:", names(counts)[1]),
        paste("Most frequent count:", as.integer(counts[1])),
        "Top category counts:",
        top_text,
        sep = "\n"
      ))
    }
    
    "Interactive plot insights are not available for the current settings."
  })
  
  output$viz_plot <- renderPlotly({
    req(filtered_viz_data())
    df <- filtered_viz_data()
    
    shiny::validate(
      shiny::need(nrow(df) > 0, "No rows are available after the current filter settings."),
      shiny::need(ncol(df) > 0, "Select at least one column in the Interactive EDA tab.")
    )
    
    plot_type <- input$viz_plot_type
    color_var <- input$viz_color_var
    use_color <- !is.null(color_var) && color_var != "None" && color_var %in% names(df)
    
    if (plot_type == "Histogram") {
      x_var <- input$viz_x_var
      shiny::validate(
        shiny::need(!is.null(x_var) && x_var %in% names(df), "Select a numeric X variable for the histogram."),
        shiny::need(is.numeric(df[[x_var]]), "Histogram requires a numeric X variable.")
      )
      if (use_color) {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          color = plot_formula(color_var),
          type = "histogram",
          nbinsx = input$viz_bins,
          opacity = 0.75
        )
      } else {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          type = "histogram",
          nbinsx = input$viz_bins
        )
      }
      p <- layout(
        p,
        title = paste("Histogram of", x_var),
        xaxis = list(title = x_var),
        yaxis = list(title = "Count"),
        barmode = "overlay"
      )
      return(p)
    }
    
    if (plot_type == "Boxplot") {
      x_var <- input$viz_x_var
      y_var <- input$viz_y_var
      shiny::validate(
        shiny::need(!is.null(y_var) && y_var %in% names(df), "Select a numeric Y variable for the boxplot."),
        shiny::need(is.numeric(df[[y_var]]), "Boxplot requires a numeric Y variable.")
      )
      if (is.null(x_var) || x_var == "All Data") {
        p <- plot_ly(
          df,
          y = plot_formula(y_var),
          type = "box"
        )
        p <- layout(
          p,
          title = paste("Boxplot of", y_var),
          xaxis = list(title = "All Data"),
          yaxis = list(title = y_var)
        )
        return(p)
      }
      shiny::validate(
        shiny::need(x_var %in% names(df), "Select a valid grouping variable for the boxplot.")
      )
      if (use_color) {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          y = plot_formula(y_var),
          color = plot_formula(color_var),
          type = "box"
        )
      } else {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          y = plot_formula(y_var),
          type = "box"
        )
      }
      p <- layout(
        p,
        title = paste("Boxplot of", y_var, "by", x_var),
        xaxis = list(title = x_var),
        yaxis = list(title = y_var)
      )
      return(p)
    }
    
    if (plot_type == "Scatter Plot") {
      x_var <- input$viz_x_var
      y_var <- input$viz_y_var
      shiny::validate(
        shiny::need(!is.null(x_var) && x_var %in% names(df), "Select a numeric X variable for the scatter plot."),
        shiny::need(!is.null(y_var) && y_var %in% names(df), "Select a numeric Y variable for the scatter plot."),
        shiny::need(is.numeric(df[[x_var]]), "Scatter plot requires a numeric X variable."),
        shiny::need(is.numeric(df[[y_var]]), "Scatter plot requires a numeric Y variable.")
      )
      if (use_color) {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          y = plot_formula(y_var),
          color = plot_formula(color_var),
          type = "scatter",
          mode = "markers"
        )
      } else {
        p <- plot_ly(
          df,
          x = plot_formula(x_var),
          y = plot_formula(y_var),
          type = "scatter",
          mode = "markers"
        )
      }
      if (isTRUE(input$viz_add_trendline)) {
        complete_idx <- complete.cases(df[, c(x_var, y_var), drop = FALSE])
        if (sum(complete_idx) >= 2) {
          fit_df <- data.frame(
            x = df[[x_var]][complete_idx],
            y = df[[y_var]][complete_idx]
          )
          fit <- lm(y ~ x, data = fit_df)
          trend_df <- data.frame(x = seq(min(fit_df$x), max(fit_df$x), length.out = 100))
          trend_df$y <- predict(fit, newdata = trend_df)
          p <- add_lines(
            p,
            data = trend_df,
            x = ~x,
            y = ~y,
            name = "Trend Line",
            inherit = FALSE
          )
        }
      }
      p <- layout(
        p,
        title = paste("Scatter Plot:", y_var, "vs", x_var),
        xaxis = list(title = x_var),
        yaxis = list(title = y_var)
      )
      return(p)
    }
    
    if (plot_type == "Bar Chart") {
      x_var <- input$viz_x_var
      shiny::validate(
        shiny::need(!is.null(x_var) && x_var %in% names(df), "Select a categorical X variable for the bar chart.")
      )
      
      if (use_color && color_var != x_var) {
        counts <- as.data.frame(table(Category = df[[x_var]], Group = df[[color_var]], useNA = "no"), stringsAsFactors = FALSE)
        names(counts)[3] <- "Count"
        counts <- counts[counts$Count > 0, , drop = FALSE]
        shiny::validate(shiny::need(nrow(counts) > 0, "No non-missing category counts are available for the selected bar chart."))
        p <- plot_ly(
          counts,
          x = ~Category,
          y = ~Count,
          color = ~Group,
          type = "bar"
        )
        p <- layout(
          p,
          title = paste("Bar Chart of", x_var, "grouped by", color_var),
          xaxis = list(title = x_var),
          yaxis = list(title = "Count"),
          barmode = "stack"
        )
      } else {
        counts <- as.data.frame(table(Category = df[[x_var]], useNA = "no"), stringsAsFactors = FALSE)
        names(counts) <- c("Category", "Count")
        counts <- counts[counts$Count > 0, , drop = FALSE]
        shiny::validate(shiny::need(nrow(counts) > 0, "No non-missing category counts are available for the selected bar chart."))
        p <- plot_ly(
          counts,
          x = ~Category,
          y = ~Count,
          type = "bar"
        )
        p <- layout(
          p,
          title = paste("Bar Chart of", x_var),
          xaxis = list(title = x_var),
          yaxis = list(title = "Count")
        )
      }
      return(p)
    }
    
    plot_ly()
  })
}

# ---- Run App -----------------------------------------------------------------
shinyApp(ui = ui, server = server)

