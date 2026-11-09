# =============================================================================
#  KENYA STEP SKILLS DASHBOARD
#  Data: World Bank STEP Employer Survey (2016) + Household Survey (2013)
#  Framework: Shiny + shinydashboard + plotly + DT
# =============================================================================
#
#  HOW TO RUN IN RSTUDIO
#  ─────────────────────
#  1. Open RStudio and create a new folder called  kenya_step_dashboard/
#  2. Put this file (app.R) inside that folder
#  3. Put the two cleaned CSVs (emp_clean.csv, hh_clean.csv) in the SAME folder
#     — see data_prep.R for how to generate them from the original ZIPs
#  4. Install packages (run once in the Console):
#       source("install_packages.R")
#  5. Click  Run App  or run:  shiny::runApp("kenya_step_dashboard")
# =============================================================================

library(shiny)
library(shinydashboard)
library(shinydashboardPlus)   # for extra box styles
library(plotly)
library(dplyr)
library(tidyr)
library(ggplot2)
library(DT)
library(scales)
library(stringr)

# ── 0. LOAD DATA ──────────────────────────────────────────────────────────────
# The CSVs are produced by data_prep.R from the original World Bank ZIPs.
# They must be in the same folder as app.R.
emp <- read.csv("emp_clean.csv", stringsAsFactors = FALSE)
hh  <- read.csv("hh_clean.csv",  stringsAsFactors = FALSE)

# Fix factor ordering
educ_levels <- c("None","Primary","Junior Sec","Secondary","Tertiary","University+")
hh$educ_group <- factor(hh$educ_group, levels = educ_levels, ordered = TRUE)

size_levels <- c("Micro(<10)","Small(10-50)","Medium(50-200)","Large(200+)")
emp$size_cat <- factor(emp$size_cat, levels = size_levels, ordered = TRUE)

# ── 1. COLOUR PALETTE ─────────────────────────────────────────────────────────
pal <- list(
  bg       = "#0f172a",
  surface  = "#1e293b",
  surface2 = "#263148",
  border   = "#334155",
  text     = "#e2e8f0",
  muted    = "#94a3b8",
  blue     = "#38bdf8",
  purple   = "#818cf8",
  green    = "#4ade80",
  orange   = "#fb923c",
  pink     = "#f472b6",
  red      = "#f87171",
  yellow   = "#fbbf24",
  teal     = "#2dd4bf"
)

# Plotly base layout (dark theme)
base_layout <- function(title = NULL) {
  list(
    paper_bgcolor = pal$surface,
    plot_bgcolor  = pal$surface,
    font          = list(color = pal$text, family = "Segoe UI, system-ui, sans-serif"),
    title         = if (!is.null(title)) list(text = title, font = list(size = 14, color = pal$text)) else NULL,
    xaxis         = list(gridcolor = pal$border, zerolinecolor = pal$border, tickfont = list(color = pal$muted)),
    yaxis         = list(gridcolor = pal$border, zerolinecolor = pal$border, tickfont = list(color = pal$muted)),
    legend        = list(bgcolor = "rgba(0,0,0,0)", font = list(color = pal$text)),
    margin        = list(l = 50, r = 20, t = 40, b = 50)
  )
}

