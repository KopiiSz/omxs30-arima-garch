# =============================================================================
# 03_arima.R — model selection, residual diagnostics and out-of-sample forecast
# =============================================================================

if (!exists("returns_ts")) source(file.path("R", "02_stationarity.R"))
section("3. ARIMA")

# -----------------------------------------------------------------------------
# 3.1 Model selection with AIC and BIC (d = 0: returns are already stationary)
# -----------------------------------------------------------------------------

arima_aic <- auto.arima(returns_ts, d = 0, ic = "aic",
                        stepwise = FALSE, approximation = FALSE)
arima_bic <- auto.arima(returns_ts, d = 0, ic = "bic",
                        stepwise = FALSE, approximation = FALSE)

cat("AIC selects: ARIMA(", paste(arimaorder(arima_aic), collapse = ","), ")\n", sep = "")
cat("BIC selects: ARIMA(", paste(arimaorder(arima_bic), collapse = ","), ")\n", sep = "")
# AIC -> ARMA(1,1); BIC -> ARMA(0,0), i.e. white noise, which is what the
# efficient market hypothesis would predict (Fama, 1970).

# -----------------------------------------------------------------------------
# 3.2 Residual diagnostics — decide between the two candidates
# -----------------------------------------------------------------------------

save_plot("fig05_06_residual_acf_pacf_aic_vs_bic", {
  par(mfrow = c(2, 2))
  acf(residuals(arima_aic),  lag.max = 30, main = "ACF: residuals (AIC model)")
  acf(residuals(arima_bic),  lag.max = 30, main = "ACF: residuals (BIC model)")
  pacf(residuals(arima_aic), lag.max = 30, main = "PACF: residuals (AIC model)")
  pacf(residuals(arima_bic), lag.max = 30, main = "PACF: residuals (BIC model)")
}, width = 10, height = 8)

# Ljung-Box, H0: no autocorrelation. Lags ≈ ln(T) ≈ 9, so we use 10
# (Tsay, 2005, p. 33).
lb_lag <- 10
lb_table <- data.frame(
  model    = c("AIC model", "BIC model", "AIC model", "AIC model"),
  lags     = c(lb_lag, lb_lag, 15, 20),
  p_value  = round(c(
    Box.test(residuals(arima_aic), lag = lb_lag, type = "Ljung-Box")$p.value,
    Box.test(residuals(arima_bic), lag = lb_lag, type = "Ljung-Box")$p.value,
    Box.test(residuals(arima_aic), lag = 15,     type = "Ljung-Box")$p.value,
    Box.test(residuals(arima_aic), lag = 20,     type = "Ljung-Box")$p.value
  ), 4)
)
print(lb_table)
save_table(lb_table, "table_ljung_box_arima_residuals")
# With 10 lags the BIC residuals are autocorrelated but the AIC residuals are
# not, so ARMA(1,1) is kept. Caveats (discussed in the report):
#  * at 15-20 lags the AIC model also rejects;
#  * AR and MA coefficients almost cancel (common-factor problem), so the
#    simpler ARMA(0,0) is a serious alternative.

arima_model <- arima_aic
print(coeftest(arima_model))

# Stationarity / invertibility: AR and MA roots must lie outside the unit circle
cat("AR root modulus:", round(Mod(polyroot(c(1, -coef(arima_model)["ar1"]))), 3), "\n")
cat("MA root modulus:", round(Mod(polyroot(c(1,  coef(arima_model)["ma1"]))), 3), "\n")

ct <- coeftest(arima_model)
arima_table <- data.frame(
  parameter = c("Intercept", "AR(1)", "MA(1)"),
  estimate  = round(ct[c("intercept", "ar1", "ma1"), "Estimate"], 4),
  std_error = round(ct[c("intercept", "ar1", "ma1"), "Std. Error"], 4),
  p_value   = signif(ct[c("intercept", "ar1", "ma1"), "Pr(>|z|)"], 3)
)
print(arima_table)
save_table(arima_table, "table2_arma11_estimates")

# -----------------------------------------------------------------------------
# 3.3 Out-of-sample forecast: hold out the last 3 trading years (756 days)
# -----------------------------------------------------------------------------

n_test  <- 3 * 252
n_train <- length(returns_ts) - n_test
train   <- returns_ts[1:n_train]
test    <- returns_ts[(n_train + 1):length(returns_ts)]

p <- arimaorder(arima_model)[1]; q <- arimaorder(arima_model)[3]
arima_train <- Arima(train, order = c(p, 0, q), include.mean = TRUE)
arima_fc    <- forecast(arima_train, h = n_test)

save_plot("fig10_arma_forecast", {
  plot(arima_fc,
       main = sprintf("ARMA(%d,%d): 3-trading-year forecast vs realised returns", p, q),
       ylab = "Log return", xlab = "", xaxt = "n",
       col = "steelblue", fcol = "black", flwd = 2,
       shadecols = c("lightblue", "skyblue"))
  lines((n_train + 1):(n_train + n_test), test, col = "red", lwd = 0.7, lty = 2)
  lines((n_train + 1):(n_train + n_test), as.numeric(arima_fc$mean),
        col = "black", lwd = 2)
  tick_dates <- seq(as.Date("1995-01-01"), as.Date("2025-12-31"), by = "3 years")
  tick_obs   <- sapply(tick_dates, function(d) which.min(abs(index(returns) - d)))
  axis(1, at = tick_obs, labels = format(tick_dates, "%Y"), cex.axis = 0.8)
  legend("bottomleft", bg = "white", cex = 0.8,
         legend = c("In-sample returns", "Realised (test)", "Forecast mean"),
         col = c("steelblue", "red", "black"), lty = c(1, 2, 1), lwd = c(1, 1, 2))
}, width = 11, height = 5)

errors <- test - as.numeric(arima_fc$mean)
forecast_eval <- data.frame(
  metric = c("MAE", "RMSE", "Std. dev. of test sample (naive benchmark)",
             "RMSE / MAE"),
  value  = round(c(mean(abs(errors)), sqrt(mean(errors^2)), sd(test),
                   sqrt(mean(errors^2)) / mean(abs(errors))), 6)
)
print(forecast_eval)
save_table(forecast_eval, "table_arma_forecast_evaluation")
# RMSE ≈ SD of the test sample: the ARMA forecast is essentially no better than
# forecasting the mean. MAPE is not reported — it explodes when returns ≈ 0.
