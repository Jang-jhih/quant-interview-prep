# 以遺傳演算法優化台股複合條件選股策略

## 專案概述

以 **DEAP 遺傳演算法** 為核心，自動搜尋台股選股策略中「複合條件」的最佳組合，並透過 **YoY 營收加權持倉**、**IS/OOS 內外樣本驗證**、**PBO 過擬合懲罰** 三道機制，確保搜尋出來的策略在同時考慮「獲利能力」與「風險控管」下具備樣本外穩健性。

整個系統圍繞三個核心問題：

1. **搜尋什麼？** 從一組條件清單中，以二進位編碼挑選 4–8 個條件 AND 組合，作為一個「個體」。
2. **怎麼評分？** 把個體的條件組合轉成持倉 → 回測 → 取出 10 個績效指標 → 加權得到適應度。
3. **怎麼避免過擬合？** 60% 內樣本訓練、40% 外樣本驗證，並用 PBO 機率（真實策略沒贏過隨機策略的比例）懲罰適應度。

> 本文件所有流程圖使用 **Mermaid** 語法，配色統一採「淺色底 + 深色字」原則，相容於亮／暗 IDE 主題。顯示方式請見**第八節**。

---

## 一、整體架構

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    USER["📈 策略研究者<br/>設定 config 與持倉函式"] --> ENTRY

    subgraph ENTRY["策略入口 (Notebook)"]
        direction TB
        C1["匯入 GA 套件與 finlab 回測引擎"]
        C2["定義持倉函式 get_position<br/>(YoY 加權 + 流動性篩選)"]
        C3["組裝 config:<br/>・GA 演化參數<br/>・績效指標權重<br/>・條件清單來源<br/>・驗證模式"]
    end

    ENTRY --> MAIN["GA 主流程<br/>while True: 持續優化"]

    MAIN --> M1["初始化日誌系統"]
    MAIN --> M2["解析 CLI 參數<br/>用命令列覆蓋 config"]
    MAIN --> M3["載入條件清單 (YAML)<br/>→ 條件 → pickle 對照表"]
    MAIN --> M4["驗證條件可用性"]
    MAIN --> M5["建構 DEAP Toolbox<br/>(個體/交配/變異/選擇/多進程)"]
    MAIN --> M6["啟動 GA 演化迴圈"]
    M6 --> RET["回傳最佳策略組合 + 績效指標"]
    RET --> MAIN

    classDef highlight fill:#fff4d6,stroke:#b8860b,stroke-width:2px,color:#5c4500;
    class M5,M6 highlight;
```

---

## 二、GA 演化迴圈

每跑一輪主流程，會執行 **400 代** 演化，每代從 70 個個體中篩選、重組、評分。支援 checkpoint：中斷後可從最近的檢查點恢復。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    START(["進入演化迴圈"]) --> CP{"存在檢查點？"}
    CP -- 是 --> LOAD["載入族群 / 名人堂 / 日誌 / 隨機狀態"]
    CP -- 否 --> INIT["初始化族群 (70 個個體)<br/>名人堂 HallOfFame(1)<br/>logbook + Statistics(avg/min/max)"]
    LOAD --> LOOP
    INIT --> LOOP

    LOOP{"for gen = 1..400"} --> SELECT["錦標賽選擇 tournsize=3<br/>→ 70 個子代"]
    SELECT --> CLONE["複製子代 (避免共享 reference)"]
    CLONE --> CX["兩兩配對<br/>機率 0.5 → 兩點交叉<br/>清除適應度（待重評）"]
    CX --> MUT["對每位子代<br/>機率 0.2 → 翻轉位元 (indpb=0.05)<br/>清除適應度"]
    MUT --> EVAL["篩出無效個體 invalid_ind<br/>交給多進程 Pool(15 cores) 平行評分"]
    EVAL --> EVALFN["呼叫適應度函式<br/>(詳見 §三)"]
    EVALFN --> UPDATE["族群 = 子代<br/>更新名人堂<br/>記錄統計"]
    UPDATE --> CKPT{"每 10 代？"}
    CKPT -- 是 --> SAVE["寫入檢查點 pickle"]
    CKPT -- 否 --> NEXT{"未達 400 代？"}
    SAVE --> NEXT
    NEXT -- 是 --> LOOP
    NEXT -- 否 --> DONE(["演化結束"])

    DONE --> BEST["取名人堂第 1 名<br/>→ 解碼成實際條件組合"]
    BEST --> FINAL["用最佳組合再做一次完整回測<br/>→ 取最終績效指標"]
    FINAL --> RESULT["輸出 JSON:<br/>・最佳條件清單<br/>・績效指標<br/>・總交易次數<br/>・執行時間"]
    RESULT --> CLEAN["刪除檢查點檔案<br/>(下一輪從乾淨狀態重啟)"]

    classDef loop fill:#d6e8ff,stroke:#0050aa,stroke-width:2px,color:#002b66;
    classDef eval fill:#ffd6d6,stroke:#b30000,stroke-width:2px,color:#6b0000;
    class LOOP,SELECT,CLONE,CX,MUT,NEXT loop;
    class EVAL,EVALFN eval;
```