# ── 2. UI ─────────────────────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = "purple",

  # ── Header ────────────────────────────────────────────────────────────────
  dashboardHeader(
    title = tags$span(
      tags$b("Kenya STEP"),
      tags$span(" | Skills Dashboard", style = "font-size:0.85em; color:#94a3b8;")
    ),
    titleWidth = 320
  ),

  # ── Sidebar ───────────────────────────────────────────────────────────────
  dashboardSidebar(
    width = 240,
    tags$style(HTML("
      .main-sidebar { background-color: #1e293b !important; }
      .sidebar-menu > li > a { color: #94a3b8 !important; }
      .sidebar-menu > li.active > a,
      .sidebar-menu > li > a:hover { color: #e2e8f0 !important; background: #263148 !important; }
      .sidebar-menu > li > a > .fa { color: #38bdf8 !important; }
    ")),
    sidebarMenu(
      id = "sidebar",
      menuItem("Overview",        tabName = "overview",  icon = icon("chart-pie")),
      menuItem("Skills Supply",   tabName = "supply",    icon = icon("user-graduate")),
      menuItem("Skills Demand",   tabName = "demand",    icon = icon("building")),
      menuItem("Skills Gap",      tabName = "gap",       icon = icon("arrows-left-right")),
      menuItem("Earnings Analysis", tabName = "earnings", icon = icon("coins"))
    ),
    tags$hr(style = "border-color:#334155; margin:10px 15px;"),
    tags$div(
      style = "padding:10px 15px; font-size:0.75rem; color:#94a3b8;",
      tags$b("Global Filters", style = "color:#e2e8f0; display:block; margin-bottom:8px;"),

      tags$label("Gender", style = "color:#94a3b8; font-size:0.72rem;"),
      checkboxGroupInput("filter_gender", NULL,
        choices  = c("Male","Female"),
        selected = c("Male","Female"),
        inline   = TRUE
      ),

      tags$label("Age Range", style = "color:#94a3b8; font-size:0.72rem;"),
      sliderInput("filter_age", NULL, min = 15, max = 64, value = c(15, 64), sep = ""),

      tags$label("Education", style = "color:#94a3b8; font-size:0.72rem;"),
      checkboxGroupInput("filter_educ", NULL,
        choices  = educ_levels,
        selected = educ_levels
      )
    ),
    tags$div(
      style = "padding:0 15px 15px; font-size:0.72rem; color:#64748b; line-height:1.5;",
      tags$b("Data Sources", style = "color:#94a3b8; display:block; margin-bottom:4px;"),
      "World Bank STEP Survey", tags$br(),
      tags$span("• HH Survey 2013 (n=3,894)", style = "display:block;"),
      tags$span("• Employer Survey 2016 (n=504)", style = "display:block;"),
      tags$br(),
      tags$span("Kenya Urban Areas", style = "color:#64748b;")
    )
  ),

  # ── Body ──────────────────────────────────────────────────────────────────
  dashboardBody(
    tags$head(tags$style(HTML("
      body, .content-wrapper, .main-footer { background-color: #0f172a !important; }
      .box { background: #1e293b !important; border: 1px solid #334155 !important;
             border-top: none !important; border-radius: 8px !important; }
      .box-header { background: #1e293b !important; border-bottom: 1px solid #334155 !important;
                    border-radius: 8px 8px 0 0 !important; color: #e2e8f0 !important; }
      .box-title { color: #e2e8f0 !important; font-size: 0.85rem !important; }
      .small-box { border-radius: 8px !important; }
      .small-box h3 { font-size: 1.8rem !important; }
      .small-box p  { font-size: 0.78rem !important; }
      h3.box-title  { font-size: 0.88rem !important; font-weight: 600; }
      .nav-tabs-custom { background: #1e293b !important; }
      .tab-content { background: #1e293b !important; }
      .dataTables_wrapper { color: #e2e8f0 !important; }
      table.dataTable thead th { background: #263148 !important; color: #94a3b8 !important;
                                  border-bottom: 1px solid #334155 !important; }
      table.dataTable tbody tr { background: #1e293b !important; color: #e2e8f0 !important; }
      table.dataTable tbody tr:hover { background: #263148 !important; }
      .dataTables_filter input, .dataTables_length select {
        background: #263148 !important; color: #e2e8f0 !important;
        border: 1px solid #334155 !important; }
      .selectize-input { background: #263148 !important; color: #e2e8f0 !important;
                         border: 1px solid #334155 !important; }
      .selectize-dropdown { background: #263148 !important; color: #e2e8f0 !important; }
      .irs--shiny .irs-bar { background: #38bdf8 !important; border-color: #38bdf8 !important; }
      .irs--shiny .irs-handle { background: #38bdf8 !important; border-color: #38bdf8 !important; }
      .checkbox label, .radio label { color: #94a3b8 !important; font-size: 0.75rem !important; }
    "))),

    tabItems(

      # ════════════════════════════════════════════════════════
      # TAB 1: OVERVIEW
      # ════════════════════════════════════════════════════════
      tabItem(tabName = "overview",

        # KPI row
        fluidRow(
          valueBoxOutput("kpi_hh",       width = 3),
          valueBoxOutput("kpi_firms",     width = 3),
          valueBoxOutput("kpi_unemp",     width = 3),
          valueBoxOutput("kpi_informal",  width = 3)
        ),
        fluidRow(
          valueBoxOutput("kpi_wage",      width = 3),
          valueBoxOutput("kpi_read",      width = 3),
          valueBoxOutput("kpi_skill_gap", width = 3),
          valueBoxOutput("kpi_training",  width = 3)
        ),

        fluidRow(
          box(title = "Employment Status Distribution",
              width = 6, solidHeader = TRUE, status = "primary",
              plotlyOutput("ov_emp_status", height = "280px")),

          box(title = "Employment by Gender",
              width = 6, solidHeader = TRUE, status = "primary",
              plotlyOutput("ov_gender_emp", height = "280px"))
        ),
        fluidRow(
          box(title = "Surveyed Firms by Sector",
              width = 8, solidHeader = TRUE, status = "info",
              plotlyOutput("ov_firm_sectors", height = "280px")),

          box(title = "Firm Size Distribution",
              width = 4, solidHeader = TRUE, status = "info",
              plotlyOutput("ov_firm_size", height = "280px"))
        )
      ),

      # ════════════════════════════════════════════════════════
      # TAB 2: SKILLS SUPPLY (Household Survey)
      # ════════════════════════════════════════════════════════
      tabItem(tabName = "supply",
        fluidRow(
          box(title = "Median Hourly Wage (USD) by Education Level",
              width = 6, solidHeader = TRUE, status = "primary",
              plotlyOutput("sup_earn_educ", height = "280px")),

          box(title = "Literacy Level by Gender (%)",
              width = 6, solidHeader = TRUE, status = "primary",
              plotlyOutput("sup_read_gender", height = "280px"))
        ),
        fluidRow(
          box(title = "Literacy Score by District (mean % of max score)",
              width = 8, solidHeader = TRUE, status = "info",
              selectInput("lit_order", "Sort by:",
                          c("Highest first" = "desc", "Lowest first" = "asc"),
                          width = "200px"),
              sliderInput("lit_top_n", "Show top N districts:",
                          min = 10, max = 78, value = 25, step = 5, width = "300px"),
              plotlyOutput("sup_lit_district", height = "340px")),

          box(title = "Workers Who Received Training by Sector (%)",
              width = 4, solidHeader = TRUE, status = "info",
              plotlyOutput("sup_train_sector", height = "400px"))
        ),
        fluidRow(
          box(title = "Socio-Emotional Skills Profile by Gender (1–4 scale)",
              width = 12, solidHeader = TRUE, status = "warning",
              plotlyOutput("sup_traits", height = "280px"))
        )
      ),

      # ════════════════════════════════════════════════════════
      # TAB 3: SKILLS DEMAND (Employer Survey)
      # ════════════════════════════════════════════════════════
      tabItem(tabName = "demand",
        fluidRow(
          box(title = "Firms Reporting Difficulty Finding Skilled Workers by Sector (%)",
              width = 8, solidHeader = TRUE, status = "primary",
              radioButtons("demand_skill_type", "Skill Type:",
                           c("Soft Skills" = "diff_soft", "Technical Skills" = "diff_tech"),
                           inline = TRUE),
              plotlyOutput("dem_skill_sector", height = "320px")),

          box(title = "Firms by City",
              width = 4, solidHeader = TRUE, status = "primary",
              plotlyOutput("dem_city", height = "360px"))
        ),
        fluidRow(
          box(title = "Firms Providing Training by Sector (%)",
              width = 6, solidHeader = TRUE, status = "info",
              plotlyOutput("dem_train_sector", height = "280px")),

          box(title = "Training Provision by Firm Size (%)",
              width = 6, solidHeader = TRUE, status = "info",
              plotlyOutput("dem_train_size", height = "280px"))
        ),
        fluidRow(
          box(title = "Firms Reporting Unfilled Vacancies by Sector (%)",
              width = 12, solidHeader = TRUE, status = "warning",
              plotlyOutput("dem_vacancies", height = "260px"))
        )
      ),

      # ════════════════════════════════════════════════════════
      # TAB 4: SKILLS GAP
      # ════════════════════════════════════════════════════════
      tabItem(tabName = "gap",
        fluidRow(
          box(title = "Skills Gap: Employer Difficulty vs Worker Training Rate",
              width = 12, solidHeader = TRUE, status = "primary",
              tags$p("Bubble size = number of firms surveyed. Sectors above dashed line face more soft-skill gaps.",
                     style = "font-size:0.75rem; color:#94a3b8; margin-bottom:8px;"),
              plotlyOutput("gap_bubble", height = "380px"))
        ),
        fluidRow(
          box(title = "Wage Premium & Employment Rate by Education Level",
              width = 6, solidHeader = TRUE, status = "info",
              plotlyOutput("gap_educ_wage", height = "300px")),

          box(title = "Formal vs Informal Earnings by Sector (Median USD/hr)",
              width = 6, solidHeader = TRUE, status = "info",
              plotlyOutput("gap_formal_informal", height = "300px"))
        ),
        fluidRow(
          box(title = "Education–Skills–Employment Summary Table",
              width = 12, solidHeader = TRUE, status = "warning",
              DTOutput("gap_table"))
        )
      ),

      # ════════════════════════════════════════════════════════
      # TAB 5: EARNINGS ANALYSIS
      # ════════════════════════════════════════════════════════
      tabItem(tabName = "earnings",
        fluidRow(
          box(title = "Hourly Wage Distribution by Gender (USD)",
              width = 6, solidHeader = TRUE, status = "primary",
              tags$p("Capped at 95th percentile to reduce outlier distortion.",
                     style = "font-size:0.75rem; color:#94a3b8; margin-bottom:8px;"),
              plotlyOutput("earn_box", height = "300px")),

          box(title = "Median Wage by Occupation (USD/hr)",
              width = 6, solidHeader = TRUE, status = "primary",
              plotlyOutput("earn_occ", height = "300px"))
        ),
        fluidRow(
          box(title = "Wage by Education × Gender (Median USD/hr)",
              width = 7, solidHeader = TRUE, status = "info",
              plotlyOutput("earn_educ_gender", height = "300px")),

          box(title = "Earnings Explorer",
              width = 5, solidHeader = TRUE, status = "info",
              tags$b("Wage quantiles by selected variable", style = "color:#94a3b8; font-size:0.78rem;"),
              selectInput("earn_group_var", "Group by:",
                          c("Education" = "educ_group",
                            "Occupation" = "occ_label",
                            "Sector"     = "sector_label",
                            "Gender"     = "gender_label"),
                          width = "100%"),
              plotlyOutput("earn_explorer", height = "260px"))
        )
      )

    ) # end tabItems
  ) # end dashboardBody
) # end dashboardPage


# ── 3. SERVER ─────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # ── Reactive filtered datasets ──────────────────────────────────────────────
  hh_f <- reactive({
    hh %>%
      filter(
        gender_label %in% input$filter_gender,
        age >= input$filter_age[1],
        age <= input$filter_age[2],
        is.na(educ_group) | educ_group %in% input$filter_educ
      )
  })

  # emp is not filtered by HH filters (different survey)
  emp_f <- reactive({ emp })

  # ── Helper: plotly dark config ───────────────────────────────────────────────
  dark_config <- function(p) {
    p %>% layout(
      paper_bgcolor = pal$surface,
      plot_bgcolor  = pal$surface,
      font  = list(color = pal$text, family = "Segoe UI, system-ui"),
      xaxis = list(gridcolor = pal$border, zerolinecolor = pal$border,
                   tickfont  = list(color = pal$muted)),
      yaxis = list(gridcolor = pal$border, zerolinecolor = pal$border,
                   tickfont  = list(color = pal$muted)),
      legend = list(bgcolor = "rgba(0,0,0,0)", font = list(color = pal$text)),
      margin = list(l = 50, r = 20, t = 30, b = 50)
    ) %>%
      config(displayModeBar = FALSE)
  }

  # ══════════════════════════════════════════════════════════════════
  # KPI VALUE BOXES
  # ══════════════════════════════════════════════════════════════════
  output$kpi_hh <- renderValueBox({
    valueBox(format(nrow(hh_f()), big.mark = ","), "Workers Surveyed",
             icon = icon("users"), color = "light-blue")
  })
  output$kpi_firms <- renderValueBox({
    valueBox(nrow(emp_f()), "Firms Surveyed",
             icon = icon("building"), color = "purple")
  })
  output$kpi_unemp <- renderValueBox({
    d <- hh_f() %>% filter(emp_status %in% c("Unemployed","Wage Worker","Informal Wage"))
    pct <- if (nrow(d) > 0) round(mean(d$emp_status == "Unemployed") * 100, 1) else 0
    valueBox(paste0(pct, "%"), "Unemployment Rate",
             icon = icon("person-walking-arrow-right"), color = "red")
  })
  output$kpi_informal <- renderValueBox({
    d <- hh_f() %>% filter(emp_status %in% c("Wage Worker","Informal Wage"))
    pct <- if (nrow(d) > 0) round(mean(d$emp_status == "Informal Wage") * 100, 1) else 0
    valueBox(paste0(pct, "%"), "Informal Employment Share",
             icon = icon("handshake-slash"), color = "orange")
  })
  output$kpi_wage <- renderValueBox({
    med <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0) %>%
      pull(earnings_h_usd) %>% median() %>% round(2)
    valueBox(paste0("$", med), "Median Hourly Wage (USD)",
             icon = icon("dollar-sign"), color = "green")
  })
  output$kpi_read <- renderValueBox({
    pct <- round(mean(hh_f()$read_label == "Full Passage", na.rm = TRUE) * 100, 1)
    valueBox(paste0(pct, "%"), "Full Literacy Rate",
             icon = icon("book-open"), color = "teal")
  })
  output$kpi_skill_gap <- renderValueBox({
    pct <- round(mean(emp_f()$diff_tech, na.rm = TRUE) * 100, 1)
    valueBox(paste0(pct, "%"), "Firms: Tech-Skills Gap",
             icon = icon("triangle-exclamation"), color = "yellow")
  })
  output$kpi_training <- renderValueBox({
    pct <- round(mean(emp_f()$provides_training, na.rm = TRUE) * 100, 1)
    valueBox(paste0(pct, "%"), "Firms Providing Training",
             icon = icon("chalkboard-teacher"), color = "blue")
  })

  # ══════════════════════════════════════════════════════════════════
  # TAB 1 – OVERVIEW
  # ══════════════════════════════════════════════════════════════════
  output$ov_emp_status <- renderPlotly({
    d <- hh_f() %>% count(emp_status)
    colors <- c("Wage Worker" = pal$blue, "Informal Wage" = pal$orange,
                "Unemployed" = pal$red,  "Inactive" = pal$muted)
    plot_ly(d, labels = ~emp_status, values = ~n, type = "pie",
            marker = list(colors = colors[d$emp_status],
                          line   = list(color = pal$surface, width = 2)),
            textinfo = "label+percent", hoverinfo = "label+value+percent") %>%
      dark_config()
  })

  output$ov_gender_emp <- renderPlotly({
    d <- hh_f() %>%
      group_by(gender_label, emp_status) %>%
      summarise(n = n(), .groups = "drop") %>%
      group_by(gender_label) %>%
      mutate(pct = round(n / sum(n) * 100, 1))

    colors <- c("Wage Worker" = pal$blue, "Informal Wage" = pal$orange,
                "Unemployed" = pal$red,  "Inactive" = pal$muted)

    plot_ly(d, x = ~gender_label, y = ~pct, color = ~emp_status,
            colors = unname(colors[unique(d$emp_status)]),
            type = "bar", text = ~paste0(pct, "%"),
            textposition = "inside", hoverinfo = "x+name+text") %>%
      layout(barmode = "stack", xaxis = list(title = ""),
             yaxis = list(title = "Share (%)")) %>%
      dark_config()
  })

  output$ov_firm_sectors <- renderPlotly({
    d <- emp_f() %>% count(sector_label) %>% arrange(n)
    plot_ly(d, x = ~n, y = ~reorder(sector_label, n), type = "bar",
            orientation = "h",
            marker = list(color = pal$purple,
                          line = list(color = pal$border, width = 0.5)),
            text = ~n, textposition = "outside",
            hovertemplate = "<b>%{y}</b><br>Firms: %{x}<extra></extra>") %>%
      layout(xaxis = list(title = "Number of Firms"),
             yaxis = list(title = "")) %>%
      dark_config()
  })

  output$ov_firm_size <- renderPlotly({
    d <- emp_f() %>%
      count(size_cat) %>%
      mutate(size_cat = factor(size_cat, levels = size_levels))
    plot_ly(d, x = ~size_cat, y = ~n, type = "bar",
            marker = list(color = c(pal$teal, pal$blue, pal$purple, pal$pink)),
            text = ~n, textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>Firms: %{y}<extra></extra>") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Firms")) %>%
      dark_config()
  })

  # ══════════════════════════════════════════════════════════════════
  # TAB 2 – SKILLS SUPPLY
  # ══════════════════════════════════════════════════════════════════
  output$sup_earn_educ <- renderPlotly({
    d <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0, !is.na(educ_group)) %>%
      group_by(educ_group) %>%
      summarise(median_wage = median(earnings_h_usd),
                n = n(), .groups = "drop") %>%
      arrange(educ_group)

    plot_ly(d, x = ~educ_group, y = ~median_wage, type = "scatter", mode = "lines+markers",
            line   = list(color = pal$blue, width = 3),
            marker = list(color = pal$blue, size = 9,
                          line = list(color = pal$surface, width = 2)),
            text = ~paste0("$", round(median_wage, 2), " (n=", n, ")"),
            hovertemplate = "<b>%{x}</b><br>Median wage: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "Education Level"),
             yaxis = list(title = "Median USD/hr")) %>%
      dark_config()
  })

  output$sup_read_gender <- renderPlotly({
    read_order <- c("Cannot Read","Letters Only","Words","Full Passage")
    d <- hh_f() %>%
      filter(!is.na(read_label)) %>%
      group_by(gender_label, read_label) %>%
      summarise(n = n(), .groups = "drop") %>%
      group_by(gender_label) %>%
      mutate(pct = round(n / sum(n) * 100, 1),
             read_label = factor(read_label, levels = read_order))

    plot_ly(d, x = ~read_label, y = ~pct, color = ~gender_label,
            colors = c("Male" = pal$blue, "Female" = pal$pink),
            type = "bar", text = ~paste0(pct, "%"),
            textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>%{data.name}: %{text}<extra></extra>") %>%
      layout(barmode = "group",
             xaxis = list(title = "Literacy Level", categoryorder = "array",
                          categoryarray = read_order),
             yaxis = list(title = "Share (%)")) %>%
      dark_config()
  })

  output$sup_lit_district <- renderPlotly({
    d <- hh_f() %>%
      group_by(district_clean) %>%
      summarise(mean_lit = round(mean(literacy_pct, na.rm = TRUE), 1),
                n = n(), .groups = "drop") %>%
      filter(n >= 10)

    if (input$lit_order == "desc") {
      d <- d %>% arrange(desc(mean_lit)) %>% head(input$lit_top_n)
    } else {
      d <- d %>% arrange(mean_lit) %>% head(input$lit_top_n)
    }

    # Color gradient: red → green
    col_vals <- scales::rescale(d$mean_lit)
    fill_cols <- scales::col_numeric(c(pal$red, pal$yellow, pal$green), domain = NULL)(col_vals)

    plot_ly(d, x = ~mean_lit, y = ~reorder(district_clean, mean_lit),
            type = "bar", orientation = "h",
            marker = list(color = fill_cols),
            text  = ~paste0(mean_lit, "%"),
            textposition = "outside",
            hovertemplate = "<b>%{y}</b><br>Literacy: %{x}%<extra></extra>") %>%
      layout(xaxis = list(title = "Mean Literacy Score (% of max)"),
             yaxis = list(title = "")) %>%
      dark_config()
  })

  output$sup_train_sector <- renderPlotly({
    d <- hh_f() %>%
      group_by(sector_label) %>%
      summarise(pct = round(mean(has_training, na.rm = TRUE) * 100, 1),
                n   = n(), .groups = "drop") %>%
      filter(n >= 20, sector_label != "Unknown") %>%
      arrange(pct)

    plot_ly(d, x = ~pct, y = ~reorder(sector_label, pct),
            type = "bar", orientation = "h",
            marker = list(color = pal$teal,
                          line  = list(color = pal$border, width = 0.5)),
            text = ~paste0(pct, "%"), textposition = "outside",
            hovertemplate = "<b>%{y}</b><br>Trained: %{x}%<extra></extra>") %>%
      layout(xaxis = list(title = "% Received Training"),
             yaxis = list(title = "")) %>%
      dark_config()
  })

  output$sup_traits <- renderPlotly({
    trait_cols  <- c("extraversion_av","conscientiousness_av","openness_av",
                     "agreeableness_av","grit_av")
    trait_names <- c("Extraversion","Conscientiousness","Openness","Agreeableness","Grit")

    d <- hh_f() %>%
      group_by(gender_label) %>%
      summarise(across(all_of(trait_cols), ~ round(mean(.x, na.rm = TRUE), 3)),
                .groups = "drop") %>%
      pivot_longer(-gender_label, names_to = "col", values_to = "mean") %>%
      mutate(trait = trait_names[match(col, trait_cols)])

    plot_ly(d, x = ~trait, y = ~mean, color = ~gender_label,
            colors = c("Male" = pal$blue, "Female" = pal$pink),
            type = "bar",
            text  = ~round(mean, 2), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>%{data.name}: %{y:.2f}<extra></extra>") %>%
      layout(barmode = "group",
             xaxis = list(title = ""),
             yaxis = list(title = "Mean Score (1–4)", range = c(0, 4.2))) %>%
      dark_config()
  })

  # ══════════════════════════════════════════════════════════════════
  # TAB 3 – SKILLS DEMAND
  # ══════════════════════════════════════════════════════════════════
  output$dem_skill_sector <- renderPlotly({
    var  <- input$demand_skill_type
    col_c <- if (var == "diff_soft") pal$orange else pal$purple
    ylab  <- if (var == "diff_soft") "Soft-Skill Gap (%)" else "Tech-Skill Gap (%)"

    d <- emp_f() %>%
      group_by(sector_label) %>%
      summarise(pct = round(mean(.data[[var]], na.rm = TRUE) * 100, 1),
                n   = n(), .groups = "drop") %>%
      arrange(desc(pct))

    plot_ly(d, x = ~reorder(sector_label, -pct), y = ~pct,
            type = "bar",
            marker = list(color  = col_c,
                          line   = list(color = pal$border, width = 0.5)),
            text = ~paste0(pct, "%"), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>Difficulty: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "", tickangle = -35),
             yaxis = list(title = ylab, range = c(0, 115))) %>%
      dark_config()
  })

  output$dem_city <- renderPlotly({
    d <- emp_f() %>% count(city) %>% arrange(n)
    plot_ly(d, labels = ~city, values = ~n, type = "pie",
            hole = 0.4,
            marker = list(colors = c(pal$blue, pal$purple, pal$green,
                                     pal$orange, pal$pink, pal$teal,
                                     pal$yellow, pal$red, "#a78bfa",
                                     "#67e8f9", "#86efac", "#fca5a5", "#fde68a"),
                          line    = list(color = pal$surface, width = 2)),
            textinfo = "label+percent",
            hoverinfo = "label+value") %>%
      dark_config()
  })

  output$dem_train_sector <- renderPlotly({
    d <- emp_f() %>%
      group_by(sector_label) %>%
      summarise(pct = round(mean(provides_training, na.rm = TRUE) * 100, 1),
                n   = n(), .groups = "drop") %>%
      arrange(desc(pct))

    plot_ly(d, x = ~reorder(sector_label, -pct), y = ~pct,
            type = "bar",
            marker = list(color = pal$green,
                          line  = list(color = pal$border, width = 0.5)),
            text = ~paste0(pct, "%"), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>Training: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "", tickangle = -35),
             yaxis = list(title = "% Firms Providing Training",
                          range = c(0, 115))) %>%
      dark_config()
  })

  output$dem_train_size <- renderPlotly({
    d <- emp_f() %>%
      mutate(size_cat = factor(size_cat, levels = size_levels)) %>%
      group_by(size_cat) %>%
      summarise(pct = round(mean(provides_training, na.rm = TRUE) * 100, 1),
                n   = n(), .groups = "drop")

    plot_ly(d, x = ~size_cat, y = ~pct, type = "bar",
            marker = list(color  = c(pal$teal, pal$blue, pal$purple, pal$pink),
                          line   = list(color = pal$border, width = 0.5)),
            text = ~paste0(pct, "% (n=", n, ")"), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>%{text}<extra></extra>") %>%
      layout(xaxis = list(title = "Firm Size Category"),
             yaxis = list(title = "% Providing Training", range = c(0, 100))) %>%
      dark_config()
  })

  output$dem_vacancies <- renderPlotly({
    d <- emp_f() %>%
      group_by(sector_label) %>%
      summarise(pct = round(mean(has_vacancies, na.rm = TRUE) * 100, 1),
                n   = n(), .groups = "drop") %>%
      arrange(desc(pct))

    plot_ly(d, x = ~reorder(sector_label, -pct), y = ~pct,
            type = "bar",
            marker = list(color  = pal$red,
                          line   = list(color = pal$border, width = 0.5)),
            text = ~paste0(pct, "%"), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>Vacancies: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "", tickangle = -35),
             yaxis = list(title = "% Firms with Unfilled Vacancies",
                          range = c(0, 115))) %>%
      dark_config()
  })

  # ══════════════════════════════════════════════════════════════════
  # TAB 4 – SKILLS GAP
  # ══════════════════════════════════════════════════════════════════
  output$gap_bubble <- renderPlotly({
    # Demand side: employer difficulty by sector
    demand_d <- emp_f() %>%
      group_by(sector_label) %>%
      summarise(pct_diff_soft = round(mean(diff_soft, na.rm = TRUE) * 100, 1),
                pct_diff_tech = round(mean(diff_tech, na.rm = TRUE) * 100, 1),
                n_firms       = n(), .groups = "drop")

    # Supply side: worker training rate by sector (HH)
    supply_d <- hh_f() %>%
      filter(sector_label != "Unknown") %>%
      group_by(sector_label) %>%
      summarise(pct_trained = round(mean(has_training, na.rm = TRUE) * 100, 1),
                .groups = "drop")

    # Map HH sector to EMP sector (broad alignment)
    hh_to_emp <- c("Agriculture" = "Agriculture", "Industry" = "Manufacturing",
                   "Trade/Commerce" = "Trade/Retail", "Services" = "Other Services")

    supply_d <- supply_d %>%
      mutate(sector_label = recode(sector_label, !!!hh_to_emp)) %>%
      filter(sector_label %in% demand_d$sector_label)

    d <- inner_join(demand_d, supply_d, by = "sector_label")

    plot_ly(d,
            x = ~pct_trained, y = ~pct_diff_soft,
            size = ~n_firms, text = ~sector_label,
            type = "scatter", mode = "markers+text",
            textposition = "top center",
            marker = list(
              color  = ~pct_diff_tech,
              colorscale = list(c(0, pal$green), c(0.5, pal$yellow), c(1, pal$red)),
              showscale  = TRUE,
              colorbar   = list(title = "Tech Gap %",
                                tickfont = list(color = pal$muted),
                                titlefont = list(color = pal$muted)),
              sizemode   = "area", sizeref = 0.05,
              line       = list(color = pal$border, width = 1)
            ),
            hovertemplate = paste0(
              "<b>%{text}</b><br>",
              "Worker training rate: %{x}%<br>",
              "Soft-skill gap: %{y}%<extra></extra>"
            )) %>%
      layout(
        shapes = list(list(
          type = "line", x0 = 0, x1 = 1, xref = "paper",
          y0 = 50, y1 = 50,
          line = list(color = pal$muted, dash = "dash", width = 1)
        )),
        xaxis = list(title = "Worker Training Rate from HH Survey (%)"),
        yaxis = list(title = "Employer Soft-Skill Gap (%)")) %>%
      dark_config()
  })

  output$gap_educ_wage <- renderPlotly({
    d <- hh_f() %>%
      filter(!is.na(educ_group)) %>%
      group_by(educ_group) %>%
      summarise(
        pct_employed = round(mean(emp_status %in% c("Wage Worker","Informal Wage")) * 100, 1),
        median_wage  = round(median(earnings_h_usd[earnings_h_usd > 0], na.rm = TRUE), 2),
        .groups = "drop"
      ) %>%
      arrange(educ_group)

    plot_ly(d) %>%
      add_bars(x = ~educ_group, y = ~pct_employed,
               name = "Employment rate (%)",
               marker = list(color = pal$blue), yaxis = "y1") %>%
      add_lines(x = ~educ_group, y = ~median_wage,
                name = "Median wage (USD)",
                line   = list(color = pal$orange, width = 3),
                marker = list(color = pal$orange, size = 8),
                yaxis  = "y2") %>%
      layout(
        yaxis  = list(title = "Employment Rate (%)", gridcolor = pal$border,
                      tickfont = list(color = pal$muted)),
        yaxis2 = list(title = "Median USD/hr", overlaying = "y", side = "right",
                      gridcolor = "rgba(0,0,0,0)", tickfont = list(color = pal$orange)),
        xaxis  = list(title = "", tickangle = -20),
        legend = list(orientation = "h", x = 0, y = 1.15),
        barmode = "group"
      ) %>%
      dark_config()
  })

  output$gap_formal_informal <- renderPlotly({
    d <- hh_f() %>%
      filter(emp_status %in% c("Wage Worker","Informal Wage"),
             !is.na(earnings_h_usd), earnings_h_usd > 0,
             sector_label != "Unknown") %>%
      group_by(sector_label, emp_status) %>%
      summarise(median_wage = round(median(earnings_h_usd), 2), .groups = "drop")

    plot_ly(d, x = ~sector_label, y = ~median_wage, color = ~emp_status,
            colors = c("Wage Worker" = pal$blue, "Informal Wage" = pal$orange),
            type = "bar",
            text = ~paste0("$", median_wage), textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>%{data.name}: %{text}<extra></extra>") %>%
      layout(barmode  = "group",
             xaxis    = list(title = ""),
             yaxis    = list(title = "Median USD/hr")) %>%
      dark_config()
  })

  output$gap_table <- renderDT({
    d <- hh_f() %>%
      filter(!is.na(educ_group)) %>%
      group_by(educ_group) %>%
      summarise(
        N              = n(),
        `Employment %` = round(mean(emp_status %in% c("Wage Worker","Informal Wage")) * 100, 1),
        `Formal Work %`= round(mean(emp_status == "Wage Worker") * 100, 1),
        `Median Wage (USD/hr)` = round(median(earnings_h_usd[earnings_h_usd > 0], na.rm = TRUE), 2),
        `Training %`   = round(mean(has_training, na.rm = TRUE) * 100, 1),
        `Literacy %`   = round(mean(literacy_pct, na.rm = TRUE), 1),
        .groups = "drop"
      ) %>%
      arrange(educ_group) %>%
      rename(`Education Level` = educ_group)

    datatable(d, options = list(
      pageLength = 10, dom = "t",
      columnDefs = list(list(className = "dt-center", targets = 1:6))
    ), rownames = FALSE) %>%
      formatStyle("Median Wage (USD/hr)",
                  background = styleColorBar(c(0, max(d$`Median Wage (USD/hr)`, na.rm = TRUE)),
                                             pal$blue),
                  backgroundSize = "100% 80%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") %>%
      formatStyle("Literacy %",
                  background = styleColorBar(c(0, 100), pal$teal),
                  backgroundSize = "100% 80%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center")
  })

  # ══════════════════════════════════════════════════════════════════
  # TAB 5 – EARNINGS ANALYSIS
  # ══════════════════════════════════════════════════════════════════
  output$earn_box <- renderPlotly({
    cap95 <- quantile(hh_f()$earnings_h_usd, 0.95, na.rm = TRUE)
    d <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0) %>%
      mutate(wage_capped = pmin(earnings_h_usd, cap95))

    plot_ly(d, x = ~gender_label, y = ~wage_capped, type = "violin",
            color = ~gender_label,
            colors = c("Male" = pal$blue, "Female" = pal$pink),
            box    = list(visible = TRUE),
            meanline = list(visible = TRUE),
            hoverinfo = "y+name") %>%
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Hourly Wage (USD, capped at 95th pctile)")) %>%
      dark_config()
  })

  output$earn_occ <- renderPlotly({
    d <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0, !is.na(occ_label)) %>%
      group_by(occ_label) %>%
      summarise(
        median = round(median(earnings_h_usd), 2),
        q25    = round(quantile(earnings_h_usd, 0.25), 2),
        q75    = round(quantile(earnings_h_usd, 0.75), 2),
        n      = n(),
        .groups = "drop"
      ) %>%
      arrange(median)

    plot_ly(d) %>%
      add_bars(x = ~median, y = ~reorder(occ_label, median),
               orientation = "h",
               marker = list(color = pal$purple),
               error_x = list(
                 type      = "data",
                 symmetric = FALSE,
                 plus      = ~q75 - median,
                 minus     = ~median - q25,
                 color     = pal$muted,
                 thickness = 1.5,
                 width     = 4
               ),
               text = ~paste0("$", median, " (n=", n, ")"),
               hovertemplate = "<b>%{y}</b><br>Median: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "Median USD/hr (bar = IQR)"),
             yaxis = list(title = "")) %>%
      dark_config()
  })

  output$earn_educ_gender <- renderPlotly({
    d <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0, !is.na(educ_group)) %>%
      group_by(educ_group, gender_label) %>%
      summarise(median_wage = round(median(earnings_h_usd), 2), .groups = "drop") %>%
      arrange(educ_group)

    plot_ly(d, x = ~educ_group, y = ~median_wage,
            color = ~gender_label,
            colors = c("Male" = pal$blue, "Female" = pal$pink),
            type = "scatter", mode = "lines+markers",
            line   = list(width = 3),
            marker = list(size = 9, line = list(color = pal$surface, width = 2)),
            text   = ~paste0("$", median_wage),
            hovertemplate = "<b>%{x}</b><br>%{data.name}: %{text}<extra></extra>") %>%
      layout(xaxis = list(title = "Education Level", tickangle = -20),
             yaxis = list(title = "Median USD/hr")) %>%
      dark_config()
  })

  output$earn_explorer <- renderPlotly({
    grp_var <- input$earn_group_var
    d <- hh_f() %>%
      filter(!is.na(earnings_h_usd), earnings_h_usd > 0,
             !is.na(.data[[grp_var]])) %>%
      group_by(grp = .data[[grp_var]]) %>%
      summarise(
        p25    = round(quantile(earnings_h_usd, 0.25), 2),
        median = round(median(earnings_h_usd), 2),
        p75    = round(quantile(earnings_h_usd, 0.75), 2),
        n      = n(),
        .groups = "drop"
      ) %>%
      arrange(desc(median)) %>%
      head(12)

    plot_ly(d, x = ~reorder(grp, median), type = "candlestick",
            open  = ~p25, close = ~p75,
            high  = ~p75, low   = ~p25,
            increasing = list(line = list(color = pal$green)),
            decreasing = list(line = list(color = pal$red)),
            hoverinfo = "none") %>%
      add_markers(x = ~reorder(grp, median), y = ~median,
                  marker = list(color = pal$yellow, size = 7, symbol = "diamond"),
                  hovertemplate = "<b>%{x}</b><br>Median: $%{y}<extra></extra>") %>%
      layout(xaxis = list(title = "", tickangle = -30),
             yaxis = list(title = "USD/hr (box=IQR, dot=median)"),
             showlegend = FALSE) %>%
      dark_config()
  })

} # end server

# ── 4. RUN ────────────────────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
