# Dev Notes — Eurobarometer Survey Explorer

A record of the full development and debugging process for this project — from raw data to deployed Shiny app on Render.

---

## Mental Model

Every issue encountered during this project fell into one of four layers. Debugging became much faster once I learned to identify which layer was broken before trying to fix anything.

| Layer | What it covers |
|---|---|
| 1. Data | Cleaning, file paths, preprocessing |
| 2. R / Code | Objects, functions, execution order |
| 3. Shiny | App structure, routing, reactivity |
| 4. Docker | Environment, filesystem, container config |

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
eb_data <- readRDS("../data/eb_clean.rds")
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

## 3. Shiny App Debugging

### Problem 1 — App not loading ("Not Found")

**Cause:** Wrong folder structure. Shiny Server expects `app.R` to live in a specific location.

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

## 4. File Path Debugging

### Problem
```r
readRDS("data/eb_clean.rds")
```
This worked locally but broke inside Docker.

### Why
The app runs from `/srv/shiny-server/app` inside the container. The data file was at `/srv/shiny-server/data`. The relative path `"data/eb_clean.rds"` looked for the file inside the `app/` folder, not one level up.

### Fix
```r
readRDS("../data/eb_clean.rds")
```

### Lesson
Always ask: where is my code actually running from? Relative paths depend on the working directory, which changes between local development and a container environment.

---

## 5. Docker Debugging

### Problem 1 — Image fails to build

**Error:** `no match for platform in manifest`

**Cause:** Building on Apple Silicon (ARM) but Render runs on AMD64.

**Fix:**
```dockerfile
FROM --platform=linux/amd64 rocker/shiny:latest
```

---

### Problem 2 — Very slow builds (30+ minutes)

**Cause:** `install.packages()` runs on every build, reinstalling everything from scratch.

**Lesson:** Package installation is the slowest layer in a Docker build. Use `renv` with a lockfile so Docker can cache the install layer and only reinstall when `renv.lock` changes. Copy `renv.lock` before copying the rest of the app:

```dockerfile
COPY renv.lock .
RUN R -e "renv::restore()"   # cached unless renv.lock changes
COPY . .                      # changes here don't bust the package cache
```

---

### Problem 3 — App not found at the expected URL

**Cause:** Shiny Server ships with a default `index.html` that overrides app routing.

**Fix:**
```dockerfile
RUN rm /srv/shiny-server/index.html
```

---

### Problem 4 — Wrong container run command

**Wrong:**
```bash
docker run ... bash
```
This opens a shell but doesn't start the app.

**Right:**
```bash
docker run -p 3838:3838 eurobarometer-app
```

---

### Problem 5 — File not copied into container

**Debug approach:** Inspect the container filesystem directly:

```bash
docker run -it eurobarometer-app bash
ls /srv/shiny-server/
```

This lets you verify exactly what made it into the image and what didn't.

---

## 6. Systematic Debugging Workflow

When something breaks, work through these steps in order rather than jumping around:

```
Step 1 — Check the container is running
docker ps

Step 2 — Check logs
docker logs <container-id>

Step 3 — If logs are vague, run the app directly in R
R -e "shiny::runApp('path/to/app')"

Step 4 — Inspect the container filesystem
docker run -it <image-name> bash
ls /srv/shiny-server/

Step 5 — Fix ONE thing at a time and rebuild
```

---

## Final Project Architecture

```
project/
├── app.R                  # Shiny UI + server logic
├── data_prep.R            # Data cleaning pipeline
├── data/
│   └── eurobarometer_trends.dta
├── Dockerfile             # Container config
├── renv.lock              # Locked R package versions
└── analysis.qmd           # Quarto analysis
```

---

## Five Things Worth Remembering

1. **Precompute data** — don't clean inside the app
2. **Always check the container filesystem** when Docker breaks
3. **Paths depend on working directory** — what works locally may not work in a container
4. **Use `runApp()` to get real errors** — the browser message is almost never enough
5. **Fix one layer at a time** — data, code, Shiny, Docker, in that order