---

## 三、適應度評估（每一個個體都會走這條路）

這是整個系統最關鍵的環節——**把一段二進位編碼轉成「這個策略有多好」的單一分數**，並用 PBO 懲罰避免過擬合。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    E0(["拿到個體編碼 (0/1 list)"]) --> CHK{"未選任一條件？"}
    CHK -- 是 --> F0["return 0.0 (直接淘汰)"]
    CHK -- 否 --> DECODE["依 bit 開啟對應的 pickle<br/>→ 取出條件 DataFrame 清單"]
    DECODE --> COMB["依策略模式 (Compound) AND 組合<br/>→ 合併後的條件 DataFrame"]
    COMB --> DT["轉 DatetimeIndex"]
    DT --> VMODE{"驗證模式"}

    VMODE -- IS_OOS --> SPLIT["按時間切分<br/>內樣本 (前 60%) / 外樣本 (後 40%)"]
    SPLIT --> FIT_IN["compute_fitness(內樣本) → 主要適應度"]
    SPLIT --> FIT_OUT["compute_fitness(外樣本) → 真實績效"]
    SPLIT --> FIT_RND["compute_random_fitness(外樣本)<br/>把條件矩陣打亂當隨機 baseline"]

    VMODE -- CSCV --> CSCV["時間序列交叉驗證 (4 組 split)<br/>每組都跑訓練/測試/隨機 三次"]

    FIT_IN --> ADJ
    FIT_OUT --> ADJ
    FIT_RND --> ADJ
    CSCV --> ADJ

    ADJ["PBO 過擬合懲罰<br/>PBO = 真實策略沒贏過隨機的比例<br/>適應度 = 平均適應度 × (1 − PBO)"]
    ADJ --> RET(["return (調整後適應度,)"])

    classDef branch fill:#ffe0bf,stroke:#b35a00,stroke-width:2px,color:#6b3a00;
    classDef baseline fill:#e0ccff,stroke:#5a2eb8,stroke-width:2px,color:#3a1488;
    class SPLIT,FIT_IN,FIT_OUT branch;
    class FIT_RND,CSCV baseline;
```

### compute_fitness(條件) 內部

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart LR
    A["compute_fitness"] --> B["get_performance_metrics<br/>→ 回測 → 取指標"]
    B --> C{"指標缺失<br/>或交易數 < 200？"}
    C -- 是 --> Z["return 0.0 (流動性不足/過擬合懲罰)"]
    C -- 否 --> D["Score 加權計算<br/>(詳見 §四)"]
    D --> E(["return fitness"])
```

