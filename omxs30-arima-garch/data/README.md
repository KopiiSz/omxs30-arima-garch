# Data

Daily closing levels of the **OMX Stockholm 30 (OMXS30)** price index. The index is not adjusted for dividends.

| File | Source | Coverage | Format notes |
|---|---|---|---|
| `raw/omxs30_yahoo_2008_2025.csv` | Yahoo Finance (`^OMX`), downloaded with `quantmod::getSymbols()` | 2008-11-20 to 2025-12-30 | Written with `zoo::write.zoo()`. Six days have missing values (`NA`). |
| `raw/omxs30_investing_1995_2014.csv` | Investing.com | 1995-01-02 to 2014-12-02 | Dates are `MM/DD/YYYY`. Prices use thousands separators (`"1,450.03"`). |
| `raw/omxs30_nasdaq_2016_2026.csv` | Nasdaq | 2016-04-11 to 2026-04-10 | Semicolon-separated with a `sep=;` first line. Prices use thousands separators. |

All files were retrieved on 14 April 2026.

## How the series is built (`R/01_data.R`)

1. Use the Yahoo close where it is available.
2. Fill the gaps from Nasdaq, then from Investing.com. This fills 2012-01-02 and 2021-02-15.
3. Drop the four days that have no value in any source: 2017-06-06, 2017-06-23, 2018-06-06 and 2018-06-22.
4. Restrict to 1995–2025. The result is **7,783 observations**, written to `processed/omxs30_close_1995_2025.csv`.

On the 1,513 days where they overlap, Yahoo and Investing.com differ by 0.0004% on average (correlation ≈ 1).

## Terms of use

The data belong to their respective providers. They are included here only so the academic analysis can be reproduced. They must not be redistributed for commercial use, and the MIT license in this repository does not cover them.
