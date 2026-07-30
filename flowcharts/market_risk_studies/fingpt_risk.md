# FinGPT 恐慌指數環境監控 — 流程圖

> 履歷用途：以流程圖呈現 FinGPT 輿情如何從「cnyes 新聞爬蟲 → LLM 推論 → 截面 Z-score → expanding percentile → Pack C 狀態驗證 → n8n 每日釋出 → 儀表板」的完整鏈路。本模組是市場風險平台 `auxiliary_signal/` 軸下的 **環境描述器（overlay）**——**不預測漲跌方向**，只描述當下市場恐慌程度，供下游客層（獨立策略、 dashboard、Discord 通知）做為 regime 條件使用。

> 父架構見 [`../market_risk.md`](../market_risk.md) §二「Pack C · auxiliary_signal」。本圖為 Pack C 底下其中一個獨立研究專案。

---

## 一、模組定位

| 項目 | 內容 |
|---|---|
| **研究問題** | 把 FinGPT 輿情情緒分數轉成 [0, 1] 的「恐慌百分位」，描述當下市場恐慌環境 |
| **議題角色** | **overlay**（環境描述，非主策略訊號），禁止宣稱 P(up) / P(down) |
| **資料資產** | `/data_g/warehouse/fingpt_stock_sentiment/_market/` — **12 年** parquet（2015 ~ 2026-07-09，~2900 檔股票，~290 萬筆）|
| **生產指標** | `panic_index_rank`（expanding window 分位數版本，`min_periods=60`）|
| **驗證主軸** | Pack C auxiliary：`state_icc`（η²）／`state_spearman`（|ρ|）／`quantile_separation` |
| **目標狀態變數** | TAIEX 20d rvol、OTC 20d rvol、TAIEX 5d MDD、OTC 5d MDD（雙市場對照）|
| **每日排程** | n8n「FinGPT Daily Update」22:30 TST（Asia/Taipei）|
| **入口 Notebook** | `notebooks/risk_dashboard.ipynb`（Restart + Run All ✅）|

---

## 二、整體資料鏈（cnyes → LLM → warehouse → indicator → dashboard）

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart LR
    classDef source fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef model fill:#ffe1e1,stroke:#7a0000,stroke-width:2px,color:#7a0000
    classDef warehouse fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef indicator fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef consumer fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    NEWS["cnyes 新聞清單<br/>FinLab tw_news_cnyes"]:::source
    BODY["新聞正文爬蟲<br/>NewsScraper"]:::source
    RAW["fingpt_news_raw<br/>/warehouse/_market/{year}.parquet"]:::warehouse
    LLM["Llama-3-8B-Instruct<br/>+ FinGPT LoRA 8-bit<br/>( NousResearch / FinGPT )"]:::model
    SENT["fingpt_stock_sentiment<br/>12 年 ~2900 檔<br/>欄位: date / stock_id /<br/>sentiment_score / url"]:::warehouse
    IND["FinGPTRiskIndicator<br/>4 sub-indicators<br/>→ panic_index_rank"]:::indicator
    DASH["risk_dashboard.ipynb<br/>+ results/ui/<br/>latest_assessment.json"]:::consumer
    N8N["n8n Daily Update<br/>22:30 TST cron"]:::consumer

    NEWS --> BODY --> RAW --> LLM --> SENT --> IND
    IND --> DASH
    N8N -. "-> SENT ingest" .-> SENT
    N8N -. "-> UI snapshot" .-> DASH

    class NEWS,BODY source
    class LLM model
    class RAW,SENT warehouse
    class IND indicator
    class DASH,N8N consumer
