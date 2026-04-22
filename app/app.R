library(shiny)
library(dplyr)
library(ggplot2)
library(haven)
library(stringr)
library(broom)

eb_data <- readRDS("/srv/shiny-server/data/eb_clean.rds")

eb_data <- readRDS("/srv/shiny-server/data/eb_clean.rds") |>
  select(nation1, year, particip_num, polint_num,
         mediause_num, relimp_num, income_num)

# ── Choices ────────────────────────────────────────────────────────────────────
country_choices <- eb_data |>
  distinct(nation1) |>
  arrange(nation1) |>
  pull(nation1) |>
  as.character()

variable_choices <- c(
  "Voting Intention"     = "particip_num",
  "Political Interest"   = "polint_num",
  "Media Use"            = "mediause_num",
  "Religious Importance" = "relimp_num",
  "Income"               = "income_num"
)

variable_labels <- c(
  particip_num = "Voting Intention",
  polint_num   = "Political Interest",
  mediause_num = "Media Use",
  relimp_num   = "Religious Importance",
  income_num   = "Income"
)

variable_scales <- c(
  particip_num = "1 = Certainly Not, 4 = Certainly Yes",
  polint_num   = "1 = Not At All, 4 = A Great Deal",
  mediause_num = "1 = Very Low, 4 = Very High",
  relimp_num   = "1 = Little Importance, 3 = Great Importance",
  income_num   = "Ordinal income scale"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
get_stats <- function(x_full, n_sim) {
  x <- x_full[!is.na(x_full)]
  if (length(x) == 0) {
    return(NULL)
  }

  n_use <- min(n_sim, length(x))
  x_sample <- sample(x, size = n_use, replace = (n_sim > length(x)))

  mean_x <- mean(x_sample)
  sd_x <- sd(x_sample)
  se_x <- sd_x / sqrt(n_use)
  t_stat <- mean_x / se_x
  df <- n_use - 1
  p_val <- 2 * pt(-abs(t_stat), df = df)

  list(
    mean     = mean_x,
    sd       = sd_x,
    se       = se_x,
    ci_low   = mean_x - 1.96 * se_x,
    ci_high  = mean_x + 1.96 * se_x,
    t_stat   = t_stat,
    p_val    = p_val,
    df       = df,
    n        = n_use,
    x_sample = x_sample
  )
}

fmt <- function(x, digits = 3) formatC(round(x, digits), format = "f", digits = digits)

# ── Concept glossary ──────────────────────────────────────────────────────────
glossary <- list(
  mean = list(
    term = "Mean",
    def  = "The arithmetic average of all values. Sensitive to outliers — if a few extreme values exist, the mean gets pulled toward them. Compare with the median to detect skew."
  ),
  sd = list(
    term = "Standard Deviation (SD)",
    def  = "How spread out individual observations are around the mean. A high SD means values are widely dispersed; a low SD means they cluster tightly. SD describes your data — it does not shrink with larger samples."
  ),
  se = list(
    term = "Standard Error (SE)",
    def  = "How uncertain your estimate of the mean is. Calculated as SD / sqrt(n) — so it shrinks as your sample grows. SE describes your estimate, not your data. This is the key distinction from SD."
  ),
  ci = list(
    term = "95% Confidence Interval (CI)",
    def  = "A range built around your estimate. If you repeated your sampling 100 times, roughly 95 of those intervals would contain the true population mean. Narrower = more precise. Watch: as you increase the simulated sample size, the CI narrows."
  ),
  t_stat = list(
    term = "T-Statistic",
    def  = "Your estimate divided by its standard error — a signal-to-noise ratio. It asks: how many standard errors away from zero is your estimate? A value above ~2 generally corresponds to statistical significance (p < 0.05)."
  ),
  p_val = list(
    term = "P-Value",
    def  = "If the true mean were zero, how likely would you be to observe a result this extreme just by chance? A small p-value (< 0.05) means your result is unlikely to be noise. Common misconception: it is NOT the probability that the null hypothesis is true."
  ),
  df = list(
    term = "Degrees of Freedom (df)",
    def  = "The number of independent pieces of information available to estimate something. Roughly: n minus 1 for a mean. More df = larger effective sample = t-distribution approaches normal. At small sample sizes, df shrinks and you need a larger t-statistic to reach significance."
  )
)

# ── Colour palette ────────────────────────────────────────────────────────────
pal <- list(
  bg      = "#0f1117",
  panel   = "#1a1d27",
  card    = "#1e2130",
  border  = "#2d3148",
  accent1 = "#6c8ef5",
  accent2 = "#f56c8e",
  accent3 = "#56cfb2",
  text    = "#e8eaf0",
  muted   = "#8b90a8",
  warning = "#f5a623"
)

# ── CSS ───────────────────────────────────────────────────────────────────────
app_css <- sprintf(
  "
@import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap');

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background-color: %s;
  color: %s;
  font-family: 'DM Sans', sans-serif;
  font-size: 14px;
  min-height: 100vh;
}
.app-wrapper {
  max-width: 1400px;
  margin: 0 auto;
  padding: 28px 24px;
}
.app-header {
  margin-bottom: 28px;
  border-bottom: 1px solid %s;
  padding-bottom: 20px;
}
.app-title {
  font-family: 'Syne', sans-serif;
  font-size: 26px;
  font-weight: 800;
  color: %s;
  letter-spacing: -0.5px;
}
.app-subtitle {
  font-size: 13px;
  color: %s;
  margin-top: 4px;
  font-weight: 300;
}
.tag {
  display: inline-block;
  background: %s22;
  color: %s;
  border: 1px solid %s55;
  border-radius: 4px;
  padding: 2px 8px;
  font-size: 11px;
  font-family: 'DM Mono', monospace;
  margin-right: 6px;
  margin-top: 8px;
}
.card {
  background: %s;
  border: 1px solid %s;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 18px;
}
.card-title {
  font-family: 'Syne', sans-serif;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: %s;
  margin-bottom: 14px;
}
.nav-tabs {
  border-bottom: 1px solid %s !important;
  margin-bottom: 0 !important;
}
.nav-tabs > li > a {
  font-family: 'Syne', sans-serif !important;
  font-size: 12px !important;
  font-weight: 600 !important;
  text-transform: uppercase !important;
  letter-spacing: 1px !important;
  color: %s !important;
  background: transparent !important;
  border: none !important;
  border-bottom: 2px solid transparent !important;
  padding: 10px 16px !important;
  border-radius: 0 !important;
}
.nav-tabs > li.active > a,
.nav-tabs > li > a:hover {
  color: %s !important;
  border-bottom: 2px solid %s !important;
  background: transparent !important;
}
.tab-content { padding-top: 18px; }
.form-control, .selectize-input {
  background: %s !important;
  border: 1px solid %s !important;
  color: %s !important;
  border-radius: 8px !important;
  font-family: 'DM Sans', sans-serif !important;
  font-size: 13px !important;
}
.selectize-dropdown {
  background: %s !important;
  border: 1px solid %s !important;
  color: %s !important;
}
.selectize-dropdown .option:hover,
.selectize-dropdown .option.active { background: %s33 !important; }
label {
  font-size: 11px !important;
  font-weight: 500 !important;
  text-transform: uppercase !important;
  letter-spacing: 0.8px !important;
  color: %s !important;
  margin-bottom: 6px !important;
}
.irs--shiny .irs-bar { background: %s !important; border-color: %s !important; }
.irs--shiny .irs-handle { background: %s !important; border-color: %s !important; }
.irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single {
  background: %s !important;
  font-family: 'DM Mono', monospace !important;
  font-size: 11px !important;
}
.irs--shiny .irs-line { background: %s !important; }
.irs--shiny .irs-min, .irs--shiny .irs-max {
  color: %s !important;
  font-size: 10px !important;
  font-family: 'DM Mono', monospace !important;
  background: transparent !important;
}
.stat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.stat-box {
  background: %s;
  border: 1px solid %s;
  border-radius: 8px;
  padding: 12px 14px;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s;
}
.stat-box:hover { border-color: %s; background: %s22; }
.stat-box.active { border-color: %s; background: %s22; }
.stat-label {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  color: %s;
  text-transform: uppercase;
  letter-spacing: 0.8px;
}
.stat-value {
  font-family: 'Syne', sans-serif;
  font-size: 22px;
  font-weight: 700;
  color: %s;
  margin-top: 2px;
}
.stat-value.c1 { color: %s; }
.stat-value.c2 { color: %s; }
.stat-badge {
  display: inline-block;
  font-size: 10px;
  font-family: 'DM Mono', monospace;
  padding: 2px 6px;
  border-radius: 3px;
  margin-top: 4px;
}
.badge-sig   { background: %s22; color: %s; border: 1px solid %s55; }
.badge-insig { background: %s22; color: %s; border: 1px solid %s55; }
.glossary-box {
  background: %s;
  border-left: 3px solid %s;
  border-radius: 0 8px 8px 0;
  padding: 14px 16px;
  margin-top: 14px;
  display: none;
}
.glossary-box.show { display: block; }
.glossary-term {
  font-family: 'Syne', sans-serif;
  font-weight: 700;
  font-size: 13px;
  color: %s;
  margin-bottom: 6px;
}
.glossary-def { font-size: 13px; color: %s; line-height: 1.6; }
.insight-box {
  background: %s;
  border: 1px solid %s;
  border-radius: 8px;
  padding: 14px 16px;
  font-size: 13px;
  line-height: 1.7;
  color: %s;
}
.insight-box strong { color: %s; }
.insight-highlight {
  display: inline-block;
  font-family: 'DM Mono', monospace;
  font-size: 12px;
  background: %s22;
  color: %s;
  padding: 1px 6px;
  border-radius: 3px;
}
.scale-note {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  color: %s;
  margin-bottom: 14px;
  padding: 6px 10px;
  background: %s;
  border-radius: 6px;
  border: 1px solid %s;
}
.reg-table { width: 100%%; border-collapse: collapse; font-size: 13px; }
.reg-table th {
  font-family: 'Syne', sans-serif;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: %s;
  border-bottom: 1px solid %s;
  padding: 8px 12px;
  text-align: left;
}
.reg-table td {
  padding: 8px 12px;
  border-bottom: 1px solid %s;
  color: %s;
  font-family: 'DM Mono', monospace;
}
.reg-table tr:last-child td { border-bottom: none; }
.reg-table .sig   { color: %s; font-weight: 500; }
.reg-table .insig { color: %s; }
.chain-step {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  margin-bottom: 14px;
}
.chain-num {
  font-family: 'Syne', sans-serif;
  font-weight: 800;
  font-size: 20px;
  color: %s;
  min-width: 28px;
  line-height: 1;
  padding-top: 2px;
}
.chain-title {
  font-family: 'Syne', sans-serif;
  font-weight: 700;
  font-size: 13px;
  color: %s;
  margin-bottom: 3px;
}
.chain-desc { font-size: 13px; color: %s; line-height: 1.6; }
.chain-arrow { text-align: center; color: %s; font-size: 18px; margin: -6px 0 8px 0; }
.overlap-badge {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 4px;
  font-family: 'DM Mono', monospace;
  font-size: 12px;
  margin-bottom: 10px;
}
.overlap-yes { background: %s22; color: %s; border: 1px solid %s55; }
.overlap-no  { background: %s22; color: %s; border: 1px solid %s55; }
.app-footer {
  text-align: center;
  padding: 24px 0 8px;
  font-size: 11px;
  color: %s;
  font-family: 'DM Mono', monospace;
  border-top: 1px solid %s;
  margin-top: 8px;
}
",
  pal$bg, pal$text,
  pal$border,
  pal$text,
  pal$muted,
  pal$accent1, pal$accent1, pal$accent1,
  pal$card, pal$border,
  pal$muted,
  pal$border,
  pal$muted, pal$text, pal$accent1,
  pal$panel, pal$border, pal$text,
  pal$panel, pal$border, pal$text,
  pal$accent1,
  pal$muted,
  pal$accent1, pal$accent1,
  pal$accent1, pal$accent1,
  pal$accent1,
  pal$border,
  pal$muted,
  pal$panel, pal$border,
  pal$accent1, pal$accent1,
  pal$accent1, pal$accent1,
  pal$muted, pal$text,
  pal$accent1, pal$accent2,
  pal$accent3, pal$accent3, pal$accent3,
  pal$warning, pal$warning, pal$warning,
  pal$panel, pal$accent1,
  pal$accent1, pal$text,
  pal$panel, pal$border, pal$text, pal$text,
  pal$accent1, pal$accent1,
  pal$muted, pal$panel, pal$border,
  pal$muted, pal$border,
  pal$border, pal$text,
  pal$accent3, pal$muted,
  pal$accent1,
  pal$text, pal$muted,
  pal$border,
  pal$accent3, pal$accent3, pal$accent3,
  pal$accent2, pal$accent2, pal$accent2,
  pal$muted, pal$border
)

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  tags$head(
    tags$style(HTML(app_css)),
    tags$script(HTML("
      $(document).on('click', '.stat-box', function() {
        var key = $(this).data('key');
        $('.stat-box').removeClass('active');
        $(this).addClass('active');
        Shiny.setInputValue('active_stat', key, {priority: 'event'});
      });
    "))
  ),
  div(
    class = "app-wrapper",

    # ── Header ────────────────────────────────────────────────────────────────
    div(
      class = "app-header",
      div(class = "app-title", "Survey Statistics Explorer"),
      div(
        class = "app-subtitle",
        "Eurobarometer Trends Dataset · Interactive learning tool for survey statistics"
      ),
      div(
        span(class = "tag", "Confidence Intervals"),
        span(class = "tag", "Standard Error"),
        span(class = "tag", "T-Statistics"),
        span(class = "tag", "P-Values"),
        span(class = "tag", "Degrees of Freedom")
      )
    ),

    # ── Body ──────────────────────────────────────────────────────────────────
    fluidRow(
      # Left sidebar
      column(
        width = 3,
        div(
          class = "card",
          div(class = "card-title", "Configuration"),
          selectInput("country1", "Primary Country",
            choices = country_choices, selected = "United Kingdom"
          ),
          selectInput("country2", "Compare With",
            choices = c("None" = "None", country_choices), selected = "France"
          ),
          selectInput("var", "Variable", choices = variable_choices),
          hr(style = sprintf("border-color: %s; margin: 14px 0;", pal$border)),
          div(class = "card-title", "Sample Size Simulator"),
          sliderInput("n_sim", NULL,
            min = 50, max = 5000, value = 500, step = 50
          ),
          div(
            style = sprintf(
              "font-size:11px; color:%s; font-family:'DM Mono',monospace; margin-top:-8px;",
              pal$muted
            ),
            "Drag to see how n affects SE and CI width"
          )
        ),
        div(
          class = "card",
          div(class = "card-title", "The Statistical Chain"),
          div(
            class = "chain-step",
            div(class = "chain-num", "1"),
            div(
              div(class = "chain-title", "Estimate"),
              div(class = "chain-desc", "Calculate the mean from your sample data")
            )
          ),
          div(class = "chain-arrow", "↓"),
          div(
            class = "chain-step",
            div(class = "chain-num", "2"),
            div(
              div(class = "chain-title", "Standard Error"),
              div(class = "chain-desc", "Measure uncertainty: SD / sqrt(n)")
            )
          ),
          div(class = "chain-arrow", "↓"),
          div(
            class = "chain-step",
            div(class = "chain-num", "3"),
            div(
              div(class = "chain-title", "T-Statistic"),
              div(class = "chain-desc", "Signal-to-noise: estimate / SE")
            )
          ),
          div(class = "chain-arrow", "↓"),
          div(
            class = "chain-step",
            div(class = "chain-num", "4"),
            div(
              div(class = "chain-title", "P-Value"),
              div(class = "chain-desc", "How surprising is this result under the null?")
            )
          ),
          div(class = "chain-arrow", "↓"),
          div(
            class = "chain-step",
            div(class = "chain-num", "5"),
            div(
              div(class = "chain-title", "Confidence Interval"),
              div(class = "chain-desc", "Estimate +/- 1.96 x SE")
            )
          )
        )
      ),

      # Main panel
      column(
        width = 9,
        tabsetPanel(
          id = "tabs", type = "tabs",

          # Tab 1: Distribution Explorer
          tabPanel(
            "Distribution Explorer",
            fluidRow(
              column(
                width = 8,
                div(
                  class = "card",
                  div(class = "card-title", "Distribution & Confidence Intervals"),
                  uiOutput("scale_note"),
                  plotOutput("ci_plot", height = "340px")
                )
              ),
              column(
                width = 4,
                div(
                  class = "card",
                  div(class = "card-title", "Click a Statistic to Learn More"),
                  uiOutput("stat_boxes"),
                  uiOutput("glossary_panel")
                )
              )
            ),
            fluidRow(
              column(
                width = 12,
                div(
                  class = "card",
                  div(class = "card-title", "Interpretation"),
                  uiOutput("interpretation_box")
                )
              )
            )
          ),

          # Tab 2: Country Comparison
          tabPanel(
            "Country Comparison",
            fluidRow(
              column(
                width = 7,
                div(
                  class = "card",
                  div(class = "card-title", "Side-by-Side Distributions"),
                  plotOutput("compare_plot", height = "320px")
                )
              ),
              column(
                width = 5,
                div(
                  class = "card",
                  div(class = "card-title", "Statistical Comparison"),
                  uiOutput("comparison_stats")
                )
              )
            ),
            fluidRow(
              column(
                width = 12,
                div(
                  class = "card",
                  div(class = "card-title", "What Does Overlap Mean?"),
                  div(
                    class = "insight-box",
                    "When two confidence intervals ",
                    tags$strong("do not overlap"),
                    " it suggests a meaningful difference between groups. When they ",
                    tags$strong("do overlap"),
                    " it does not prove the means are equal — it means we cannot confidently distinguish them at this sample size. Try reducing the simulated sample size to see how smaller samples create wider, more overlapping intervals, illustrating why ",
                    tags$strong("statistical power"),
                    " matters."
                  )
                )
              )
            )
          ),

          # Tab 3: Regression Explorer
          tabPanel(
            "Regression Explorer",
            fluidRow(
              column(
                width = 5,
                div(
                  class = "card",
                  div(class = "card-title", "Model Configuration"),
                  selectInput("reg_country", "Country",
                    choices = country_choices, selected = "United Kingdom"
                  ),
                  checkboxGroupInput("reg_predictors", "Predictors",
                    choices = c(
                      "Political Interest"   = "polint_num",
                      "Media Use"            = "mediause_num",
                      "Income"               = "income_num",
                      "Religious Importance" = "relimp_num",
                      "Year"                 = "year"
                    ),
                    selected = c("polint_num", "mediause_num", "income_num", "year"),
                    inline = FALSE
                  ),
                  div(
                    style = sprintf("font-size:12px; color:%s; margin-top:8px;", pal$muted),
                    "Outcome: Voting Intention (particip_num)"
                  )
                ),
                div(
                  class = "card",
                  div(class = "card-title", "Model Fit"),
                  uiOutput("model_fit_boxes")
                )
              ),
              column(
                width = 7,
                div(
                  class = "card",
                  div(class = "card-title", "Coefficient Table"),
                  div(
                    style = sprintf("font-size:11px; color:%s; margin-bottom:12px;", pal$muted),
                    "* = p < 0.05  **  = p < 0.01  *** = p < 0.001"
                  ),
                  tableOutput("reg_table")
                ),
                div(
                  class = "card",
                  div(class = "card-title", "Coefficient Plot"),
                  plotOutput("coef_plot", height = "240px")
                )
              )
            )
          ),

          # Tab 4: Concept Reference
          tabPanel(
            "Concept Reference",
            fluidRow(
              column(
                width = 12,
                lapply(names(glossary), function(key) {
                  g <- glossary[[key]]
                  div(
                    class = "card",
                    div(class = "card-title", g$term),
                    div(
                      style = sprintf(
                        "font-size:13px; color:%s; line-height:1.7;", pal$text
                      ),
                      g$def
                    )
                  )
                })
              )
            )
          )
        )
      )
    ),

    # ── Footer ────────────────────────────────────────────────────────────────
    div(
      class = "app-footer",
      "Built by Stann-Omar Jones · Eurobarometer Survey Statistics Explorer"
    )
  ) # closes div(class = "app-wrapper")
) # closes fluidPage


# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {
  data1 <- reactive({
    eb_data |> filter(nation1 == input$country1)
  })

  data2 <- reactive({
    if (input$country2 == "None") {
      return(NULL)
    }
    eb_data |> filter(nation1 == input$country2)
  })

  stats1 <- reactive({
    x <- data1()[[input$var]]
    get_stats(x, input$n_sim)
  })

  stats2 <- reactive({
    d2 <- data2()
    if (is.null(d2)) {
      return(NULL)
    }
    x <- d2[[input$var]]
    get_stats(x, input$n_sim)
  })

  output$scale_note <- renderUI({
    div(
      class = "scale-note",
      sprintf("Scale: %s", variable_scales[[input$var]])
    )
  })

  # ── Plot theme ─────────────────────────────────────────────────────────────
  dark_theme <- function() {
    theme_minimal(base_size = 13) +
      theme(
        plot.background = element_rect(fill = pal$card, color = NA),
        panel.background = element_rect(fill = pal$card, color = NA),
        panel.grid.major = element_line(color = pal$border, linewidth = 0.4),
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        axis.text = element_text(color = pal$muted, family = "mono", size = 10),
        axis.title = element_text(color = pal$muted, size = 11),
        plot.title = element_text(
          color = pal$text, family = "sans",
          face = "bold", size = 13
        ),
        plot.subtitle = element_text(color = pal$muted, size = 11),
        legend.background = element_rect(fill = pal$card, color = NA),
        legend.text = element_text(color = pal$muted),
        legend.title = element_text(color = pal$muted),
        strip.text = element_text(color = pal$muted)
      )
  }

  # ── CI Plot ────────────────────────────────────────────────────────────────
  output$ci_plot <- renderPlot(
    {
      s1 <- stats1()
      if (is.null(s1)) {
        return(NULL)
      }

      x1_df <- data.frame(x = s1$x_sample)

      ggplot(x1_df, aes(x = x)) +
        geom_histogram(aes(y = after_stat(density)),
          bins = 20, fill = pal$accent1, alpha = 0.35, color = NA
        ) +
        geom_density(color = pal$accent1, linewidth = 1, alpha = 0) +
        annotate("rect",
          xmin = s1$mean - s1$se, xmax = s1$mean + s1$se,
          ymin = -Inf, ymax = Inf, fill = pal$accent1, alpha = 0.08
        ) +
        geom_vline(
          xintercept = s1$ci_low, linetype = "dashed",
          color = pal$accent1, linewidth = 0.8
        ) +
        geom_vline(
          xintercept = s1$ci_high, linetype = "dashed",
          color = pal$accent1, linewidth = 0.8
        ) +
        geom_vline(xintercept = s1$mean, color = pal$accent1, linewidth = 1.4) +
        annotate("text",
          x = s1$mean, y = Inf,
          label = sprintf("mean\n%.2f", s1$mean),
          vjust = 1.5, hjust = -0.1,
          color = pal$accent1, size = 3.2, family = "mono"
        ) +
        labs(
          title = sprintf("%s - %s", variable_labels[[input$var]], input$country1),
          subtitle = sprintf(
            "n = %s  |  SD = %.3f  |  SE = %.3f  |  95%% CI [%.3f, %.3f]",
            format(s1$n, big.mark = ","), s1$sd, s1$se, s1$ci_low, s1$ci_high
          ),
          x = variable_labels[[input$var]], y = "Density"
        ) +
        dark_theme()
    },
    bg = pal$card
  )

  # ── Stat boxes ─────────────────────────────────────────────────────────────
  output$stat_boxes <- renderUI({
    s1 <- stats1()
    if (is.null(s1)) {
      return(NULL)
    }

    sig_p <- s1$p_val < 0.05
    active <- if (is.null(input$active_stat)) "mean" else input$active_stat

    make_box <- function(key, label, val, extra = NULL) {
      is_active <- identical(key, active)
      div(
        class = paste("stat-box", if (is_active) "active"),
        `data-key` = key,
        div(class = "stat-label", label),
        div(class = "stat-value c1", val),
        if (!is.null(extra)) extra
      )
    }

    p_badge <- if (sig_p) {
      div(class = "stat-badge badge-sig", "p < 0.05 ✓")
    } else {
      div(class = "stat-badge badge-insig", "p >= 0.05")
    }

    div(
      class = "stat-grid",
      make_box("mean", "Mean", fmt(s1$mean)),
      make_box("sd", "SD", fmt(s1$sd)),
      make_box("se", "SE", fmt(s1$se)),
      make_box("ci", "95% CI", sprintf(
        "[%s, %s]",
        fmt(s1$ci_low, 2), fmt(s1$ci_high, 2)
      )),
      make_box("t_stat", "T-Stat", fmt(s1$t_stat, 2)),
      make_box("p_val", "P-Value", fmt(s1$p_val, 4), p_badge)
    )
  })

  # ── Glossary panel ─────────────────────────────────────────────────────────
  output$glossary_panel <- renderUI({
    key <- if (is.null(input$active_stat)) "mean" else input$active_stat
    g <- glossary[[key]]
    if (is.null(g)) {
      return(NULL)
    }

    div(
      class = "glossary-box show",
      div(class = "glossary-term", g$term),
      div(class = "glossary-def", g$def)
    )
  })

  # ── Interpretation ─────────────────────────────────────────────────────────
  output$interpretation_box <- renderUI({
    s1 <- stats1()
    if (is.null(s1)) {
      return(NULL)
    }

    sig <- s1$p_val < 0.05
    ci_width <- s1$ci_high - s1$ci_low
    skew_flag <- abs(s1$mean - median(s1$x_sample, na.rm = TRUE)) > 0.1 * s1$sd

    div(
      class = "insight-box",
      tags$p(
        tags$strong(sprintf("%s in %s", variable_labels[[input$var]], input$country1)),
        " has a mean of ",
        span(class = "insight-highlight", fmt(s1$mean)),
        sprintf(" (SD = %s, n = %s).", fmt(s1$sd), format(s1$n, big.mark = ",")),
        " The standard error is ",
        span(class = "insight-highlight", fmt(s1$se)),
        " — meaning your estimate of the mean is precise to within roughly +/-",
        span(class = "insight-highlight", fmt(s1$se * 2)),
        " at 95% confidence."
      ),
      tags$p(
        style = "margin-top: 10px;",
        "The 95% CI is [",
        span(class = "insight-highlight", fmt(s1$ci_low, 2)),
        ", ",
        span(class = "insight-highlight", fmt(s1$ci_high, 2)),
        sprintf("] — a width of %s. ", fmt(ci_width, 3)),
        if (sig) {
          tags$span(
            "The t-statistic is ",
            span(class = "insight-highlight", fmt(s1$t_stat, 2)),
            sprintf(" (p = %s), which is statistically significant.", fmt(s1$p_val, 4)),
            " This means the mean is unlikely to be zero by chance alone."
          )
        } else {
          tags$span("The result is not statistically significant at the 0.05 level.")
        }
      ),
      if (skew_flag) {
        tags$p(
          style = "margin-top: 10px;",
          tags$strong("Note: "),
          "The mean and median diverge noticeably, suggesting the distribution may be skewed. Consider whether the mean is the best summary statistic here."
        )
      },
      tags$p(
        style = "margin-top: 10px;",
        tags$strong("Try this: "),
        "Drag the sample size slider down to ~100 and watch the SE grow and the CI widen. Then push it to 2000 and see precision improve."
      )
    )
  })

  # ── Compare plot ───────────────────────────────────────────────────────────
  output$compare_plot <- renderPlot(
    {
      s1 <- stats1()
      s2 <- stats2()

      x1_df <- data.frame(x = s1$x_sample, country = input$country1)

      if (!is.null(s2)) {
        x2_df <- data.frame(x = s2$x_sample, country = input$country2)
        plot_df <- bind_rows(x1_df, x2_df)
        colours <- c(pal$accent1, pal$accent2)
        names(colours) <- c(input$country1, input$country2)

        means_df <- data.frame(
          country = c(input$country1, input$country2),
          mean    = c(s1$mean, s2$mean),
          ci_low  = c(s1$ci_low, s2$ci_low),
          ci_high = c(s1$ci_high, s2$ci_high)
        )

        ggplot(plot_df, aes(x = x, fill = country, color = country)) +
          geom_density(alpha = 0.25, linewidth = 1) +
          geom_vline(
            data = means_df, aes(xintercept = mean, color = country),
            linewidth = 1.3
          ) +
          geom_vline(
            data = means_df, aes(xintercept = ci_low, color = country),
            linetype = "dashed", linewidth = 0.7
          ) +
          geom_vline(
            data = means_df, aes(xintercept = ci_high, color = country),
            linetype = "dashed", linewidth = 0.7
          ) +
          scale_fill_manual(values = colours) +
          scale_color_manual(values = colours) +
          labs(
            x = variable_labels[[input$var]], y = "Density",
            title = "Distribution Comparison", fill = NULL, color = NULL
          ) +
          dark_theme() +
          theme(legend.position = "top")
      } else {
        ggplot(x1_df, aes(x = x)) +
          geom_density(
            fill = pal$accent1, alpha = 0.3,
            color = pal$accent1, linewidth = 1
          ) +
          labs(
            x = variable_labels[[input$var]], y = "Density",
            title = sprintf("%s - %s", variable_labels[[input$var]], input$country1)
          ) +
          dark_theme()
      }
    },
    bg = pal$card
  )

  # ── Comparison stats ───────────────────────────────────────────────────────
  output$comparison_stats <- renderUI({
    s1 <- stats1()
    s2 <- stats2()

    if (is.null(s2)) {
      return(div(
        class = "insight-box",
        "Select a comparison country to see side-by-side statistics."
      ))
    }

    overlap <- !(s1$ci_high < s2$ci_low || s2$ci_high < s1$ci_low)

    make_row <- function(label, v1, v2 = NULL) {
      tags$tr(
        tags$td(style = sprintf(
          "color:%s; font-size:11px; text-transform:uppercase; letter-spacing:.6px; padding:7px 10px;",
          pal$muted
        ), label),
        tags$td(style = sprintf(
          "color:%s; font-family:monospace; padding:7px 10px;", pal$accent1
        ), v1),
        if (!is.null(v2)) {
          tags$td(style = sprintf(
            "color:%s; font-family:monospace; padding:7px 10px;", pal$accent2
          ), v2)
        }
      )
    }

    div(
      div(
        class = paste("overlap-badge", if (overlap) "overlap-yes" else "overlap-no"),
        if (overlap) {
          "CIs overlap - difference uncertain"
        } else {
          "CIs do not overlap - likely meaningful difference"
        }
      ),
      tags$table(
        style = sprintf(
          "width:100%%; border-collapse:collapse; border-top:1px solid %s;", pal$border
        ),
        tags$thead(tags$tr(
          tags$th(
            style = sprintf("padding:7px 10px; color:%s; font-size:11px;", pal$muted),
            "Statistic"
          ),
          tags$th(
            style = sprintf("padding:7px 10px; color:%s; font-size:11px;", pal$accent1),
            input$country1
          ),
          tags$th(
            style = sprintf("padding:7px 10px; color:%s; font-size:11px;", pal$accent2),
            input$country2
          )
        )),
        tags$tbody(
          make_row("N (sim)", format(s1$n, big.mark = ","), format(s2$n, big.mark = ",")),
          make_row("Mean", fmt(s1$mean), fmt(s2$mean)),
          make_row("SD", fmt(s1$sd), fmt(s2$sd)),
          make_row("SE", fmt(s1$se), fmt(s2$se)),
          make_row("CI Low", fmt(s1$ci_low), fmt(s2$ci_low)),
          make_row("CI High", fmt(s1$ci_high), fmt(s2$ci_high)),
          make_row("T-Stat", fmt(s1$t_stat, 2), fmt(s2$t_stat, 2)),
          make_row("P-Value", fmt(s1$p_val, 4), fmt(s2$p_val, 4)),
          make_row("Diff (means)", fmt(s1$mean - s2$mean))
        )
      )
    )
  })

  # ── Regression ─────────────────────────────────────────────────────────────
  reg_model <- reactive({
    req(length(input$reg_predictors) > 0)

    df <- eb_data |>
      filter(nation1 == input$reg_country) |>
      select(particip_num, all_of(input$reg_predictors)) |>
      filter(if_all(everything(), ~ !is.na(.)))

    req(nrow(df) > 10)

    formula_str <- paste(
      "particip_num ~",
      paste(input$reg_predictors, collapse = " + ")
    )
    lm(as.formula(formula_str), data = df)
  })

  output$reg_table <- renderTable(
    {
      m <- reg_model()
      tdf <- broom::tidy(m)

      tdf |>
        filter(term != "(Intercept)") |>
        mutate(
          Term = recode(term,
            polint_num   = "Political Interest",
            mediause_num = "Media Use",
            income_num   = "Income",
            relimp_num   = "Religious Importance",
            year         = "Year"
          ),
          Estimate = round(estimate, 4),
          SE = round(std.error, 4),
          `T-Stat` = round(statistic, 3),
          `P-Value` = round(p.value, 4),
          Sig = case_when(
            p.value < 0.001 ~ "***",
            p.value < 0.01 ~ "**",
            p.value < 0.05 ~ "*",
            TRUE ~ ""
          )
        ) |>
        select(Term, Estimate, SE, `T-Stat`, `P-Value`, Sig)
    },
    striped = FALSE,
    bordered = FALSE,
    hover = FALSE,
    spacing = "s",
    align = "lrrrrr",
    na = "-"
  )

  output$coef_plot <- renderPlot(
    {
      m <- reg_model()
      tdf <- broom::tidy(m) |>
        filter(term != "(Intercept)") |>
        mutate(
          term = recode(term,
            polint_num   = "Political Interest",
            mediause_num = "Media Use",
            income_num   = "Income",
            relimp_num   = "Religious Importance",
            year         = "Year"
          ),
          sig = p.value < 0.05
        )

      ggplot(tdf, aes(x = reorder(term, estimate), y = estimate, color = sig)) +
        geom_hline(yintercept = 0, color = pal$border, linewidth = 0.8) +
        geom_errorbar(
          aes(
            ymin = estimate - 1.96 * std.error,
            ymax = estimate + 1.96 * std.error
          ),
          width = 0.15, linewidth = 0.8
        ) +
        geom_point(size = 3) +
        coord_flip() +
        scale_color_manual(
          values = c("TRUE" = pal$accent3, "FALSE" = pal$muted),
          labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05"),
          name   = NULL
        ) +
        labs(
          x = NULL, y = "Coefficient Estimate",
          title = sprintf("Coefficients - %s", input$reg_country)
        ) +
        dark_theme() +
        theme(
          legend.position = "top",
          legend.text = element_text(color = pal$muted, size = 10)
        )
    },
    bg = pal$card
  )

  output$model_fit_boxes <- renderUI({
    m <- reg_model()
    s <- summary(m)
    r2 <- round(s$r.squared, 4)
    ar2 <- round(s$adj.r.squared, 4)
    n <- nrow(m$model)
    df_r <- m$df.residual

    make_fit_box <- function(label, val) {
      div(
        class = "stat-box", style = "margin-bottom:8px;",
        div(class = "stat-label", label),
        div(
          class = "stat-value",
          style = sprintf("font-size:18px; color:%s;", pal$accent3), val
        )
      )
    }

    div(
      make_fit_box("R-squared", fmt(r2, 4)),
      make_fit_box("Adjusted R-sq", fmt(ar2, 4)),
      make_fit_box("Observations", format(n, big.mark = ",")),
      make_fit_box("Residual df", format(df_r, big.mark = ",")),
      div(
        style = sprintf(
          "font-size:11px; color:%s; margin-top:8px; line-height:1.6;", pal$muted
        ),
        sprintf(
          "R-squared of %.1f%% means your predictors explain %.1f%% of the variance in voting intention. Low R-squared is typical for survey behavioral data.",
          r2 * 100, r2 * 100
        )
      )
    )
  })
}

shinyApp(ui, server)
