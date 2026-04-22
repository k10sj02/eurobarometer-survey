# Dev Notes — Eurobarometer Survey Explorer

A record of the full development and debugging process for this project — from raw data to deployed Shiny app on both Render and shinyapps.io.

---

## Mental Model

Every issue encountered during this project fell into one of four layers. Debugging became much faster once I learned to identify which layer was broken before trying to fix anything.

| Layer | What it covers |
|---|---|
| 1. Data | Cleaning, file paths, preprocessing |
| 2. R / Code | Objects, functions, execution order |
| 3. Shiny | App structure, routing, reactivity |
| 4. Docker / Deployment | Environment, filesystem, container config |

**The rule: identify the layer first, then fix.**

---

## 1. Data Layer

### Problem
Data cleaning was slow and the Shiny app depended on runtime preprocessing — every time the app loaded, it was re-running the full cleaning pipeline.

### Fix
Extracted all data cleaning into a separate `data_prep.R` file with a reusable `load_eb_data()` function. Precomputed the cleaned dataset and saved it:

```r
saveRDS(clean_data, "data/eb_clean.rds")
```

Then loaded it instantly in `app.R`:

```r
eb_data <- readRDS("eb_clean.rds")
```

### Lesson
Don't clean data inside your app. Precompute, store, load fast.

---

## 2. Performance Debugging

### Problem
The data cleaning step was extremely slow. The culprit was this pattern:

```r
across(where(haven::is.labelled), ...)
```

Applying a function to every column that matched a condition on a large dataset is expensive.

### Fix
Replace with an explicit column list:

```r
across(c(mediause, particip, polint, ecint3, ecint4, relimp), ...)
```

### Lesson
Avoid "apply to everything" operations on large data. Be explicit about which columns you're transforming.

---

## 3. Country Names Showing as Numbers

### Problem
The Primary Country dropdown was displaying numeric codes (1, 2, 3...) instead of country names.

### Root Cause
`haven::read_dta()` reads Stata variables as labelled integers. Calling `as.character()` directly on a labelled vector returns the numeric code as a string, not the label text.

### Fix
Use `haven::as_factor()` first to extract the label, then convert to character:

```r
nation1 = nation1 |>
  haven::as_factor() |>   # extract the label first
  as.character() |>        # then convert to plain string
  str_to_lower() |>
  str_to_title()
```

### Lesson
When working with Haven labelled variables, always use `as_factor()` before `as.character()`. Using `as.character()` alone strips the label and returns the underlying numeric code.

---

## 4. Shiny App Debugging

### Problem 1 — App not loading ("Not Found")

**Cause:** Wrong folder structure. Shiny Server expects `app.R` to live in a named subfolder.

**Fix:** Restructure so the app lives at:
```
app/
  app.R
```

**Lesson:** "Not Found" is a routing issue, not a crash. Check folder structure first.

---

### Problem 2 — App crashes silently

**Symptom:** `The application exited during initialization` — no useful error message in the browser.

**Fix:** Run the app directly in R with trace mode enabled to get the real error:

```r
options(shiny.trace = TRUE)
shiny::runApp("path/to/app")
```

**Lesson:** The browser error message is almost never the real error. Run the app from the R console to see the actual stack trace.

---

### Problem 3 — Missing objects / undefined variable errors

**Cause:** Variables used in the UI were defined after the UI block, so they didn't exist yet when the UI tried to reference them.

**Fix:** Always define data objects and choice vectors before the UI:

```r
# Define BEFORE ui <- fluidPage(...)
eb_data <- load_eb_data()
country_choices <- eb_data |> distinct(nation1) |> pull(nation1)
variable_choices <- c("Voting Intention" = "particip_num", ...)

ui <- fluidPage(...)
server <- function(input, output, session) {...}
```

**Lesson:** R executes top to bottom. Anything referenced in the UI must exist before the UI is defined.

---

### Problem 4 — R version syntax errors on shinyapps.io

**Symptom:** App worked locally but failed on shinyapps.io with "Possible missing comma" errors.

**Cause:** shinyapps.io uses R 4.5.3 which is stricter about inline `if` statements inside function call arguments than older versions.

**Examples of problematic patterns:**
```r
# These cause parse errors in R 4.5.3
div(class = paste("stat-box", if (is_active) "active"),
if (skew_flag) { tags$p(...) },
```

**Fix:** Pre-compute conditional values before passing them into function calls, or wrap in `{}`:

```r
# Pre-compute
box_class <- if (is_active) "stat-box active" else "stat-box"
div(class = box_class, ...)

# Or wrap in braces
{ if (skew_flag) tags$p(...) }
```

