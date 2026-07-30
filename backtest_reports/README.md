# 台股策略回測報告（FinLab `sim()`）

本目錄存放 **17 份**量化策略的回測 HTML 報告，含權益曲線、Drawdown、逐筆交易紀錄與績效指標。

---

## ⚠️ 先讀這段：這些報告是什麼、不是什麼

| | 說明 |
|---|---|
| **是什麼** | **研究層的策略候選篩選結果**——用來挑出值得進一步驗證的方向 |
| **不是什麼** | **不是實盤績效**，也**不是可直接部署的策略** |
| **成本** | ✅ **已扣**手續費（2.2 折 / 3 折，`feeRatio` 0.000314 / 0.000428）與證交稅（`taxRatio` 0.3%） |
| **未納入** | ❌ **滑價**、❌ **流動性 / 容量限制**、❌ **借券與融資成本**、❌ 漲跌停無法成交、❌ 除權息稅務細節 |
| **樣本切分** | ⚠️ **全期回測，未做 IS/OOS 切分**——這是與 [`../flowcharts/market_risk.md`](../flowcharts/market_risk.md) 系列研究最大的差別 |
| **選擇偏誤** | ⚠️ 這 17 份是**留下來的**。試過而被淘汰的組合沒有留報告 → 存在**倖存者偏誤**，指標應視為**上界** |

> **面試時的標準說法**：
> 「這些是我在研究階段用 FinLab 回測篩策略候選的產出，**成本扣了手續費跟證交稅，但沒有扣滑價、
> 也沒有做 IS/OOS 切分**。所以我不會拿這裡的年化報酬當成績，它的用途是**挑方向**。
> 真正把統計嚴謹度做完整的是 `market-risk` 那條線——那邊有 purged walk-forward、
> block bootstrap、FDR 校正，還有事前登記跟一次性 hold-out。**兩者的嚴謹度不同，用途也不同。**」

---

## 績效摘要

> 期間統一到 2026-07-30（報告產出日）。各策略起始日不同，取決於其所用因子的資料可用起點。
> **報酬欄刻意不加粗**——重點在下方的限制，不在數字大小。

| 策略 | 檔案 | 期間 | 年化報酬 | Sharpe | 最大回撤 | Calmar | 勝率 |
|---|---|---|---:|---:|---:|---:|---:|
| super8888 | `super8888.html` | 2016-12 ~ 2026-07 | 111.4% | 2.59 | −34.4% | 3.24 | 54.1% |
| yoy_v5 | `s_yoy_v5.html` | 2016-11 ~ 2026-07 | 106.4% | 2.19 | −25.3% | 4.21 | 52.2% |
| super8 | `super8.html` | 2017-01 ~ 2026-07 | 97.6% | 2.19 | −30.3% | 3.23 | 56.1% |
| **營收股價雙渦輪** | `revenue_price_turbo.html` | 2017-01 ~ 2026-07 | 96.2% | 2.38 | −25.1% | 3.83 | 58.1% |
| GVI_V1 | `gvi_v1.html` | 2017-01 ~ 2026-07 | 87.3% | 2.56 | −25.7% | 3.39 | 53.1% |
| Super888 | `super888.html` | 2017-01 ~ 2026-07 | 80.9% | 2.08 | −27.0% | 3.00 | 52.2% |
| Capital_Layer | `capital_layer.html` | 2018-03 ~ 2026-07 | 74.0% | 2.09 | −23.9% | 3.09 | 52.4% |
| **暴力營收** | `aggressive_revenue.html` | 2016-12 ~ 2026-07 | 72.9% | 1.88 | −32.0% | 2.28 | 49.3% |
| **小市值** | `small_cap.html` | 2013-06 ~ 2026-07 | 69.8% | 2.05 | −26.8% | 2.61 | 50.1% |
| **強勢突圍** ⚠️ | `strong_breakout.html` | 2013-06 ~ 2026-07 | 69.8% | 2.05 | −26.8% | 2.61 | 50.1% |
| S_yoy_v2_v1 | `s_yoy_v2_v1.html` | 2014-04 ~ 2026-07 | 69.1% | 2.36 | −28.7% | 2.41 | 55.4% |
| **集保_1** | `jibao_1.html` | 2017-01 ~ 2026-07 | 67.9% | 2.02 | −22.2% | 3.06 | 55.6% |
| **五線穿雲術** | `five_line_cloud.html` | 2013-06 ~ 2026-07 | 64.4% | 1.95 | −28.5% | 2.26 | 48.9% |
| LowVol_Alpha_V2 | `lowvol_alpha_v2.html` | 2013-06 ~ 2026-07 | 60.5% | 1.87 | −33.4% | 1.81 | 51.0% |
| LowVol_Alpha_V1 | `lowvol_alpha_v1.html` | 2013-06 ~ 2026-07 | 58.6% | 1.88 | −26.6% | 2.20 | 48.6% |
| **超級績效** | `super_performance.html` | 2017-01 ~ 2026-07 | 52.5% | 1.80 | −25.1% | 2.09 | 43.1% |
| **國家認證2** | `national_cert_2.html` | 2014-01 ~ 2026-07 | 33.6% | 2.36 | −25.8% | 1.30 | 65.3% |

