# 台股策略回測報告（FinLab `sim()`）

本目錄存放 **17 份**量化策略的回測 HTML 報告，含權益曲線、Drawdown、逐筆交易紀錄與績效指標。

---

## 績效摘要

> 期間統一到 2026-07-30（報告產出日）。各策略起始日不同，取決於其所用因子的資料可用起點。
> **報酬欄刻意不加粗**——重點在下方的限制，不在數字大小。

| 策略              | 檔案                         | 期間                |   年化報酬 | Sharpe |   最大回撤 | Calmar |    勝率 |
| --------------- | -------------------------- | ----------------- | -----: | -----: | -----: | -----: | ----: |
| super8888       | `super8888.html`           | 2016-12 ~ 2026-07 | 111.4% |   2.59 | −34.4% |   3.24 | 54.1% |
| yoy_v5          | `s_yoy_v5.html`            | 2016-11 ~ 2026-07 | 106.4% |   2.19 | −25.3% |   4.21 | 52.2% |
| super8          | `super8.html`              | 2017-01 ~ 2026-07 |  97.6% |   2.19 | −30.3% |   3.23 | 56.1% |
| **營收股價雙渦輪**     | `revenue_price_turbo.html` | 2017-01 ~ 2026-07 |  96.2% |   2.38 | −25.1% |   3.83 | 58.1% |
| GVI_V1          | `gvi_v1.html`              | 2017-01 ~ 2026-07 |  87.3% |   2.56 | −25.7% |   3.39 | 53.1% |
| Super888        | `super888.html`            | 2017-01 ~ 2026-07 |  80.9% |   2.08 | −27.0% |   3.00 | 52.2% |
| Capital_Layer   | `capital_layer.html`       | 2018-03 ~ 2026-07 |  74.0% |   2.09 | −23.9% |   3.09 | 52.4% |
| **暴力營收**        | `aggressive_revenue.html`  | 2016-12 ~ 2026-07 |  72.9% |   1.88 | −32.0% |   2.28 | 49.3% |
| **小市值**         | `small_cap.html`           | 2013-06 ~ 2026-07 |  69.8% |   2.05 | −26.8% |   2.61 | 50.1% |
| **強勢突圍** ⚠️     | `strong_breakout.html`     | 2013-06 ~ 2026-07 |  69.8% |   2.05 | −26.8% |   2.61 | 50.1% |
| S_yoy_v2_v1     | `s_yoy_v2_v1.html`         | 2014-04 ~ 2026-07 |  69.1% |   2.36 | −28.7% |   2.41 | 55.4% |
| **集保_1**        | `jibao_1.html`             | 2017-01 ~ 2026-07 |  67.9% |   2.02 | −22.2% |   3.06 | 55.6% |
| **五線穿雲術**       | `five_line_cloud.html`     | 2013-06 ~ 2026-07 |  64.4% |   1.95 | −28.5% |   2.26 | 48.9% |
| LowVol_Alpha_V2 | `lowvol_alpha_v2.html`     | 2013-06 ~ 2026-07 |  60.5% |   1.87 | −33.4% |   1.81 | 51.0% |
| LowVol_Alpha_V1 | `lowvol_alpha_v1.html`     | 2013-06 ~ 2026-07 |  58.6% |   1.88 | −26.6% |   2.20 | 48.6% |
| **超級績效**        | `super_performance.html`   | 2017-01 ~ 2026-07 |  52.5% |   1.80 | −25.1% |   2.09 | 43.1% |
| **國家認證2**       | `national_cert_2.html`     | 2014-01 ~ 2026-07 |  33.6% |   2.36 | −25.8% |   1.30 | 65.3% |

| 策略 | 預覽 |
|---|---|
| S YoY v5 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/s_yoy_v5.html) |
| Super8888 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super8888.html) |
| Revenue Price Turbo | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/revenue_price_turbo.html) |
| Super8 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super8.html) |
| GVI v1 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/gvi_v1.html) |
| Super888 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super888.html) |
| Capital Layer | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/capital_layer.html) |
| Aggressive Revenue | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/aggressive_revenue.html) |
| S YoY v2 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/s_yoy_v2_v1.html) |
| 小市值 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/small_cap.html) |
| 強勢突圍 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/strong_breakout.html) |
| Jibao 1 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/jibao_1.html) |
| Five Line Cloud | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/five_line_cloud.html) |
| Low-Vol Alpha v2 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/lowvol_alpha_v2.html) |
| Low-Vol Alpha v1 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/lowvol_alpha_v1.html) |
| Super Performance | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super_performance.html) |
| 國家認證 2 | [開啟](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/national_cert_2.html) |


