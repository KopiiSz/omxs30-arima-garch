[README.md](https://github.com/user-attachments/files/32668888/README.md)
# Modelling Returns and Volatility of the OMXS30 with ARIMA and GARCH

An empirical study of the Swedish stock market. I model the daily log returns of the **OMX Stockholm 30 (OMXS30)** index from 1995 to 2025 with an **ARMA(1,1)** for the conditional mean and a **GARCH(1,1)** with Student-t errors for the conditional variance. The whole analysis is in R.

*Course project, Financial Econometrics, MSc Advanced Economics and Finance, Copenhagen Business School.*
📄 **[Read the full report (PDF)](report/OMXS30_ARIMA_GARCH_report.pdf)**

---

## The story in four steps

1. **Data.** No single free source covers 1995–2025 without gaps, so I splice Yahoo Finance, Nasdaq and Investing.com into one series. On overlapping days the sources agree to within rounding (correlation ≈ 1). The result is 7,783 daily closes.
2. **Stationarity.** Log prices have a unit root (ADF fails to reject, KPSS rejects). Log returns are stationary (ADF −14.35 against a 1% critical value of −3.43; KPSS p > 0.10).
3. **Mean model.** BIC picks ARMA(0,0), which is white noise and what the efficient-market hypothesis predicts. AIC picks **ARMA(1,1)**. I keep ARMA(1,1) because its residuals pass Ljung-Box at 10 lags (p = 0.21) while the white-noise residuals do not (p = 0.0005). I also flag the near-cancelling AR and MA roots (1.339 vs 1.284) as a common-factor risk. Out of sample, the ARMA forecast is essentially no better than forecasting the mean (RMSE 0.009389 against a test-sample SD of 0.009394).
4. **Volatility model.** The squared ARMA residuals are strongly autocorrelated and the ARCH-LM test rejects (p < 0.001). This is volatility clustering, which motivates a joint ARMA(1,1)–GARCH(1,1) estimated by maximum likelihood with Student-t errors. The standardised residuals then pass Ljung-Box (p = 0.60), Ljung-Box on squares (p = 0.11) and ARCH-LM (p = 0.11).

## Key results

| | |
|---|---|
| Sample | 2 Jan 1995 – 30 Dec 2025, 7,782 daily log returns |
| Mean daily return / annualised | 0.0296% / ≈ 7.5% |
| Daily volatility / annualised | 1.39% / ≈ 22% |
| Skewness / excess kurtosis | −0.06 / 4.61 (fat tails) |
| ARMA(1,1) | μ = 0.0003, φ = 0.7468, θ = −0.7790 (all significant at 5%) |
| GARCH(1,1) | ω = 1.86×10⁻⁶, α = 0.0857, β = 0.9055, t-dist. ν = 9.7 |
| Persistence α + β | **0.991**, a half-life of volatility shocks of ≈ **77 trading days** |
| Unconditional volatility | 1.46% daily, ≈ 23% annualised |

Volatility is highly persistent and driven mainly by its own past (β ≫ α). This is in line with Engle & Patton (2001) for the Dow Jones.

## Repository structure

```
omxs30-arima-garch/
├── run_all.R                 # runs the full pipeline
├── R/
│   ├── 00_setup.R            # packages, paths, helpers
│   ├── 01_data.R             # load, splice and clean the three data sources
│   ├── 02_stationarity.R     # ADF/KPSS, log returns, descriptive statistics
│   ├── 03_arima.R            # AIC/BIC selection, Ljung-Box, out-of-sample forecast
│   └── 04_garch.R            # ARCH-LM, ARMA-GARCH (rugarch), diagnostics, vol forecast
├── data/
│   ├── raw/                  # source CSVs (see data/README.md)
│   └── processed/            # spliced series (created by 01_data.R)
├── figures/                  # all figures (created by the scripts)
├── output/                   # result tables as CSV (created by the scripts)
├── report/                   # final report (PDF)
└── docs/img/                 # images used in this README
```

## How to run

Requires R ≥ 4.1.

```r
install.packages(c("xts", "zoo", "forecast", "rugarch", "FinTS",
                   "tseries", "urca", "lmtest", "moments"))
```

Open `omxs30-arima-garch.Rproj` in RStudio (or `setwd()` to the repo root), then:

```r
source("run_all.R")
```

Each script in `R/` can also be run on its own and will source the steps it depends on. Figures are written to `figures/` and tables to `output/`.

## Notes on reproducing the report

- The Yahoo Finance data are read from the saved CSV rather than downloaded live, because Yahoo occasionally revises history. The download code is in `01_data.R` if you want fresh data.
- **Excess kurtosis:** the report's Table 1 gives 1.61. The correct value is **4.61** (raw kurtosis 7.61). The most likely cause is that the `kurtosis()` used in the original session already returned excess kurtosis, so 3 was subtracted twice. The code now calls `moments::kurtosis()` explicitly. The conclusion is unchanged, and the fat tails that motivate Student-t errors are even stronger than reported.
- The ADF statistic for log prices is −1.755 with the Schwert (1989) maximum of 35 lags. The report's −1.759 came from a maximum of 34 lags. Neither is close to rejecting.
- The code has been lightly refactored from the version handed in. It is split into steps, parses the source files correctly, and saves figures and tables. The econometrics is the same.

## Possible extensions

- Asymmetric GARCH (EGARCH, GJR-GARCH) to capture the leverage effect (Christie, 1982)
- Formal out-of-sample evaluation of volatility forecasts against a realised-volatility proxy, e.g. with Mincer–Zarnowitz regressions (Hansen & Lunde, 2005)
- Rolling-window re-estimation instead of a single train/test split

## Data sources

- Yahoo Finance. *OMX Stockholm 30 Index (^OMX)*. https://finance.yahoo.com/quote/%5EOMX/history/
- Investing.com. *OMX Stockholm 30 (OMXS30)*. https://www.investing.com/indices/omx-stockholm-30
- Nasdaq. *OMX Stockholm 30 Index*. https://indexes.nasdaqomx.com/Index/History/OMXS30

All retrieved 14 April 2026. The raw files are included only so the analysis can be reproduced. They remain the property of their providers (see [`data/README.md`](data/README.md)).

## Key references

Bollerslev (1987) · Engle (1982) · Engle & Patton (2001) · Fama (1965, 1970) · Hansen & Lunde (2005) · Mandelbrot (1963) · Schwert (1989) · Tsay (2005). The full list is in the [report](report/OMXS30_ARIMA_GARCH_report.pdf).

## Author

**Koppány Szatmári**. MSc Advanced Economics and Finance, Copenhagen Business School.

## License

The code is released under the [MIT License](LICENSE). The data and the report are not covered by it.