```

**寫入設計重點**

- `WarehouseWriter.append()`（`tools/pipeline/warehouse_writer.py:67`）走 atomic write + DuckDB `MetadataStore.update_catalog`（`:114`），按年分檔
- `dedup_keys = [date, stock_id, url]`（`config.py:19`）—— 同一篇新聞被重複爬不會重複寫
- `explode_sentiment_records`（`transforms.py:71`）把一篇多股新聞展開為多個 (date, stock_id) 列，**1 新聞 → N 列**

---

## 三、Ingest 與 LLM 推論 Pipeline

> 從 cnyes 清單拉到 LLM 推論寫入 `fingpt_stock_sentiment`。模型 ID 與 batch size **寫死在 config.py**，不走 env var。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef source fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef model fill:#ffe1e1,stroke:#7a0000,stroke-width:2px,color:#7a0000
    classDef warehouse fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef decision fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef loop fill:#d6e8ff,stroke:#002b66,stroke-width:1.5px,color:#002b66

    INGEST["scripts/ingest_news.py:50<br/>finlab.data.get('tw_news_cnyes')"]:::source
    SCRAPE["NewsScraper<br/>tools/pipeline/scraper.py<br/>抓 cnyes 正文"]:::source
    WRITER["WarehouseWriter.append()<br/>tools/pipeline/warehouse_writer.py:67<br/>→ atomic year-file"]:::warehouse
    RAW[("/data_g/warehouse/<br/>fingpt_news_raw/_market/{year}.parquet")]:::warehouse
    INFER["scripts/run_inference.py:31<br/>讀 RAW → 推論 → 寫 SENT"]:::model
    LLM["MODEL_ID = NousResearch/<br/>Meta-Llama-3-8B-Instruct<br/>LORA_ID = FinGPT/<br/>fingpt-mt_llama3-8b_lora<br/>BATCH=16 (config.py:11-13)"]:::model
    EXPLODE["explode_sentiment_records<br/>transforms.py:71<br/>1 新聞 → N (stock_id) 列"]:::model
    DEDUP["dedup_keys =<br/>[date, stock_id, url]"]:::decision
    SENT[("/data_g/warehouse/<br/>fingpt_stock_sentiment/_market<br/>12 年 ~2900 檔")]:::warehouse

    INGEST --> SCRAPE --> WRITER --> RAW
    RAW --> INFER --> LLM --> EXPLODE --> DEDUP --> SENT

    class INGEST,SCRAPE source
    class INFER,LLM,EXPLODE model
    class WRITER,RAW,SENT warehouse
    class DEDUP decision
```

**面試亮點**

- **回推 12 年**：`fingpt_stock_sentiment` 從 2015 開始，~2900 檔股票 → 不是只有近期資料
- **FinGPT LoRA**：用 Llama-3-8B 為底，加 8-bit LoRA（FinGPT 預訓權重），GPU batch=16，**沒有依賴商用 API**（OpenAI / Anthropic）
- **欄位最小化**：sentiment 推論後只保留 `date / stock_id / sentiment_score / url` 4 欄，把敘述丟掉以壓縮 parquet 體積

---

## 四、指標計算（4 sub-indicators → panic_index_rank）

> 從 `fingpt_stock_sentiment` 寬表（pivot + cross-sectional Z-score）出發，並聯算 4 個子指標，再各自取 expanding percentile → 最終 `panic_index_rank`。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef input fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef transform fill:#e1f5e1,stroke:#145a14,stroke-width:1.5px,color:#145a14
    classDef sub fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef combine fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef output fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    SENT["read_fingpt_data<br/>tools/read_fingpt_data.py:90"]:::input
    WIDE["convert_to_wide_format<br/>tools/read_fingpt_data.py:122<br/>pivot_table + aggfunc=mean"]:::transform
    Z["cross_sectional Z<br/>fingpt_risk_indicator.py:97<br/>(x-μ_daily)/σ_daily"]:::transform

    subgraph SUB4["4 sub-indicators 並聯計算（tools/fingpt_risk_indicator.py）"]
        direction LR
        P["panic_index<br/>(:110)<br/>#{Z<-1.5} / N"]:::sub
        V["sentiment_volatility<br/>(:141)<br/>rolling(5).std"]:::sub
        A["anomaly_count<br/>(:173)<br/>#{|Z|>2.0}"]:::sub
        T["sentiment_trend<br/>(:199)<br/>5d linreg slope"]:::sub
    end

    GET["get_time_series()<br/>:683<br/>合併 4 條為 DataFrame"]:::combine
    RANK["calculate_quantile_ranks<br/>(min_periods=60)<br/>fingpt_risk_indicator.py:489-554"]:::combine
    OUT["panic_index_rank<br/>volatility_rank<br/>anomaly_count_rank<br/>trend_rank<br/>(全部 [0,1] expanding percentile)"]:::output

    SENT --> WIDE --> Z --> SUB4 --> GET --> RANK --> OUT

    class SENT input
    class WIDE,Z transform
    class P,V,A,T sub
    class GET,RANK combine
    class OUT output