**Lesson:** Always test against the R version your deployment platform uses. Syntax that works locally may fail on newer or stricter versions of R.

---

## 5. File Path Debugging

### Problem 1 — Relative paths breaking between environments

```r
readRDS("data/eb_clean.rds")    # worked locally, broke in Docker
readRDS("../data/eb_clean.rds") # worked in Docker, broke on shinyapps.io
```

### Why
Each platform runs the app from a different working directory:
- Local: project root
- Docker/Render: `/srv/shiny-server/app`
- shinyapps.io: `/srv/connect/apps/eurobarometer-survey-explorer`

### Final Fix
Move `eb_clean.rds` inside the `app/` folder and use a simple relative path:

```r
readRDS("eb_clean.rds")
```

This works everywhere because the file is always in the same directory as `app.R`.

### Lesson
The most portable path is no path — keep data files in the same directory as the app. Relative paths like `../data/` only work when you control the working directory, which you don't on hosted platforms.

---

### Problem 2 — Data file not bundled with shinyapps.io deploy

**Symptom:** `cannot open compressed file '../data/eb_clean.rds'`

**Cause:** `rsconnect::deployApp('app/')` only bundles files inside the `app/` folder. Files outside it are not uploaded.

**Fix:** Move the data file into `app/` and update the path:

```bash
cp data/eb_clean.rds app/eb_clean.rds
```

```r
eb_data <- readRDS("eb_clean.rds")
```

**Lesson:** shinyapps.io only sees what's in the folder you deploy. Data files must be co-located with the app.

---

### Problem 3 — Data file ignored by git

**Symptom:** `git add app/eb_clean.rds` silently ignored because `.gitignore` had a rule for `*.rds`.

**Fix:** Force add it:

```bash
git add -f app/eb_clean.rds
```

**Lesson:** Check `.gitignore` when files don't appear in `git status`. Binary data files are often excluded by default patterns.

---

## 6. Docker Debugging

### Problem 1 — Dockerfile not committed

**Error:** `open Dockerfile: no such file or directory`

**Cause:** Dockerfile existed locally but was never committed to git. Render pulls from GitHub, not your local machine.

**Fix:**
```bash
git add Dockerfile
git commit -m "Add Dockerfile"
git push origin main
```

---

### Problem 2 — Wrong base image

**Error:** `exit status 128` / app crashes immediately on startup

**Cause:** Used `rocker/verse` or `rocker/tidyverse` as the base image. Neither includes Shiny Server — they are R environments only.

**Fix:**
```dockerfile
FROM --platform=linux/amd64 rocker/shiny:latest
```

**Lesson:** `rocker/shiny` is the only Rocker image that includes Shiny Server. `rocker/verse` and `rocker/tidyverse` are for data science work, not serving apps.

---

### Problem 3 — Missing system dependencies for R packages

**Error:** `installation of package 'textshaping' had non-zero exit status`

**Cause:** Some R packages (particularly those in tidyverse like `ragg` and `textshaping`) require system-level graphics libraries not included in the base `rocker/shiny` image.

**Fix:** Add system dependencies to the Dockerfile and install only the specific packages your app needs:

```dockerfile
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','dplyr','ggplot2','stringr','haven','broom'), repos='https://cloud.r-project.org/')"
```

**Lesson:** Don't install `tidyverse` as a bundle — install only the specific packages your app actually uses. The full tidyverse bundle pulls in packages with complex system dependencies that frequently fail to compile.

---

### Problem 4 — Image fails to build on Apple Silicon

**Error:** `no match for platform in manifest`

**Cause:** Building on Apple Silicon (ARM64) but Render runs on AMD64.

**Fix:**
```dockerfile
FROM --platform=linux/amd64 rocker/shiny:latest
```

---

### Problem 5 — App not found at URL

**Cause:** Shiny Server ships with a default `index.html` that overrides routing, and the default config serves a directory of apps rather than pointing directly at one.

**Fix:** Remove the default index and add a custom `shiny-server.conf`:

```dockerfile
RUN rm -f /srv/shiny-server/index.html
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
```

```
run_as shiny;
server {
  listen 3838;
  location / {
    app_dir /srv/shiny-server/app;
    log_dir /var/log/shiny-server;
  }
}
```

---

### Problem 6 — File permissions

**Cause:** Files copied into the container are owned by root. Shiny Server runs as the `shiny` user and can't read them.

**Fix:** Add a `chown` after all `COPY` commands:
```dockerfile
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/
```

