library(shiny)
library(dplyr)
library(ggplot2)
library(haven)
library(stringr)

source("data_prep.R")
eb_data <- load_eb_data()

# -----------------------------
# Choices & labels
# -----------------------------

country_choices <- eb_data |>
  distinct(nation1) |>
  arrange(nation1) |>
  pull(nation1) |>
  as.character()

variable_choices <- c(
  "Voting Intention" = "particip_num",
  "Political Interest" = "polint_num",
  "Media Use" = "mediause_num",
  "Religious Importance" = "relimp_num",
  "Income" = "income_num"
)

variable_labels <- c(
  particip_num = "Voting Intention",
  polint_num = "Political Interest",
  mediause_num = "Media Use",
  relimp_num = "Religious Importance",
  income_num = "Income"
)

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f8f9fa;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }

      .card {
        background: white;
        padding: 20px;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        margin-bottom: 20px;
      }

      .title {
        font-size: 28px;
        font-weight: 600;
        margin-bottom: 20px;
      }

      .subtitle {
        color: #6c757d;
        margin-bottom: 10px;
      }
    "))
  ),
  fluidRow(
    column(
      width = 12,
      div(class = "title", "Survey Confidence Explorer")
    )
  ),
  fluidRow(
    column(
      width = 3,
      div(
        class = "card",
        div(class = "subtitle", "Controls"),
        selectInput(
          "country",
          "Country",
          choices = country_choices,
          selected = "United Kingdom"
        ),
        selectInput(
          "var",
          "Variable",
          choices = variable_choices,
          selected = "polint_num"
        )
      )
    ),
    column(
      width = 6,
      div(
        class = "card",
        plotOutput("ci_plot", height = "350px")
      )
    ),
    column(
      width = 3,
      div(
        class = "card",
        div(class = "subtitle", "Summary"),
        tableOutput("stats_table")
      )
    )
  )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output) {
  filtered_data <- reactive({
    req(input$country, input$var)

    eb_data |>
      filter(nation1 == input$country)
  })

  summary_stats <- reactive({
    df <- filtered_data()
    x <- df[[input$var]]
    x <- x[!is.na(x)]

    validate(
      need(length(x) > 1, "Not enough non-missing observations for this selection.")
    )

    mean_x <- mean(x)
    sd_x <- sd(x)
    se_x <- sd_x / sqrt(length(x))
    ci_low <- mean_x - 1.96 * se_x
    ci_high <- mean_x + 1.96 * se_x

    list(
      mean = mean_x,
      sd = sd_x,
      se = se_x,
      ci_low = ci_low,
      ci_high = ci_high,
      n = length(x)
    )
  })

  output$ci_plot <- renderPlot({
    s <- summary_stats()

    plot_df <- data.frame(
      label = "Estimate",
      mean = s$mean,
      ci_low = s$ci_low,
      ci_high = s$ci_high
    )

    ggplot(plot_df, aes(x = label, y = mean)) +
      geom_point(size = 4) +
      geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.1, linewidth = 0.7) +
      labs(
        title = paste(variable_labels[[input$var]], "in", input$country),
        subtitle = "Mean estimate with 95% confidence interval",
        x = NULL,
        y = variable_labels[[input$var]]
      ) +
      theme_minimal(base_size = 13)
  })

  output$stats_table <- renderTable(
    {
      s <- summary_stats()

      data.frame(
        Statistic = c("Mean", "Standard Deviation", "Standard Error", "95% CI Lower", "95% CI Upper", "N"),
        Value = c(
          round(s$mean, 3),
          round(s$sd, 3),
          round(s$se, 3),
          round(s$ci_low, 3),
          round(s$ci_high, 3),
          s$n
        )
      )
    },
    striped = TRUE,
    bordered = TRUE,
    spacing = "m"
  )
}

shinyApp(ui, server)
