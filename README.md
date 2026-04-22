# Eurobarometer Analysis: Voting Intention in Europe

This project analyzes patterns in voting intention across European countries using Eurobarometer survey data. The goal is to understand how political interest, media use, income, and time relate to self-reported likelihood of voting.

An interactive Shiny dashboard accompanies the analysis, allowing exploration of distributions, confidence intervals, regression results, and cross-country comparisons.

---

## Live App

🔗 [eurobarometer-survey-explorer.onrender.com](https://eurobarometer-survey-explorer.onrender.com)

> Note: The app is hosted on Render's free tier and may take a moment to load after periods of inactivity.

---

## Approach

The analysis focuses on three countries: the United Kingdom, France, and the Netherlands. These were selected based on data quality — specifically, the availability of complete observations across key variables.

Due to substantial missingness in the dataset, all models are estimated on complete-case samples to ensure consistent comparison across predictors.

---

## Methods

- Data cleaning and transformation using `tidyverse`
- Conversion of ordinal survey responses into numeric scales
- Country-level filtering based on data completeness
- Linear regression models:

```r
particip_num ~ income_num + polint_num + mediause_num + year
```

- Cross-country coefficient comparison with confidence intervals

---

## Key Findings

- **Political interest** is the strongest and most consistent predictor of voting intention across all three countries
- **Media use** is positively associated with participation, though its magnitude varies by country
- **Income** shows a small and inconsistent relationship with voting intention, with limited explanatory power once political engagement is accounted for
- Time trends are modest and inconsistent across countries

---

## Limitations

- Analysis is based on complete-case samples, which may not fully represent the population
- Cross-sectional survey data limits causal interpretation
- Some variables (e.g., religion) were excluded due to inconsistent coverage and missingness

---

## Shiny App

The interactive dashboard includes four tabs:

| Tab | Description |
|---|---|
| Distribution Explorer | Visualize variable distributions with live confidence intervals and a sample size simulator |
| Country Comparison | Compare distributions and summary statistics across two countries side by side |
| Regression Explorer | Run and modify regression models interactively with live coefficient plots |
| Concept Reference | Plain-language definitions of key statistical concepts |

---

## Reproducibility

This project uses `renv` for dependency management. To reproduce:

```r
renv::restore()
```

```bash
quarto render analysis.qmd
```

---

## Deployment

The Shiny app is containerized with Docker and deployed on Render.

---

## Files

| File | Description |
|---|---|
| `analysis.qmd` | Main Quarto analysis |
| `analysis.html` | Rendered output |
| `app.R` | Shiny dashboard |
| `data_prep.R` | Data loading and cleaning |
| `Dockerfile` | Container config for Render deployment |
| `renv.lock` | Package environment |