**Lesson:** The `chown` must come AFTER all `COPY` commands. If it runs before a `COPY`, the copied files arrive owned by root and the permission fix doesn't apply.

---

### Problem 7 — Corrupted RDS file in git

**Error:** `error reading from connection` when loading `eb_clean.rds`

**Cause:** Large binary files committed to git without Git LFS get corrupted during transfer. The 37MB RDS file was being treated as a text file.

**Fix:** Use Git LFS for binary data files:
```bash
brew install git-lfs
git lfs install
git lfs track "*.rds"
git add .gitattributes
git add data/eb_clean.rds
git commit -m "Track RDS files with Git LFS"
git push origin main
```

**Lesson:** Any binary file over a few MB should be tracked with Git LFS. Without it, git can silently corrupt the file during push/pull.

---

## 7. Memory Issues

### Problem 1 — Out of memory on Render free tier (512MB)

**Cause:** R with packages loaded plus a 37MB dataset exceeded the 512MB free tier limit.

**Lesson:** Render's free tier cannot run a Shiny app with tidyverse + a large dataset. Either upgrade to the $7/month plan or use shinyapps.io.

---

### Problem 2 — Out of memory on shinyapps.io (1GB)

**Cause:** The full 37MB RDS file had 153 columns. Even though `select()` was called after `readRDS()`, R loads the entire file into memory before filtering runs.

**Fix:** Pre-filter the dataset before saving so the RDS file is small from the start:

```r
eb_slim <- load_eb_data() |>
  dplyr::select(nation1, year, particip_num, polint_num,
                mediause_num, relimp_num, income_num)
saveRDS(eb_slim, "app/eb_clean.rds")
```

This reduced the file from 37MB to 1.3MB — well within memory limits.

**Lesson:** `select()` in your app code doesn't help if the full file is already loaded. The filtering must happen before `saveRDS()`, not after `readRDS()`. Always slim down your precomputed data to only the columns your app actually uses.

---

## 8. Systematic Debugging Workflow

When something breaks, work through these steps in order:

```
Step 1 — Identify the layer (data / code / Shiny / Docker)

Step 2 — Check logs
docker logs <container-id>           # Docker
Render dashboard → Logs              # Render
shinyapps.io dashboard → Logs        # shinyapps.io

Step 3 — If logs are vague, run the app directly in R
R -e "shiny::runApp('path/to/app')"

Step 4 — Inspect the container filesystem
docker run -it <image-name> bash
ls /srv/shiny-server/

Step 5 — Check file sizes and contents
ls -lh app/
readRDS("app/eb_clean.rds") |> head()

Step 6 — Fix ONE thing at a time and redeploy
```

---

## Final Project Architecture

```
project/
├── app/
│   ├── app.R              # Shiny UI + server logic
│   └── eb_clean.rds       # Pre-filtered data (7 columns, 1.3MB)
├── data/
│   └── eurobarometer_trends.dta
├── data_prep.R            # Data cleaning pipeline
├── Dockerfile             # Container config for Render
├── shiny-server.conf      # Custom Shiny Server routing config
├── renv.lock              # Locked R package versions
└── analysis.qmd           # Quarto analysis
```

---

## Deployment Comparison

| | Render | shinyapps.io |
|---|---|---|
| Setup complexity | High (Docker required) | Low (one R command) |
| Free tier RAM | 512MB | 1GB |
| Cold start | Slow (spins down) | Slow (spins down) |
| Deploy command | `git push` + manual trigger | `rsconnect::deployApp()` |
| Best for | Full control, custom config | Quick deploys, Shiny-specific |

**Recommendation:** Use shinyapps.io for Shiny apps unless you have a specific reason to use Docker.

---

## Ten Things Worth Remembering

1. **Precompute and slim down data** — filter to only required columns before saving RDS
2. **Use `as_factor()` before `as.character()`** on Haven labelled variables
3. **Keep data files in the same folder as `app.R`** — the most portable approach across platforms
4. **`rocker/shiny` is the only base image with Shiny Server** — not `rocker/verse` or `rocker/tidyverse`
5. **`chown` must come after all `COPY` commands** in the Dockerfile
6. **Use Git LFS for binary files** — RDS, CSV, and data files over a few MB
7. **Always check the container filesystem** when Docker breaks — `docker run -it <image> bash`
8. **Paths depend on working directory** — what works locally may not work in a container or on a hosted platform
9. **Use `runApp()` to get real errors** — the browser message is almost never enough
10. **Test against the R version your platform uses** — syntax valid in older R may fail on newer versions