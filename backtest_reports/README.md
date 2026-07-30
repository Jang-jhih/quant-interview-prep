# Quant Backtest Reports

本目錄存放量化策略的回測 HTML 報告。報告包含權益曲線、Drawdown、詳細交易紀錄以及各項量化績效指標（如 Sharpe Ratio, Max Drawdown, Win Rate 等）。

---

## 網頁預覽方法 (HTML Preview)

GitHub 直接開啟 `.html` 檔案時僅會顯示原始碼。若要線上直接互動與檢視渲染後的圖表，推薦使用 **GitHub HTML Preview** 服務：

網址格式：
```
https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/<REPORT_NAME>.html
```

### 範例連結

| 策略名稱 | 檔案名稱 | 線上預覽連結 |
| :--- | :--- | :--- |
| **Low-Vol Alpha v1** | `lowvol_alpha_v1.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/lowvol_alpha_v1.html) |
| **Low-Vol Alpha v2** | `lowvol_alpha_v2.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/lowvol_alpha_v2.html) |
| **Super8888** | `super8888.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super8888.html) |
| **Super Performance** | `super_performance.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/super_performance.html) |
| **Small Cap Strategy** | `small_cap.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/small_cap.html) |
| **Strong Breakout** | `strong_breakout.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/strong_breakout.html) |
| **Revenue Price Turbo** | `revenue_price_turbo.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/revenue_price_turbo.html) |
| **Five Line Cloud** | `five_line_cloud.html` | [預覽報告](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Jang-jhih/quant-interview-prep/main/backtest_reports/five_line_cloud.html) |

---

## 本地瀏覽方式

若要於本機查看報告，可透過以下方式：

1. **直接用瀏覽器開啟**：雙擊 `.html` 檔案或拖曳至瀏覽器中。
2. **本機 HTTP 伺服器**：
   ```bash
   python3 -m http.server 8000
   ```
   開啟瀏覽器訪問 `http://localhost:8000/backtest_reports/`。
