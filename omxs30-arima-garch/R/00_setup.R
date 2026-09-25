# =============================================================================
# 00_setup.R — packages, paths and small helpers shared by all scripts
# =============================================================================

required_pkgs <- c(
  "xts", "zoo",      # time-series containers
  "forecast",        # auto.arima(), forecast()
  "rugarch",         # ugarchspec(), ugarchfit(), ugarchforecast()
  "FinTS",           # ArchTest()  (ARCH-LM test, Engle 1982)
  "tseries",         # kpss.test()
  "urca",            # ur.df()     (ADF test)
  "lmtest",          # coeftest()
  "moments"          # skewness(), kurtosis()
)

missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace,
                                      logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop("Missing packages: ", paste(missing_pkgs, collapse = ", "),
       "\nInstall with: install.packages(c(\"",
       paste(missing_pkgs, collapse = "\", \""), "\"))\n",
       "or run renv::restore() if you use renv.", call. = FALSE)
}

suppressPackageStartupMessages({
  library(xts)
  library(forecast)
  library(rugarch)
  library(FinTS)
  library(tseries)
  library(urca)
  library(lmtest)
  library(moments)
})

set.seed(2026)

# Paths (relative to the project root — open the .Rproj or setwd() there) ----
dir_raw       <- file.path("data", "raw")
dir_processed <- file.path("data", "processed")
dir_figures   <- "figures"
dir_output    <- "output"
for (d in c(dir_processed, dir_figures, dir_output)) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

# Helpers ---------------------------------------------------------------------

# Strip thousands separators ("1,234.56") and convert to numeric
parse_num <- function(x) as.numeric(gsub(",", "", as.character(x)))

# Save a plot to figures/<name>.png
# `plot_expr` is any code that draws a plot. plot.xts() returns an object that
# only draws when printed, so if the block's last value is an xts plot we print it.
save_plot <- function(name, plot_expr, width = 9, height = 5, res = 150) {
  path <- file.path(dir_figures, paste0(name, ".png"))
  png(path, width = width, height = height, units = "in", res = res)
  on.exit(dev.off())
  value <- plot_expr
  if (inherits(value, "replot_xts")) print(value)
  message("Saved figure: ", path)
  invisible(path)
}

# Save a data.frame to output/<name>.csv
save_table <- function(df, name) {
  path <- file.path(dir_output, paste0(name, ".csv"))
  write.csv(df, path, row.names = FALSE)
  message("Saved table:  ", path)
  invisible(path)
}

# Print a section header in the console
section <- function(title) {
  cat("\n", strrep("=", 78), "\n ", title, "\n", strrep("=", 78), "\n", sep = "")
}
