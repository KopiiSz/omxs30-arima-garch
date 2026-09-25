# =============================================================================
# 01_data.R — build one clean OMXS30 closing-price series, 1995–2025
# =============================================================================
#
# No single free source covers the full 1995–2025 period without gaps:
#   * Yahoo Finance (^OMX)  — 2008-11 onwards, with 6 missing trading days
#   * Investing.com         — 1995–2014
#   * Nasdaq                — 2016–2026
#
# Strategy: use Yahoo as the primary series, fill gaps from Nasdaq, then from
# Investing.com. Days with no data in any source are dropped.
# The series is the OMXS30 *price* index (not adjusted for dividends).
# =============================================================================

if (!exists("parse_num")) source(file.path("R", "00_setup.R"))
section("1. DATA")

# -----------------------------------------------------------------------------
# 1.1 Load the three sources
# -----------------------------------------------------------------------------

# Yahoo Finance: saved from quantmod::getSymbols() with write.zoo(), so that the
# analysis is reproducible (Yahoo occasionally revises history). To re-download:
#   quantmod::getSymbols("^OMX", src = "yahoo",
#                        from = "1995-01-01", to = "2025-12-31")
#   zoo::write.zoo(OMX, file.path(dir_raw, "omxs30_yahoo_2008_2025.csv"), sep = ",")
yahoo_raw <- read.csv(file.path(dir_raw, "omxs30_yahoo_2008_2025.csv"),
                      stringsAsFactors = FALSE)
yahoo <- xts(yahoo_raw[, c("OMX.Open", "OMX.High", "OMX.Low", "OMX.Close",
                           "OMX.Volume", "OMX.Adjusted")],
             order.by = as.Date(yahoo_raw$Index))

# For a price index, Adjusted == Close, so one of them is redundant
stopifnot(all(yahoo$OMX.Adjusted == yahoo$OMX.Close, na.rm = TRUE))
yahoo_close <- yahoo$OMX.Close

# Investing.com: US date format, prices with thousands separators
inv_raw <- read.csv(file.path(dir_raw, "omxs30_investing_1995_2014.csv"),
                    stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM",
                    colClasses = "character")
inv_close <- xts(parse_num(inv_raw$Price),
                 order.by = as.Date(inv_raw$Date, format = "%m/%d/%Y"))

# Nasdaq: semicolon-separated with a "sep=;" first line, thousands separators
nq_raw <- read.csv(file.path(dir_raw, "omxs30_nasdaq_2016_2026.csv"),
                   sep = ";", skip = 1, stringsAsFactors = FALSE,
                   colClasses = "character", check.names = FALSE)
nq_close <- xts(parse_num(nq_raw[["Closing price"]]),
                order.by = as.Date(nq_raw$Date))

cat("Yahoo:        ", format(start(yahoo_close)), "to", format(end(yahoo_close)),
    "|", nrow(yahoo_close), "rows |", sum(is.na(yahoo_close)), "missing closes\n")
cat("Investing.com:", format(start(inv_close)), "to", format(end(inv_close)),
    "|", nrow(inv_close), "rows |", sum(is.na(inv_close)), "missing closes\n")
cat("Nasdaq:       ", format(start(nq_close)), "to", format(end(nq_close)),
    "|", nrow(nq_close), "rows |", sum(is.na(nq_close)), "missing closes\n")

# -----------------------------------------------------------------------------
# 1.2 Missing trading days in Yahoo — what do the other sources have?
# -----------------------------------------------------------------------------

all_src <- merge(yahoo_close, nq_close, inv_close)
colnames(all_src) <- c("yahoo", "nasdaq", "investing")

missing_dates <- index(yahoo_close)[is.na(yahoo_close)]
cat("\nYahoo dates with missing close, and values in the other sources:\n")
print(all_src[missing_dates])
# Two of the six days can be filled (2012-01-02 from Investing.com, 2021-02-15
# from Nasdaq). The remaining four have no data in any source (also not on FRED)
# and are dropped — a negligible share of ~7,800 observations.

# -----------------------------------------------------------------------------
# 1.3 Consistency check on overlapping dates (Yahoo vs Investing.com)
# -----------------------------------------------------------------------------

overlap <- na.omit(merge(yahoo_close, inv_close, join = "inner"))
diff_pct <- (overlap[, 1] - overlap[, 2]) / overlap[, 2] * 100
cat("\nYahoo vs Investing.com on", nrow(overlap), "overlapping days:\n",
    " mean |diff| =", round(mean(abs(diff_pct)), 4), "%\n",
    " max  |diff| =", round(max(abs(diff_pct)), 4), "%\n",
    " correlation =", round(cor(overlap[, 1], overlap[, 2]), 6), "\n")
# Differences are rounding-level, so splicing the sources is safe.

# -----------------------------------------------------------------------------
# 1.4 Splice: Yahoo -> Nasdaq -> Investing.com
# -----------------------------------------------------------------------------

close <- all_src$yahoo
close[is.na(close)] <- all_src$nasdaq[is.na(close)]
close[is.na(close)] <- all_src$investing[is.na(close)]

prices <- na.omit(close["1995/2025"])
colnames(prices) <- "OMXS30"

# -----------------------------------------------------------------------------
# 1.5 Sanity checks and save
# -----------------------------------------------------------------------------

stopifnot(
  sum(is.na(prices)) == 0,             # no missing values
  sum(prices <= 0) == 0,               # no zero / negative index levels
  sum(duplicated(index(prices))) == 0  # no duplicate dates
)
cat("\nFinal series:", format(start(prices)), "to", format(end(prices)),
    "|", nrow(prices), "observations\n")
print(summary(as.numeric(prices)))

write.csv(data.frame(date = index(prices), close = as.numeric(prices)),
          file.path(dir_processed, "omxs30_close_1995_2025.csv"), row.names = FALSE)

save_plot("fig01_index_level", {
  plot(prices, main = "OMXS30 Index Level, 1995-2025", ylab = "Index level",
       col = "black", lwd = 1.2, grid.ticks.on = NULL, yaxis.right = FALSE)
})

rm(yahoo_raw, yahoo, inv_raw, nq_raw, all_src, close, overlap, diff_pct)
