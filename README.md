# Kenya STEP Skills Dashboard
### World Bank STEP Employer Survey (2016) + Household Survey (2013)

---

## STEP-BY-STEP SETUP IN RSTUDIO

### Step 1 — Create your project folder
In RStudio: **File → New Project → New Directory → New Project**
Name it `kenya_step_dashboard`. This creates a dedicated folder.

### Step 2 — Copy all files into the project folder
Place these files in the **same folder** (`kenya_step_dashboard/`):

```
kenya_step_dashboard/
├── app.R                              ← Main Shiny app (the dashboard)
├── data_prep.R                        ← Data cleaning script (run once)
├── install_packages.R                 ← Package installer (run once)
├── KEN_2016_STEP-EMP_v01_M_CSV.zip   ← Employer survey ZIP (download from World Bank; not in repo)
└── KEN_2013_STEP-HH_v02_M_CSV.zip    ← Household survey ZIP (download from World Bank; not in repo)
```

### Step 3 — Install required R packages (run once)
In the RStudio **Console**, type:
```r
source("install_packages.R")
```
Wait for all packages to finish installing (takes 2–5 minutes on first run).

### Step 4 — Prepare the data (run once)
In the RStudio **Console**, type:
```r
source("data_prep.R")
```
This will:
- Unzip the World Bank files
- Clean and recode all variables
- Save `emp_clean.csv` and `hh_clean.csv` in your project folder

You should see: ✅ Data preparation complete!

### Step 5 — Launch the dashboard
In the RStudio **Console**, type:
```r
shiny::runApp()
```
Or click the **Run App** button at the top of the `app.R` editor pane.

The dashboard will open in your browser (or RStudio viewer pane).

---

## DASHBOARD STRUCTURE

| Tab | Data Source | What it shows |
|-----|------------|---------------|
| **Overview** | Both | KPI cards, employment status, firm sectors & sizes |
| **Skills Supply** | Household Survey (2013) | Wages by education, literacy rates, training rates by sector, personality traits |
| **Skills Demand** | Employer Survey (2016) | Skill gaps by sector, training provision, unfilled vacancies |
| **Skills Gap** | Both combined | Bubble chart matching supply vs demand, education wage premium table |
| **Earnings Analysis** | Household Survey (2013) | Wage distributions, occupation earnings, gender wage gap |

### Global Filters (left sidebar)
- **Gender** — filter all household-level charts by Male / Female
- **Age Range** — restrict to specific age bands
- **Education Level** — select which education groups to include

> Note: Employer survey charts are not affected by household filters since they
> come from a separate survey of firms, not individuals.

---

## DATA SOURCES

| Survey | Year | Coverage | N |
|--------|------|----------|---|
| STEP Household Survey | 2013 | Urban Kenya | 3,894 workers |
| STEP Employer Survey  | 2016 | Urban Kenya | 504 firms |

Download from: https://microdata.worldbank.org/index.php/catalog/2996
and: https://microdata.worldbank.org/index.php/catalog/2226

---

## TROUBLESHOOTING

**"cannot open file 'emp_clean.csv'"**
→ You haven't run `data_prep.R` yet. Run `source("data_prep.R")` first.

**"there is no package called 'shinydashboardPlus'"**
→ Run `source("install_packages.R")` and wait for it to finish.

**"Could not find 'KEN_Final ES Data.csv'"**
→ The ZIP file is not in the project folder. Move it to `kenya_step_dashboard/`.

**Dashboard opens but charts are empty**
→ Check that `emp_clean.csv` and `hh_clean.csv` are in the same folder as `app.R`.

**Plotly charts show a grey box**
→ This is a loading state. Wait 2–3 seconds; large datasets take a moment to render.

---

## KEY VARIABLES USED

### Household Survey (hh_clean.csv)
| Variable | Description |
|----------|-------------|
| `gender_label` | Male / Female |
| `age` | Age in years (15–64) |
| `educ_group` | Education bracket (None → University+) |
| `emp_status` | Wage Worker / Informal Wage / Unemployed / Inactive |
| `earnings_h_usd` | Hourly earnings in USD |
| `literacy_pct` | ETS literacy test score as % of maximum |
| `has_training` | 1 = received vocational/skills training |
| `extraversion_av` … `grit_av` | Big-5 personality + grit (scale 1–4) |

### Employer Survey (emp_clean.csv)
| Variable | Description |
|----------|-------------|
| `sector_label` | Industry sector (18 categories) |
| `size_cat` | Firm size band (Micro / Small / Medium / Large) |
| `diff_soft` | 1 = firm reports difficulty finding workers with soft skills |
| `diff_tech` | 1 = firm reports difficulty finding workers with technical skills |
| `provides_training` | 1 = firm provides on- or off-job training |
| `has_vacancies` | 1 = firm has unfilled vacancies |
| `city` | Survey city (Nairobi, Mombasa, Kisumu, Nakuru …) |

---

## DATA SOURCE & LICENCE

The raw survey files are **not included** in this repository. Download them from the
[World Bank Microdata Library](https://microdata.worldbank.org) (search "STEP Kenya"):

- `KEN_2016_STEP-EMP_v01_M_CSV.zip` – STEP Employer Survey, 2016
- `KEN_2013_STEP-HH_v02_M_CSV.zip` – STEP Household Survey, 2013

Place both zip files in the project folder, then run `source("data_prep.R")` to
regenerate `emp_clean.csv` and `hh_clean.csv`. Use of the data is subject to the
World Bank's terms of use for these datasets. Please cite the World Bank STEP programme
when reusing results.

## QUICK START

```r
source("kenya_step_dashboard.R")   # installs packages + prepares data (needs the raw zips)
shiny::runApp()                    # launch the dashboard
```

Open `kenya_step_dashboard.Rproj` in RStudio first so paths resolve correctly.