```

**`calculate_quantile_ranks` 核心迴圈**（`:531`）

```python
for i in range(len(series)):
    if i < min_periods:                # min_periods=60
        ranked_df[f'{col}_rank'].iloc[i] = np.nan
        continue
    historical = series.iloc[:i+1].dropna()
    current_value = series.iloc[i]
    rank = (historical <= current_value).sum() / historical.notna().sum()
    ranked_df[f'{col}_rank'].iloc[i] = rank
```

- **`min_periods=60`** 是啟動門檻——前 60 天不產出 rank，這也是 `results/ui/history.csv` 從 2024-11-13 起算的真正原因（不是 LLM 部署日期）
- **lookback-only**：`historical.iloc[:i+1]` 只往過去看，**沒有未來洩漏（no lookahead bias）**

---

## 五、Pack C 驗證閘門（auxiliary_signal 評估契約）

> Pack C 不允許「方向預測」的 IC / IR 評估，改用「狀態相關性 + 覆蓋率」3+3 門檻。任一 state variable 通過主決策 → KEEP；全部失守 → DISCARD。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef input fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef state fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef primary fill:#ffe1e1,stroke:#7a0000,stroke-width:2px,color:#7a0000
    classDef guard fill:#fff4d6,stroke:#5c4500,stroke-width:1.5px,color:#5c4500
    classDef decision fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00

    IND["panic_index_rank<br/>(候選訊號)"]:::input

    subgraph STATE["4 個目標狀態變數（load_state_variables :79）"]
        direction LR
        SV1["taiex_rvol_20d<br/>rolling(20).std"]:::state
        SV2["otc_rvol_20d"]:::state
        SV3["taiex_dd_5d<br/>rolling_max_dd(ret,5)"]:::state
        SV4["otc_dd_5d"]:::state
    end

    OOS["OOS window<br/>2024-11-13 ~ 2024-12-31<br/>(50 天強制)<br/>≥ 2025-01-01 = 禁觸 hold-out"]:::decision

    subgraph PRIMARY["3 主決策（任 1 state var 通過 → primary_pass）"]
        direction LR
        ICC["state_icc = η²<br/>4 分位切 + compute_eta_squared<br/>門檻: ≥ 0.05"]:::primary
        RHO["state_spearman<br/>spearmanr()<br/>門檻: |ρ|>0.3 且 p<0.01"]:::primary
        QS["quantile_separation<br/>= Q4 mean − Q1 mean<br/>門檻: > 0"]:::primary
    end

    subgraph GUARD["3 守門（防呆用，可獨立 fail）"]
        direction LR
        SF["sign_flip_ratio<br/>(window=15)<br/>門檻: ≤ 5%"]:::guard
        LAG["lag1_autocorr<br/>門檻: ∈ [0.55, 0.85]"]:::guard
        EXT["extreme_pct<br/>rank≥0.9 比例<br/>門檻: ∈ [1%, 20%]"]:::guard
    end

    DECIDE{"任一 state var<br/>primary_pass?"}:::decision
    KEEP(("KEEP")):::primary
    DISCARD(("DISCARD")):::guard

    IND --> STATE
    STATE --> OOS
    OOS --> PRIMARY
    OOS --> GUARD
    PRIMARY --> DECIDE
    DECIDE -- "Yes" --> KEEP
    DECIDE -- "No" --> DISCARD

    class IND input
    class SV1,SV2,SV3,SV4 state
    class OOS,DECIDE decision
    class ICC,RHO,QS primary
    class SF,LAG,EXT guard
    class KEEP primary
    class DISCARD guard
```

**面試亮點 — 為何 Pack C 不看方向 IC**

| Pack | 評估本質 | 為何如此 |
|---|---|---|
| A · top_risk | P(down) 方向預測 → IC / IR | 預測下跌機率，方向是主訊號 |
| **C · auxiliary_signal** | **狀態相關性 η² + 同期 ρ** | **只是 regime 描述，不應宣稱漲跌預測力**；用 IC 會誤導下游 |

---

## 六、n8n 每日生產排程（22:30 TST）