### get_performance_metrics（真正呼叫回測）

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    P0(["拿到條件組合"]) --> P1["呼叫持倉函式 get_position<br/>(回呼入口端，詳見 §五)"]
    P1 --> P2["取得 report 物件"]
    P2 --> P3["總交易數 = report.get_trades() 的長度"]
    P3 --> P4{"交易數 = 0？"}
    P4 -- 是 --> P5["return None, 0"]
    P4 -- 否 --> P6["重試最多 20 次取得 metrics"]
    P6 --> P7(["return metrics, total_trade_count"])
```

---

## 四、適應度加權公式（Score）

採用 **加權平均** 模式：對 10 個績效指標做 min-max 正規化後，以指定權重加總。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    S0(["指標字典 metrics<br/>(profitability / ratio / winrate / risk)"]) --> CALC
    CALC["for 每個子字典中每個指標:<br/>1. min-max 正規化到 [0, 1]<br/>2. 乘上對應權重<br/>3. 累加"]
    CALC --> SUM(["return 加權總和 = fitness"])
```

| 指標 | 權重 | 正規化範圍 | 類別 |
|---|---|---|---|
| 年化報酬率 annualReturn | 0.1 | [0, 1] | 獲利能力 |
| Sharpe Ratio | 0.1 | [0, 100] | 風險調整 |
| Sortino Ratio | 0.1 | [0, 100] | 風險調整 |
| **Calmar Ratio** | **0.6** | [0, 100] | 風險調整 |
| **最大回撤 maxDrawdown** | **0.6** | [-1, 0] | 風險 |
| Value at Risk (VaR) | 0.1 | [-1, 0] | 風險 |
| Conditional VaR (CVaR) | 0.1 | [-1, 0] | 風險 |
| 勝率 winRate | 0.1 | [0, 1] | 交易品質 |
| MAE (最大不利偏移) | 0.1 | — | 交易品質 |
| MFE (最大有利偏移) | 0.1 | — | 交易品質 |

> 權重設計哲學：**重壓風險控管**——Calmar Ratio（年化報酬/最大回撤）與最大回撤本身的權重同為 0.6，其餘指標各 0.1。意思是「在風險可控下追求報酬」優先於「純追求高報酬」。

---

## 五、持倉函式邏輯（get_position）

這是策略端的核心：把 GA 搜出的條件組合，結合 **YoY 營收成長率** 當加權，轉成實際部位後回測。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    G0(["拿到條件組合 (DataFrame)"]) --> G1["複製條件矩陣"]
    G1 --> G2["AND 流動性門檻<br/>日成交額 > 1,500 萬"]
    G2 --> G3["取出 YoY 因子<br/>monthly_revenue:去年同月增減(%)"]
    G3 --> G4["取出月營收時序<br/>monthly_revenue:當月營收"]
    G4 --> G5["條件矩陣 × YoY%<br/>🔑 用營收年增率加權篩選結果"]
    G5 --> G6["保留正值 → 每日取 YoY 前 10 大"]
    G6 --> G7["對齊月營收日期 + 前向填補<br/>(月底訊號持有至下個月)"]
    G7 --> G8["送進 finlab 回測引擎<br/>report = sim(cond_all)"]
    G8 --> G9(["return report"])

    classDef finlab fill:#cfeecf,stroke:#226622,stroke-width:2px,color:#1f4a1f;
    class G2,G3,G4,G5,G6,G7,G8 finlab;