> 「策略」欄用的是**報告檔內 `<title>` 的實際名稱**（不是另外翻譯的），方便你打開檔案對照。
> ⚠️ 標記見下方「已知資料問題」。

### 🚨 已知資料問題（自己先揭露）

**`small_cap.html`（小市值）與 `strong_breakout.html`（強勢突圍）的回測數據完全相同。**

兩個檔案除了 `<title>` 不同之外，**績效指標與交易紀錄逐位元一致**——
表示其中一份是用錯誤的策略設定產出的（很可能是複製後只改了標題）。

- **處置**：待重跑其中一份後更新。在此之前，**這兩份只能算一份有效樣本**
- **為什麼寫在這裡**：與其讓面試官自己發現兩條一模一樣的權益曲線掛著不同名字，
  不如自己標出來。這種一致性檢查本來就該做

---

## 為什麼年化報酬看起來這麼高？（必問題的預備答案）

表上多數策略年化 50%–110%、Sharpe 1.8–2.6。**這個量級應該引起懷疑，不是引起讚嘆。** 誠實的歸因：

1. **台股小型股 + 動能 / 營收成長類因子在這段期間確實強勢**——2013~2026 涵蓋數個台股大多頭
2. **未扣滑價**：這類策略多集中在中小型股、且**月頻換股**，實際滑價會顯著吃掉報酬
3. **未做容量分析**：`is_largest(10)` 這種選 10 檔的設計，資金一放大就會推動自己的成交價
4. **未做 IS/OOS 切分**：全期最佳化的參數（停損、選股數）本身就帶有樣本內偏誤
5. **倖存者偏誤**：留下來的 17 份是通過我主觀篩選的，被淘汰的沒留報告

> **收尾**：「我知道這些數字看起來太好。這正是為什麼我後來把重心移到 `market-risk`——
> 那條線的每個結論都要過 purged walk-forward、block bootstrap、FDR，
> 而且**大部分議題的結論是 PIVOT 或 CONDITIONAL，不是 KEEP**。
> 回測報告是我的起點，不是我的證據。」

---

## 回測設定（各報告內可查）

| 參數 | 值 | 說明 |
|---|---|---|
| `feeRatio` | 0.000314 / 0.000428 | 手續費（0.1425% × 2.2 折 / 3 折） |
| `taxRatio` | 0.003 | 證交稅 0.3% |
| `tradeAt` | `close` / `open_close_avg` | 成交價基準（依策略而異） |
| `stopLoss` | 0.08 ~ 0.35 / 無 | 停損設定（依策略而異） |
| `takeProfit` | 0.8 / `Infinity` | 停利設定（多數不設） |
| 換股頻率 | 月頻（依月營收發布日） | 部分策略為訊號觸發 |

