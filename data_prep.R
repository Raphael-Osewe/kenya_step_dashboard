# =============================================================================
#  DATA PREPARATION SCRIPT  —  data_prep.R
#  Run this script ONCE before launching app.R
#
#  INPUT:  Two ZIP files from the World Bank microdata portal:
#          • KEN_2016_STEP-EMP_v01_M_CSV.zip   (Employer Survey)
#          • KEN_2013_STEP-HH_v02_M_CSV.zip    (Household Survey)
#
#  OUTPUT: emp_clean.csv  +  hh_clean.csv   (saved in the same folder)
#
#  HOW TO RUN:
#    1. Put both ZIP files in the  kenya_step_dashboard/  folder
#    2. Open this script in RStudio
#    3. Click  Source  (top-right of editor pane)  OR run:
#         source("data_prep.R")
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(stringr)

cat("━━━ KENYA STEP: Data Preparation ━━━\n\n")

# ── 0. Check ZIPs exist ───────────────────────────────────────────────────────
zip_emp <- "KEN_2016_STEP-EMP_v01_M_CSV.zip"
zip_hh  <- "KEN_2013_STEP-HH_v02_M_CSV.zip"

if (!file.exists(zip_emp)) stop("Cannot find: ", zip_emp,
  "\nPlease put the ZIP in the kenya_step_dashboard/ folder.")
if (!file.exists(zip_hh))  stop("Cannot find: ", zip_hh,
  "\nPlease put the ZIP in the kenya_step_dashboard/ folder.")

# ── 1. Extract to a temp folder ───────────────────────────────────────────────
tmp <- file.path(tempdir(), "step_data")
dir.create(tmp, showWarnings = FALSE)

cat("Extracting employer survey …\n")
unzip(zip_emp, exdir = tmp, overwrite = TRUE)

cat("Extracting household survey …\n")
unzip(zip_hh,  exdir = tmp, overwrite = TRUE)

# ── 2. Locate the actual CSV files ────────────────────────────────────────────
emp_csv <- list.files(tmp, pattern = "KEN_Final ES Data\\.csv", recursive = TRUE,
                       full.names = TRUE)[1]
hh_csv  <- list.files(tmp, pattern = "STEP Kenya_working\\.csv", recursive = TRUE,
                       full.names = TRUE)[1]

if (is.na(emp_csv)) stop("Could not find 'KEN_Final ES Data.csv' inside the employer ZIP.")
if (is.na(hh_csv))  stop("Could not find 'STEP Kenya_working.csv' inside the household ZIP.")

cat("Found employer CSV:  ", emp_csv, "\n")
cat("Found household CSV:", hh_csv,  "\n\n")

# ── 3. Read raw data ──────────────────────────────────────────────────────────
cat("Reading employer survey … ")
emp_raw <- read_csv(emp_csv, show_col_types = FALSE)
cat(nrow(emp_raw), "rows,", ncol(emp_raw), "columns\n")

cat("Reading household survey … ")
hh_raw <- suppressWarnings(read_csv(hh_csv, show_col_types = FALSE))
cat(nrow(hh_raw), "rows,", ncol(hh_raw), "columns\n\n")

# ── 4. CLEAN EMPLOYER SURVEY ──────────────────────────────────────────────────
cat("Cleaning employer survey …\n")

sector_map <- c(
  `1`  = "Agriculture",      `2`  = "Mining",
  `3`  = "Manufacturing",    `4`  = "Utilities",
  `6`  = "Construction",     `7`  = "Trade/Retail",
  `8`  = "Transport",        `9`  = "Finance & Business",
  `10` = "Education",        `11` = "Health",
  `12` = "Arts/Recreation",  `13` = "Hotels & Food",
  `14` = "ICT",              `15` = "Water/Sanitation",
  `16` = "Real Estate",      `18` = "Professional Svcs",
  `19` = "Other Services",   `20` = "Public Admin"
)

age_map    <- c(`1` = "Under 25", `2` = "25-44", `3` = "45-64", `4` = "65+")
gender_map <- c(`1` = "Male",     `2` = "Female")