```

### 持倉選股的邏輯順序

1. **流動性過濾** — 排除日均成交額不足 1500 萬的個股（避免滑點與流動性陷阱）
2. **條件組合 AND** — GA 挑出的 4–8 個條件須同時成立
3. **YoY 加權** — 把布林條件乘上「去年同期營收增減 %」，等於用營收動能為通過條件的個股排序
4. **Top 10 選股** — 每個時間點只持有 YoY 最強的 10 檔
5. **月頻持有** — 訊號以月營收日期為基準，月底換倉

---

## 六、核心參數一覽

| 參數 | 值 | 意義 |
|---|---|---|
| 策略模式 | `Compound_Conditions` | 條件 AND 組合 |
| 特徵數範圍 | 4–8 | 每個個體挑選的條件數 |
| 族群大小 | 70 | 每代 70 個個體 |
| 交叉機率 | 0.5 | 兩點交叉 |
| 變異機率 | 0.2 | 翻轉位元 (indpb=0.05) |
| 演化代數 | 400 | 收斂世代上限 |
| 平行核心 | 15 | 多進程 Pool 大小 |
| 最小交易數 | 200 | 低於則視為無效策略 |
| 評分模式 | weighted | 加權平均 |
| 驗證模式 | IS_OOS | 60/40 內外樣本 |

---

## 七、技術棧

| 領域 | 套件 |
|---|---|
| 遺傳演算法框架 | **DEAP** (Distributed Evolutionary Algorithms in Python) |
| 台股量化回測 | **FinLab** (`data.get` 取因子、`sim` 回測引擎) |
| 平行運算 | Python `multiprocessing.Pool` |
| 時間序列切分 | `sklearn.model_selection.TimeSeriesSplit` |
| 資料處理 | `pandas`, `numpy` |
| 序列化 | `pickle` (檢查點與條件快取) |
| 配置 | `YAML` (條件清單來源) |

---

## 八、如何在 IDE 完整呈現 Mermaid 流程圖

這份文件中的所有流程圖使用 **Mermaid 語法**，已內嵌「淺底深字」主題變數，**相容於亮／暗 IDE 主題**，不需另外調整配色。要在 IDE 看到渲染結果，依使用的 IDE 安裝對應套件：

### VS Code / Cursor（最推薦）

在延伸模組市集搜尋並安裝**任一**即可：

| 套件 | Publisher | 說明 |
|---|---|---|
| **Markdown Preview Mermaid Support** | *Matt Biilmann* | 最主流、最穩定，安裝後直接用 `Ctrl+Shift+V` 預覽 Markdown 就會渲染 |
| **Markdown Mermaid** | *Brian Koh* | 整合更完整，支援匯出 PNG/SVG |
| **Mermaid Markdown Syntax Highlighting** | *NETRON* | 額外提供語法高亮（可與上面任一搭配） |

**操作**：打開 `.md` 檔 → `Ctrl+Shift+V`（Mac: `Cmd+Shift+V`）開啟預覽 → 流程圖會自動渲染。

> 若想所見即所得（邊打字邊渲染）：安裝上面任一擴充後，再加裝 **Markdown All in One**（*yzhang*）。

### JetBrains 家族（PyCharm / IntelliJ / DataGrip）

**新版 (2023.1 之後) 內建支援**，無需額外安裝：

1. `Settings` → `Languages & Frameworks` → `Markdown`
2. 勾選 **"Render Mermaid diagrams in preview"**
3. 開啟 Markdown 檔後，右上角切換到 **Preview** 或 **Split** 模式即可

**舊版** 需在 Plugins 市集搜尋 *Markdown* plugin 並升級至內建版本。

### GitHub / GitLab

**原生支援**，把 `.md` push 上去後直接在網頁上看到渲染結果，**不需安裝任何套件**。

### Obsidian / Notion / HackMD

**原生支援**，把整份內容貼進去即會渲染。適合用來當面試時的展示媒介。

### 瀏覽器直接看（免安裝）

把整份 `.md` 內容貼到以下任一線上工具即可：
- **Mermaid Live Editor**：https://mermaid.live
- **GitHub Gist**：貼成 `.md` gist 直接渲染

---

## 九、附錄：Mermaid 渲染驗證

如果你的 IDE 流程圖顯示空白或出現語法錯誤，先做這兩件事：

1. **確認副檔名為 `.md`**（不是 `.txt`、`.markdown`）
2. **貼到 [mermaid.live](https://mermaid.live) 驗證語法**：能渲染就代表 IDE 端問題；不能渲染代表語法錯（這份文件已通過驗證）。