> Cron trigger → Caddy gateway API → jupyter container subprocess → GPU 防呆 → UI snapshot → Discord 通知。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef schedule fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef api fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef guard fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef process fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef output fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488
    classDef error fill:#ffe1e1,stroke:#7a0000,stroke-width:2px,color:#7a0000

    CRON["n8n Schedule Trigger<br/>FinGPT_Daily_Update.json<br/>cron: 30 22 * * *<br/>(Asia/Taipei)"]:::schedule
    POST["trigger-update node<br/>POST /api/warehouse/update-fingpt<br/>?lookback_days=3"]:::api
    GUARD["main.py:1002-1014<br/>pgrep -f run_daily_update /<br/>run_backfill / run_inference /<br/>ingest_news"]:::guard
    SKIP{"GPU 已在跑?"}:::guard
    SKIPSND["Discord: Skipped Notification<br/>→ DISCORD_BULK_DOWNLOAD_WEBHOOK"]:::error
    RUN["main.py:995<br/>warehouse_update_fingpt()<br/>subprocess: run_daily_update.py<br/>--lookback-days 3"]:::process
    LOG["/tmp/fingpt_daily_update.log<br/>marker: 'daily update ok' /<br/>'daily update failed'"]:::process
    UI["main.py:365<br/>/api/fingpt_risk/run_daily<br/>python -m fingpt_risk.scripts.export_ui_snapshot"]:::process
    SNAPSHOT["market_risk_common.ui_export<br/>write_ui_snapshot (schema v2)<br/>→ results/ui/latest_assessment.json<br/>→ results/ui/history.csv"]:::output
    DISC["Build Discord Message node<br/>→ webhook"]:::output

    CRON --> POST --> GUARD --> SKIP
    SKIP -- "Yes" --> SKIPSND
    SKIP -- "No" --> RUN --> LOG
    LOG --> UI --> SNAPSHOT
    SNAPSHOT --> DISC

    class CRON schedule
    class POST,UI api
    class GUARD,SKIP guard
    class RUN,LOG process
    class SNAPSHOT,DISC output
    class SKIPSND error
```

**面試亮點**

- **GPU 防呆**：用 `pgrep -f` 同時檢查 4 個衝突 process（`run_daily_update / run_backfill / run_inference / ingest_news`），避免 LLM 推論疊加 OOM
- **Atomic UI snapshot**：`market_risk_common.ui_export.write_ui_snapshot` 走 schema_version=2 atomic write，下游 dashboard 不會讀到半成品
- **狀態查詢**：`GET /api/warehouse/fingpt-status`（`main.py:1048`）從 log 末行判定 `result=ok|error|unknown`——不需 DB

---

## 七、兩次 Pivot 故事（誠實修正紀錄）

> 2026-07-14 跟 2026-07-15 連續兩天因為實測結果與 README 宣稱不一致而做出**主動 pivot + README 修正**——是面試時展示「誠實揭露 vs 行銷包裝」差異的最佳案例。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart LR
    classDef baseline fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef pivot fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef fix fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef lesson fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    subgraph P1["2026-07-14 · 軸 Pivot"]
        direction TB
        BEFORE1["原軸: top_risk/<br/>宣稱 P(down) 預測<br/>README IC=0.0360 IR=0.3134"]:::baseline
        TEST1["實測 OOS<br/>IC=0.0296  IR=0.2599<br/>(退化 -18% / -17%)"]:::pivot
        DECIDE1{"方向預測力<br/>不夠強？"}:::pivot
        ACT1["決議改軸<br/>top_risk/ → auxiliary_signal/<br/>從 P(down) 改為環境描述器"]:::fix
        CODE1["code impact:<br/>1. validate_risk_indicator.py 保留為歷史<br/>2. 新增 validate_auxiliary_signal.py<br/>3. 新增 versions/v0_aux_pivot/{README,replicate.py}<br/>4. risk_dashboard.ipynb:24-53 殘留舊表"]:::lesson
        BEFORE1 --> TEST1 --> DECIDE1 --> ACT1 --> CODE1
    end

    subgraph P2["2026-07-15 · README 修正"]
        direction TB
        BEFORE2["原 README §⚠️ Sibling Rerun Pending:<br/>'FinGPT 模型 2024 部署 /<br/>無法往前補資料 /<br/>OOS 50 天 / 永久 pending'"]:::baseline
        FIND["實際查 warehouse:<br/>fingpt_stock_sentiment/_market/<br/>2015 ~ 2026-07-09<br/>12 年 ~2900 檔 ~290 萬筆"]:::pivot
        DECIDE2{"README 寫錯了？"}:::pivot
        ACT2["README 全面改寫<br/>(line 20-30 標示 '修正')<br/>列出 4141 天 panic_index_rank<br/>IS:2015-2022 / OOS:2023-2024 / Hold:2025+"]:::fix
        LIMIT["真正限制: expanding(min_periods=60)<br/>啟動門檻 → history.csv 起點 2024-11-13<br/>(不是物理上限)<br/>子議題 fingpt_panic_rebound 已重跑全歷史"]:::lesson
        BEFORE2 --> FIND --> DECIDE2 --> ACT2 --> LIMIT
    end

    class BEFORE1,BEFORE2 baseline
    class TEST1,DECIDE1,FIND,DECIDE2 pivot
    class ACT1,ACT2 fix
    class CODE1,LIMIT lesson
```

