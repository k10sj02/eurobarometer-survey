library(shiny)
library(dplyr)
library(ggplot2)
library(haven)
library(stringr)

# -----------------------------
# Load cleaned data
# -----------------------------
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
# Helper function
# -----------------------------
get_stats <- function(x, n_override = NULL) {
  x <- x[!is.na(x)]

  n <- if (!is.null(n_override)) n_override else length(x)

  mean_x <- mean(x)
  sd_x <- sd(x)

  se_x <- sd_x / sqrt(n)
  ci_low <- mean_x - 1.96 * se_x
  ci_high <- mean_x + 1.96 * se_x

  list(
    mean = mean_x,
    sd = sd_x,
    se = se_x,
    ci_low = ci_low,
    ci_high = ci_high,
    n = n
  )
}

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f5f7fb;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto;
      }
      .card {
        background: white;
        padding: 22px;
        border-radius: 14px;
        box-shadow: 0 6px 18px rgba(0,0,0,0.08);
        margin-bottom: 20px;
      }
      .title {
        font-size: 28px;
        font-weight: 600;
        margin-bottom: 20px;
        color: #1f2937;
      }
      .subtitle {
        color: #6b7280;
        margin-bottom: 12px;
        font-weight: 500;
      }
    "))
  ),
  div(class = "title", "Survey Confidence Explorer"),
  fluidRow(
    column(
      width = 3,
      div(
        class = "card",
        div(class = "subtitle", "Controls"),
        selectInput("country1", "Country (Primary)", choices = country_choices),
        selectInput("country2", "Compare with", choices = c("None", country_choices)),
        selectInput("var", "Variable", choices = variable_choices),
        br(),
        div(class = "subtitle", "Sample Size Simulator"),
        sliderInput(
          "n_sim",
          "Simulated Sample Size",
          min = 50,
          max = 20000,
          value = 1000,
          step = 50
        )
      )
    ),
    column(
      width = 6,
      div(
        class = "card",
        plotOutput("ci_plot", height = "400px")
      ),
      div(
        class = "card",
        div(class = "subtitle", "Interpretation"),
        textOutput("interpretation")
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
  data1 <- reactive({
    eb_data |> filter(nation1 == input$country1)
  })

  data2 <- reactive({
    req(input$country2 != "None")
    eb_data |> filter(nation1 == input$country2)
  })

  output$ci_plot <- renderPlot({
    df1 <- data1()
    x1 <- df1[[input$var]]

    stats1 <- get_stats(x1, input$n_sim)

    p <- ggplot() +
      geom_histogram(
        data = df1,
        aes(x = x1, y = ..density..),
        bins = 30,
        fill = "#93c5fd",
        alpha = 0.5
      ) +
      geom_vline(xintercept = stats1$mean, color = "#2563eb", linewidth = 1.2) +
      geom_vline(xintercept = stats1$ci_low, linetype = "dashed", color = "#2563eb") +
      geom_vline(xintercept = stats1$ci_high, linetype = "dashed", color = "#2563eb")

    if (input$country2 != "None") {
      df2 <- data2()
      x2 <- df2[[input$var]]

      stats2 <- get_stats(x2, input$n_sim)

      p <- p +
        geom_histogram(
          data = df2,
          aes(x = x2, y = ..density..),
          bins = 30,
          fill = "#fca5a5",
          alpha = 0.4
        ) +
        geom_vline(xintercept = stats2$mean, color = "#dc2626", linewidth = 1.2) +
        geom_vline(xintercept = stats2$ci_low, linetype = "dashed", color = "#dc2626") +
        geom_vline(xintercept = stats2$ci_high, linetype = "dashed", color = "#dc2626")
    }

    p +
      labs(
        title = paste(variable_labels[[input$var]]),
        subtitle = paste("Simulated sample size:", input$n_sim),
        x = variable_labels[[input$var]],
        y = "Density"
      ) +
      theme_minimal(base_size = 14)
  })

  output$stats_table <- renderTable(
    {
      x <- data1()[[input$var]]
      stats <- get_stats(x, input$n_sim)

      data.frame(
        Statistic = c("Mean", "Std Dev", "Std Error", "95% CI Low", "95% CI High", "N (Simulated)"),
        Value = round(c(stats$mean, stats$sd, stats$se, stats$ci_low, stats$ci_high, stats$n), 3)
      )
    },
    striped = TRUE,
    bordered = TRUE,
    hover = TRUE
  )

  output$interpretation <- renderText({
    x1 <- data1()[[input$var]]
    stats1 <- get_stats(x1, input$n_sim)

    if (input$country2 == "None") {
      return(paste(
        "With a simulated sample size of", input$n_sim,
        ", the estimate becomes more precise as the confidence interval narrows."
      ))
    }

    x2 <- data2()[[input$var]]
    stats2 <- get_stats(x2, input$n_sim)

    overlap <- !(stats1$ci_high < stats2$ci_low ||
      stats2$ci_high < stats1$ci_low)

    if (overlap) {
      return("The confidence intervals overlap — the difference may not be meaningful.")
    } else {
      return("The confidence intervals do not overlap — suggesting a meaningful difference.")
    }
  })
}

shinyApp(ui, server)
