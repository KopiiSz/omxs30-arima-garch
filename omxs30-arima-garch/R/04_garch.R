# =============================================================================
# 04_garch.R — ARCH effects, joint ARMA(1,1)-GARCH(1,1) estimation, forecast
# =============================================================================

if (!exists("arima_model")) source(file.path("R", "03_arima.R"))
section("4. ARCH-LM TEST AND GARCH")

# -----------------------------------------------------------------------------
# 4.1 Are there ARCH effects in the ARMA residuals?
# -----------------------------------------------------------------------------

arima_resid <- as.numeric(residuals(arima_model))

save_plot("fig07_acf_pacf_squared_arma_residuals", {
  par(mfrow = c(1, 2))
  acf(arima_resid^2,  lag.max = 40, main = "ACF: squared ARMA residuals")
  pacf(arima_resid^2, lag.max = 40, main = "PACF: squared ARMA residuals")
}, width = 10, height = 4.5)
# Strong, slowly decaying autocorrelation in squared residuals = volatility
# clustering, which a constant-variance ARMA cannot capture.

# ARCH-LM (Engle, 1982)  H0: no ARCH effects. ArchTest() squares internally.
arch_lm <- data.frame(
  lags    = c(2, 5, 10),
  p_value = signif(sapply(c(2, 5, 10), function(l)
    ArchTest(arima_resid, lags = l)$p.value), 3)
)
print(arch_lm)
save_table(arch_lm, "table_arch_lm_arma_residuals")
# H0 rejected at every lag length -> model the conditional variance.

# -----------------------------------------------------------------------------
# 4.2 Joint MLE: ARMA(p,q) mean + GARCH(1,1) variance, Student-t errors
# -----------------------------------------------------------------------------
# GARCH(1,1): Hansen & Lunde (2005) find it is hard to beat.
# Student-t: returns show excess kurtosis (Table 1), cf. Bollerslev (1987).

p <- arimaorder(arima_model)[1]; q <- arimaorder(arima_model)[3]

garch_spec <- ugarchspec(
  variance.model     = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model         = list(armaOrder = c(p, q), include.mean = TRUE),
  distribution.model = "std"
)
garch_fit <- ugarchfit(spec = garch_spec, data = returns)
show(garch_fit)

mc <- garch_fit@fit$matcoef   # columns: estimate, std. error, t value, p-value
garch_table <- data.frame(
  parameter = rownames(mc),
  estimate  = signif(mc[, 1], 4),
  std_error = signif(mc[, 2], 4),
  p_value   = signif(mc[, 4], 3),
  row.names = NULL
)
print(garch_table)
save_table(garch_table, "table3_arma_garch_estimates")

omega  <- coef(garch_fit)["omega"]
alpha1 <- coef(garch_fit)["alpha1"]
beta1  <- coef(garch_fit)["beta1"]
persistence <- alpha1 + beta1
half_life   <- log(0.5) / log(persistence)
uncond_vol  <- sqrt(omega / (1 - persistence))   # daily

garch_summary <- data.frame(
  quantity = c("alpha1 + beta1 (persistence)",
               "Half-life of volatility shocks (trading days)",
               "Unconditional daily volatility",
               "Unconditional annualised volatility"),
  value = round(c(persistence, half_life, uncond_vol, uncond_vol * sqrt(252)), 4)
)
print(garch_summary)
save_table(garch_summary, "table_garch_persistence")
# alpha1 + beta1 just below 1: stationary but very persistent volatility.
# beta1 >> alpha1: today's variance is driven mostly by yesterday's variance
# rather than by yesterday's shock.

# -----------------------------------------------------------------------------
# 4.3 Fitted conditional volatility
# -----------------------------------------------------------------------------

cond_vol <- xts(as.numeric(sigma(garch_fit)), order.by = index(returns))
colnames(cond_vol) <- "cond_vol"

save_plot("fig08_conditional_volatility", {
  plot(index(cond_vol), as.numeric(cond_vol), type = "l", col = "firebrick",
       lwd = 0.8, xlab = "", ylab = "Daily conditional volatility",
       main = "GARCH(1,1) fitted conditional volatility - OMXS30, 1995-2025")
  abline(h = uncond_vol, lty = 2, lwd = 1.5)
  legend("topright", bty = "n", cex = 0.85,
         legend = c("Conditional volatility", "Unconditional volatility"),
         col = c("firebrick", "black"), lty = c(1, 2))
}, width = 11, height = 5)

# -----------------------------------------------------------------------------
# 4.4 Diagnostics on standardised residuals
# -----------------------------------------------------------------------------

std_resid <- as.numeric(residuals(garch_fit, standardize = TRUE))

save_plot("fig09_acf_standardised_residuals", {
  par(mfrow = c(1, 2))
  acf(std_resid,   lag.max = 30, main = "ACF: standardised residuals")
  acf(std_resid^2, lag.max = 30, main = "ACF: squared standardised residuals")
}, width = 10, height = 4.5)

garch_diag <- data.frame(
  test    = c("Ljung-Box, standardised residuals (10 lags)",
              "Ljung-Box, squared standardised residuals (10 lags)",
              "ARCH-LM, standardised residuals (10 lags)"),
  p_value = round(c(
    Box.test(std_resid,   lag = 10, type = "Ljung-Box")$p.value,
    Box.test(std_resid^2, lag = 10, type = "Ljung-Box")$p.value,
    ArchTest(std_resid, lags = 10)$p.value
  ), 4)
)
print(garch_diag)
save_table(garch_diag, "table_garch_diagnostics")
# No remaining autocorrelation in levels (mean equation OK) or squares
# (variance equation OK): GARCH(1,1) is adequate.

# -----------------------------------------------------------------------------
# 4.5 90-trading-day volatility forecast
# -----------------------------------------------------------------------------

h <- 90
garch_fc   <- ugarchforecast(garch_fit, n.ahead = h)
fc_vol_ann <- as.numeric(sigma(garch_fc)) * sqrt(252)

# Future trading days (weekdays; Swedish holidays ignored for plotting)
last_date <- end(returns)
future    <- seq(last_date + 1, by = "day", length.out = h * 2)
future    <- head(future[!format(future, "%u") %in% c("6", "7")], h)

in_sample <- tail(cond_vol, 252) * sqrt(252)

save_plot("fig11_volatility_forecast", {
  y_max <- max(c(as.numeric(in_sample), fc_vol_ann)) * 1.05
  plot(c(index(in_sample), future), c(as.numeric(in_sample), fc_vol_ann),
       type = "n", ylim = c(0, y_max), xlab = "", xaxt = "n",
       ylab = "Annualised volatility",
       main = "Conditional volatility: last year in-sample + 90-trading-day forecast")
  rect(last_date, 0, max(future), y_max, col = adjustcolor("lightblue", 0.25), border = NA)
  lines(index(in_sample), as.numeric(in_sample), col = "firebrick", lwd = 1.5)
  lines(future, fc_vol_ann, col = "firebrick", lwd = 1.5, lty = 1)
  abline(v = last_date, lty = 2, lwd = 1.5)
  abline(h = uncond_vol * sqrt(252), lty = 3, lwd = 1.2)
  axis.Date(1, at = seq(min(index(in_sample)), max(future), by = "2 months"),
            format = "%b %Y", cex.axis = 0.8)
}, width = 10, height = 5)
# The forecast mean-reverts towards the unconditional level (~23% annualised)
# but has not reached it after 90 days — consistent with a ~77-day half-life.

section("DONE — figures in figures/, tables in output/")
