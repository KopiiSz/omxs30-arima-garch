# =============================================================================
# 02_stationarity.R — log prices vs log returns, unit-root tests, descriptives
# =============================================================================

if (!exists("prices")) source(file.path("R", "01_data.R"))
section("2. STATIONARITY AND DESCRIPTIVE STATISTICS")

# -----------------------------------------------------------------------------
# 2.1 Log price level — expected to be I(1)
# -----------------------------------------------------------------------------

log_prices <- log(prices)
colnames(log_prices) <- "log_price"

save_plot("fig02_acf_pacf_log_price", {
  par(mfrow = c(1, 2))
  acf(as.numeric(log_prices),  lag.max = 30, main = "ACF: log price")
  pacf(as.numeric(log_prices), lag.max = 30, main = "PACF: log price")
}, width = 10, height = 4.5)
# Slow ACF decay = strong persistence, a sign of a unit root.

# Max lag for the ADF test from Schwert (1989): 12 * (T/100)^(1/4) ≈ 35.
# The actual lag length is then chosen by AIC.
adf_max_lag <- floor(12 * (nrow(log_prices) / 100)^(1 / 4))
cat("ADF maximum lag (Schwert, 1989):", adf_max_lag, "\n")

# ADF  H0: unit root (non-stationary)   H1: stationary
adf_log_prices <- ur.df(as.numeric(log_prices), type = "drift",
                        lags = adf_max_lag, selectlags = "AIC")
summary(adf_log_prices)
# KPSS H0: stationary                   H1: unit root
kpss_log_prices <- kpss.test(as.numeric(log_prices), null = "Level")
print(kpss_log_prices)
# ADF fails to reject, KPSS rejects -> log prices are non-stationary.
# First-differencing log prices gives log returns.

# -----------------------------------------------------------------------------
# 2.2 Log returns — expected to be I(0)
# -----------------------------------------------------------------------------

returns <- na.omit(diff(log(prices)))
colnames(returns) <- "log_return"
returns_ts <- as.numeric(returns)
cat("Number of log returns:", length(returns_ts), "\n")

save_plot("fig03_returns_and_squared_returns", {
  par(mfrow = c(1, 2))
  plot(index(returns), returns_ts, type = "l", lwd = 0.5,
       main = "Daily log returns", xlab = "", ylab = "Log return")
  plot(index(returns), returns_ts^2, type = "l", lwd = 0.5,
       main = "Squared daily log returns", xlab = "", ylab = "Squared log return")
}, width = 11, height = 4.5)
# Returns revert around a constant mean, but calm and turbulent periods
# alternate in the squared returns — a first hint of volatility clustering.

save_plot("fig04_acf_pacf_returns", {
  par(mfrow = c(1, 2))
  acf(returns_ts,  lag.max = 30, main = "ACF: log returns")
  pacf(returns_ts, lag.max = 30, main = "PACF: log returns")
}, width = 10, height = 4.5)

adf_returns <- ur.df(returns_ts, type = "drift",
                     lags = adf_max_lag, selectlags = "AIC")
summary(adf_returns)
kpss_returns <- kpss.test(returns_ts, null = "Level")
print(kpss_returns)
# ADF rejects, KPSS does not -> log returns are stationary; we can fit ARMA.

unit_root_tests <- data.frame(
  series    = c("Log price", "Log return"),
  adf_stat  = round(c(adf_log_prices@teststat[1], adf_returns@teststat[1]), 4),
  adf_cv_1pct = adf_returns@cval[1, "1pct"],
  kpss_stat = round(c(kpss_log_prices$statistic, kpss_returns$statistic), 4),
  kpss_p    = c(kpss_log_prices$p.value, kpss_returns$p.value)
)
print(unit_root_tests)
save_table(unit_root_tests, "table_unit_root_tests")

# -----------------------------------------------------------------------------
# 2.3 Descriptive statistics of log returns (Table 1 in the report)
# -----------------------------------------------------------------------------

desc_stats <- data.frame(
  statistic = c("Mean", "Std. dev.", "Minimum", "Maximum",
                "Skewness", "Excess kurtosis", "Observations"),
  value = c(
    round(mean(returns_ts), 6),
    round(sd(returns_ts), 6),
    round(min(returns_ts), 6),
    round(max(returns_ts), 6),
    round(moments::skewness(returns_ts), 4),
    # moments::kurtosis() returns raw (Pearson) kurtosis, so subtract 3 once.
    # Namespaced on purpose: some packages export a kurtosis() that already
    # returns *excess* kurtosis, which would make "- 3" double-count.
    round(moments::kurtosis(returns_ts) - 3, 4),
    length(returns_ts)
  )
)
print(desc_stats)
save_table(desc_stats, "table1_descriptive_statistics")
cat("Annualised mean return:     ", round(mean(returns_ts) * 252 * 100, 2), "%\n")
cat("Annualised volatility:      ", round(sd(returns_ts) * sqrt(252) * 100, 2), "%\n")
# Positive excess kurtosis = fat tails, motivating a Student-t GARCH later.