---

## 技術規格（已實測）

| 項目 | 實測結果 |
|---|---|
| 檔案大小 | 每份 **2.2 ~ 2.4 MB**，17 份共 **40 MB** |
| **外部依賴** | ✅ **完全沒有**——圖表庫（lightweight-charts + d3）與資料全部內嵌，**離線可開** |
| 渲染測試 | ✅ **17/17 全部正常**（headless Chrome 實測，**0 個 JS error**） |
| 載入時間 | 每份約 **2.7 秒**（本機檔案） |
| 內容 | 互動式權益曲線、月報酬、逐筆交易、年度比較（4 個 tab） |

> **結論：HTML 本身沒有任何問題，不會不能用。** 全自包含、無 CDN 依賴、零錯誤，
> 雙擊就開、離線也開得起來。面試現場用筆電直接開是最穩的方式。

---

## 線上預覽

GitHub 直接開 `.html` 只會顯示原始碼，需要透過能渲染的方式開啟。

### 方式 1：GitHub Pages（★ 推薦，最穩）

在 repo 的 **Settings → Pages → Source 選 `main` branch / root** 之後，
每份報告都有一個乾淨的永久網址、**直接由 GitHub 提供服務、沒有代理與大小限制**：

```
https://jang-jhih.github.io/quant-interview-prep/backtest_reports/<檔名>.html
```

### 方式 2：htmlpreview.github.io（免設定，但有風險）

```
https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/<檔名>.html
```

> ⚠️ **這個服務是第三方代理，2.4 MB 的檔案偏大**——它會先把整份 raw 內容抓下來再注入頁面，
> 在網路差的環境可能**慢到數十秒或直接失敗**。**不要把它當面試現場的唯一方案。**
> 下方連結表用的是這個服務（免設定），但正式對外請改用 GitHub Pages。

### 方式 3：本機（面試現場首選）

1. **直接開啟**：雙擊 `.html` 或拖曳至瀏覽器——**無外部依賴，離線可用**
2. **本機 HTTP 伺服器**（要展示多份時較方便）：
   ```bash
   python3 -m http.server 8000
   ```
   然後開 `http://localhost:8000/backtest_reports/`

> **面試現場建議**：先在本機把要展示的 2~3 份**開好放在分頁**，不要當場才載入或依賴會場 Wi-Fi。

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

---

## 命名說明

多數報告的檔內 `<title>` 是有語意的策略名（**營收股價雙渦輪**、**五線穿雲術**、**暴力營收**、
**小市值**、**強勢突圍**、**集保_1**、**超級績效**、**國家認證2**），
但**檔名是英文化／代號化的**，兩者不一致。

少數幾份連 title 也是開發期代號：`super8` / `Super888` / `super8888` /
`Capital_Layer` / `GVI_V1` / `S_yoy_v2_v1` / `yoy_v5` / `LowVol_Alpha_V1/V2`。

**待辦**：把檔名與 title 對齊成同一組可讀名稱。

> 被問到「super8888 是什麼意思」——老實說是開發期的迭代編號，不用現場編一個解釋。

---

## 與 `flowcharts/` 的關係

| | `backtest_reports/`（本目錄） | [`flowcharts/`](../flowcharts/) |
|---|---|---|
| 性質 | FinLab 全期回測，研究層候選篩選 | 事件型風險研究，含完整統計驗證 |
| 統計嚴謹度 | 低（無 OOS、無 FDR、無 bootstrap） | 高（purged WF、block bootstrap、FDR、事前登記、一次性 hold-out） |
| 結論性質 | 「這個方向值得繼續看」 | KEEP / PIVOT / CONDITIONAL / DISCARD |
| 用途 | 展示回測工具鏈熟練度與策略直覺 | 展示研究方法論 |

> 策略搜尋的自動化版本見
> [`flowcharts/example_universe_selection.md`](universe_selection_deep_GA.md)（GA 演化選股）。