emp_clean <- emp_raw %>%
  transmute(
    city          = trimws(MUNICIPALITY),
    sector_label  = recode(as.character(SECTOR), !!!sector_map, .default = "Other"),
    age_label     = recode(as.character(AGE1),   !!!age_map,    .default = "Unknown"),
    gender_label  = recode(as.character(GENDER1),!!!gender_map, .default = "Unknown"),
    SIZE          = SIZE,
    size_cat      = case_when(
      SIZE < 10   ~ "Micro(<10)",
      SIZE < 50   ~ "Small(10-50)",
      SIZE < 200  ~ "Medium(50-200)",
      TRUE        ~ "Large(200+)"
    ),
    # Skill difficulty: 2 = difficult, 1 = not difficult
    diff_soft         = as.integer(M_2_01S == 2),
    diff_tech         = as.integer(M_2_01T == 2),
    # Training: 2=on-job, 3=off-job, 4=both → provides training
    provides_training = as.integer(M_5_01 %in% c(2, 3, 4)),
    # Unfilled vacancies: 2=few, 3=many
    has_vacancies     = as.integer(M_2_02B %in% c(2, 3)),
    # Productivity: 1 = increased
    productivity_up   = as.integer(M_6_01 == 1),
    # Gender preference: 1 = prefers male
    prefers_male      = as.integer(MOD1_02 == 1),
    Final_weight      = Final_weight
  )

cat("  → Employer clean: ", nrow(emp_clean), "rows,", ncol(emp_clean), "columns\n")

# ── 5. CLEAN HOUSEHOLD SURVEY ─────────────────────────────────────────────────
cat("Cleaning household survey …\n")

sector_hh <- c(`1` = "Agriculture", `2` = "Industry",
                `3` = "Trade/Commerce", `4` = "Services")
occ_map   <- c(`1` = "Managers",      `2` = "Professionals",
               `3` = "Technicians",   `4` = "Clerical",
               `5` = "Service/Sales", `6` = "Skilled Agric",
               `7` = "Craft/Trade",   `8` = "Machine Operators",
               `9` = "Elementary",    `10` = "Other")

hh_clean <- hh_raw %>%
  transmute(
    district_clean   = str_to_title(trimws(district)),
    gender_label     = ifelse(gender == 1, "Male", "Female"),
    age              = age,
    years_educ       = years_educ,
    educ_group       = case_when(
      is.na(years_educ)   ~ NA_character_,
      years_educ == 0     ~ "None",
      years_educ <= 6     ~ "Primary",
      years_educ <= 9     ~ "Junior Sec",
      years_educ <= 12    ~ "Secondary",
      years_educ <= 16    ~ "Tertiary",
      TRUE                ~ "University+"
    ),
    sector_label     = recode(as.character(econ_sector), !!!sector_hh, .default = "Unknown"),
    occ_label        = recode(as.character(occupation),  !!!occ_map,   .default = "Other"),
    emp_status       = case_when(
      wage_worker == 1 & informal_wage == 1 ~ "Informal Wage",
      wage_worker == 1                      ~ "Wage Worker",
      unemployed  == 1                      ~ "Unemployed",
      TRUE                                  ~ "Inactive"
    ),
    read_label       = case_when(
      read == 0 ~ "Cannot Read",
      read == 1 ~ "Letters Only",
      read == 2 ~ "Words",
      read == 3 ~ "Full Passage",
      TRUE      ~ NA_character_
    ),
    has_training     = as.integer(training == 1),
    literacy_pct     = round(ETS_passage / 36 * 100, 1),
    earnings_h_usd   = earnings_h_usd,
    ln_earnings_h_usd = ln_earnings_h_usd,
    extraversion_av  = extraversion_av,
    conscientiousness_av = conscientiousness_avg,   # note: different suffix in raw
    openness_av      = openness_av,
    agreeableness_av = agreeableness_av,
    grit_av          = grit_av,
    W_FinSPwt        = W_FinSPwt
  )

cat("  → Household clean:", nrow(hh_clean), "rows,", ncol(hh_clean), "columns\n\n")

# ── 6. Save ───────────────────────────────────────────────────────────────────
cat("Saving emp_clean.csv …\n")
write_csv(emp_clean, "emp_clean.csv")

cat("Saving hh_clean.csv  …\n")
write_csv(hh_clean, "hh_clean.csv")

cat("\n✅  Data preparation complete!\n")
cat("   Files saved:\n")
cat("   •", normalizePath("emp_clean.csv"),  "\n")
cat("   •", normalizePath("hh_clean.csv"),   "\n\n")
cat("You can now run:  shiny::runApp()\n")
