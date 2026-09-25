# =============================================================================
# Modelling returns and volatility of the OMXS30 index with ARIMA and GARCH
# Run the full analysis from the project root:  source("run_all.R")
# =============================================================================

source(file.path("R", "00_setup.R"))
source(file.path("R", "01_data.R"))          # build the 1995–2025 price series
source(file.path("R", "02_stationarity.R"))  # unit-root tests, descriptives
source(file.path("R", "03_arima.R"))         # ARMA selection, diagnostics, forecast
source(file.path("R", "04_garch.R"))         # ARCH-LM, ARMA-GARCH, vol forecast

writeLines(capture.output(sessionInfo()), file.path(dir_output, "session_info.txt"))
