# =============================================================================
#  install_packages.R
#  Run this ONCE in RStudio to install all required packages.
#  Paste into the Console and press Enter, or click Source.
# =============================================================================

pkgs <- c(
  "shiny",
  "shinydashboard",
  "shinydashboardPlus",
  "plotly",
  "dplyr",
  "tidyr",
  "ggplot2",
  "DT",
  "scales",
  "stringr",
  "readr"
)

cat("Installing / checking", length(pkgs), "packages …\n\n")

for (pkg in pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing:", pkg, "\n")
    install.packages(pkg, dependencies = TRUE)
  } else {
    cat("Already installed:", pkg, "\n")
  }
}

cat("\n✅  All packages ready.\n")
cat("Next step: run  source('data_prep.R')  then  shiny::runApp()\n")
