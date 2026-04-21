library(tidyverse)
library(haven)
library(stringr)

clean_likert <- function(x) {
  x |>
    as_factor() |>
    str_to_title()
}

load_eb_data <- function(path = "eurobarometer_trends.dta") {
  eb_data <- read_dta(path) |>
    # ---- Numeric cleaning ----
    mutate(
      income = if_else(income >= 96, NA_real_, income),
      income_num = as.numeric(income)
    ) |>
    # ---- Label conversion ----
    mutate(across(where(haven::is.labelled), haven::as_factor)) |>
    # ---- Country cleaning ----
    mutate(
      nation1 = nation1 |>
        str_to_lower() |>
        str_to_title(),
      nation1 = case_when(
        nation1 == "Germany-West" ~ "Germany",
        nation1 == "Germany-East" ~ "Germany",
        nation1 == "Northern Ireland" ~ "United Kingdom",
        nation1 == "Great Britain" ~ "United Kingdom",
        TRUE ~ nation1
      )
    ) |>
    # ---- Likert cleaning ----
    mutate(across(c(mediause, particip, polint, ecint3, ecint4, relimp), clean_likert)) |>
    # ---- Feature engineering ----
    mutate(
      mediause_num = case_when(
        mediause == "Very Low" ~ 1,
        mediause == "Low" ~ 2,
        mediause == "High" ~ 3,
        mediause == "Very High" ~ 4,
        TRUE ~ NA_real_
      ),
      particip_num = case_when(
        particip == "Certainly Not" ~ 1,
        particip == "Probably Not" ~ 2,
        particip == "Probably Yes" ~ 3,
        particip == "Certainly Yes" ~ 4,
        TRUE ~ NA_real_
      ),
      polint_num = case_when(
        polint == "Not At All" ~ 1,
        polint == "Not Much" ~ 2,
        polint == "To Some Extent" ~ 3,
        polint == "A Great Deal" ~ 4,
        TRUE ~ NA_real_
      ),
      ecint3_num = case_when(
        ecint3 == "Not At All" ~ 1,
        ecint3 == "A Little" ~ 2,
        ecint3 == "Very Interested" ~ 3,
        TRUE ~ NA_real_
      ),
      ecint4_num = case_when(
        ecint4 == "Not At All" ~ 1,
        ecint4 == "Not Much" ~ 2,
        ecint4 == "To Some Extent" ~ 3,
        ecint4 == "A Great Deal" ~ 4,
        TRUE ~ NA_real_
      ),
      relimp_num = case_when(
        relimp == "Little Importance" ~ 1,
        relimp == "Some Importance" ~ 2,
        relimp == "Great Importance" ~ 3,
        TRUE ~ NA_real_
      )
    )

  return(eb_data)
}