**面試必講重點**

| 日期 | 觸發 | 行動 | 展示的特質 |
|---|---|---|---|
| **2026-07-14** | 實測 IC/IR 退化 17-18% | **主動降格**（從方向預測改為環境描述）| 不為了表面好看而護航失效假設 |
| **2026-07-15** | 發現 README 與 warehouse 事實不符 | **公開修正** + 明確列出物理上限 vs 啟動門檻的差異 | 區分「物理不可能」與「契約選擇」的習慣 |

---

## 八、IDE 與套件顯示指南

本文件全部使用 **Mermaid `flowchart` 語法**，建議安裝下列任一套件以正確渲染：

| IDE / 平台 | 推薦套件 | 安裝指令 |
|---|---|---|
| **VS Code** | Markdown Preview Mermaid Support | `ext install bierner.markdown-mermaid` |
| **VS Code** | Markdown Preview Enhanced | `ext install shd101wyy.markdown-preview-enhanced` |
| **Cursor** | 同 VS Code（沿用 marketplace）| 同上 |
| **JetBrains（DataGrip / PyCharm）**| Markdown 外掛（內建）| Settings → Plugins → Markdown → 啟用 Mermaid |
| **GitHub Web** | 原生支援 | 無需安裝 |
| **GitLab Web** | 原生支援 | 無需安裝 |
| **Obsidian** | 內建 Mermaid | 設定 → Markdown → 啟用 Mermaid |
| **CLI 預覽** | `mermaid-cli` | `npm i -g @mermaid-js/mermaid-cli`<br/>`mmdc -i fingpt_risk.md -o out.svg` |

**配色規範**（與本 repo 其他 flowchart 一致）

- 統一使用 `%%{init}%%` 主題：`primaryColor:#ececec`、`primaryTextColor:#1a1a1a`、`lineColor:#444444`
- classDef 全部補 `color:`（淺底深字，避免白底白字）
- 配色語意：
  - 🔵 藍（source / state）：資料源、狀態變數
  - 🔴 紅（model / primary）：LLM 推論、主決策指標
  - 🟡 黃（warehouse / guard / baseline）：快取、守門、原始狀態
  - 🟢 綠（indicator / process / fix）：計算、流程、修正
  - 🟠 橘（decision / pivot）：分支判斷、Pivot 動作
  - 🟣 紫（consumer / output / lesson）：下游消費、最終輸出、學到的事

---

## 九、程式碼索引（面試時可快速跳轉）

| 角色 | 路徑（host 視角） |
|---|---|
| 🎯 模組入口 README | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/README.md` |
| 🎯 軸契約（禁止方向預測）| `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/AGENTS.md` |
| 🔍 主指標類 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/tools/fingpt_risk_indicator.py` |
| 🔍 資料載入 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/tools/read_fingpt_data.py` |
| 🔍 Pipeline config（模型 ID）| `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/tools/pipeline/config.py` |
| 🔍 Warehouse 寫入 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/tools/pipeline/warehouse_writer.py` |
| 🔍 推論腳本 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/scripts/run_inference.py` |
| 🔍 Ingest 腳本 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/scripts/ingest_news.py` |
| 📓 Dashboard notebook | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/notebooks/risk_dashboard.ipynb` |
| 📓 Pack C 驗證 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/analysis/validate_auxiliary_signal.py` |
| 📓 v0_aux_pivot 復現 | `Plutus/market-risk/analyses/auxiliary_signal/fingpt_risk/versions/v0_aux_pivot/replicate.py` |
| 🐳 n8n workflow | `Plutus/services/n8n/workflows/FinGPT_Daily_Update.json` |
| 🐳 API endpoint | `Plutus/infrastructure/jupyter/api/main.py`（`/api/warehouse/update-fingpt` L995、`/api/fingpt_risk/run_daily` L365、`/api/warehouse/fingpt-status` L1048）|
| 🐳 共用 UI snapshot | `Plutus/market-risk/src/market_risk_common/ui_export.py` |
| 🐳 Discord sender | `Plutus/infrastructure/jupyter/scripts/risk/discord_sender.py` |
