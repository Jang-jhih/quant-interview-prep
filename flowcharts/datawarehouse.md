# 多源金融資料倉儲系統

## 專案概述

一個支援 **8 種資料源（含韓股 KRX）、百萬級歷史 K 線**的統一金融資料倉儲，設計核心是「**資料完整性優先於一切**」——任何下載、補檔、寫入操作都必須通過嚴格的缺口審計與多源校驗。

### 為什麼需要這套系統？

量化研究裡「**錯的資料比沒有資料更可怕**」。一個缺失的法人買超記錄、一個被去重邏輯吃掉的同日多類別列，會讓下游的籌碼因子分析直接得出錯誤結論，而且這種錯誤**不會拋例外**——它只會靜默讓你的回測績效看起來很漂亮，直到實盤爆炸。

本系統圍繞三個核心問題設計：

1. **多源資料怎麼統一？** 用「**資料源路由 + 水位線 + Redis ZSET 任務佇列**」——每個資料源有獨立 loader、獨立 schema、獨立審計工具，但透過統一的 SmartLoader 介面暴露給研究端。
2. **資料怎麼不缺？** 用「**Watermark + Gap Calculator + 自動補缺**」——每次查詢都會比對水位線，發現缺口會自動生成補任務丟進佇列；每天跑審計腳本確認無缺口。
3. **並發下載怎麼不撞？** 用「**Redis ZSET 全域任務佇列 + Lock Manager + Rate Limiter**」——百萬級任務用掃描窗批次拉取，避免熱門資料源被自身 API 限流。

### 支援資料源

| 資料源 | 用途 | 配額 / 限制 |
|---|---|---|
| **FinMind** | 台股 / 美股 / 期權主力 | Sponsor Pro, 20,000 req/hr |
| **FinLab** | 台股基本面 + FinLab US 美股公司資料 | 付費帳戶（無限制） |
| **yfinance** | 美股股價 + 深度基本面 | 53 API |
| **Binance** | 加密貨幣 OHLCV（前 10 大幣） | 2,400 weight/min（獨立配額） |
| **Macro 群組** | FRED / EIA 總經與原油、CFTC 期貨持倉、**US Congress 議員交易**、**CNN Fear & Greed**、crypto F&G、黃金、公債殖利率 | Public |
| **KRX（韓股）** | Pykrx + FinanceDataReader + Naver Finance 三源組合 | 見 §五 |
| **J-Quants** | 日股（**已暫停**） | Registry 保留、無 worker |

> **口徑說明**：`SOURCE_CONFIG`（`bulk_downloader/constants.py`）以「**進程隔離單位**」分 6 組
> （`finmind` / `jquants` / `binance` / `macro` / `yfinance` / `krx`），CFTC、FRED、EIA、Congress、CNN
> 都掛在 `macro` 群組下共用一個限速器。所以「幾種資料源」取決於怎麼數——
> **被追問時答「6 個獨立限速群組、8 個對外資料供應方」**，不要含糊。


> 📖 **讀法**：想快速理解看 **§1.0 白板版**（≤7 個框）；想看細節往下讀。標示 `>` 引言與「地雷 / 講法」的區塊是作者自己的面試準備筆記，**可直接略過**。

---

## 一、整體架構（多源攝取 → 倉儲 → 審計）

### 1.0 白板版（被要求「畫一下倉儲架構」時畫這張）

> 6 個框。口訣：**水位線發現缺口 → 缺口變任務 → daemon 補 → 每日審計確認無缺。**

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart LR
    SRC["8 個資料源<br/>(6 個限速群組)"]
    GAP["Watermark<br/>+ Gap Calculator"]
    Q[("Redis ZSET<br/>任務佇列")]
    D["Bulk Downloader<br/>daemon"]
    WH[("Parquet 倉儲<br/>+ SQLite metadata")]
    AUDIT["每日審計<br/>→ Discord 告警"]

    SRC --> D
    GAP --> Q --> D --> WH
    WH --> GAP
    WH --> AUDIT
    AUDIT -. "發現缺口回填" .-> Q

    classDef src fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500;
    classDef flow fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66;
    classDef store fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488;
    classDef audit fill:#ffd6d6,stroke:#6b0000,stroke-width:2px,color:#6b0000;
    class SRC src;
    class GAP,Q,D flow;
    class WH store;
    class AUDIT audit;
```

### 1.1 細節版

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    subgraph SOURCES["資料源層 (8 個供應方 / 6 個限速群組)"]
        direction LR
        SRC1["FinMind<br/>台股/美股/期權"]
        SRC2["FinLab + FinLab US<br/>台股基本面 / 美股公司"]
        SRC3["yfinance<br/>美股價量"]
        SRC4["Binance<br/>加密貨幣"]
        SRC5["Macro 群組<br/>FRED · EIA · CFTC<br/>Congress · CNN F&G"]
        SRC6["KRX 韓股<br/>Pykrx + FDR + Naver"]
        SRC7["J-Quants<br/>日股 (已暫停)"]
    end

    SOURCES --> LOADERS

    subgraph LOADERS["Loader 層 (每源獨立)"]
        direction TB
        L1["FinMind Loader"]
        L2["FinLab Loader"]
        L3["yfinance Loader"]
        L4["Binance Loader"]
        L5["Macro Loader<br/>(含 CFTC / Congress)"]
        L6["KRX Loader<br/>(三源組合)"]
    end

    LOADERS --> QUEUE

    subgraph QUEUE["任務佇列層"]
        direction TB
        Q1[("Redis ZSET<br/>全域任務佇列")]
        Q2["Watermark Store<br/>記錄每個 entity 最新水位"]
        Q3["Gap Calculator<br/>計算待補任務"]
        Q3 --> Q1
        Q2 --> Q3
    end

    QUEUE --> BULK

    subgraph BULK["Bulk Downloader Daemon"]
        direction TB
        B1["Scheduler<br/>掃描 ZSET 批次任務"]
        B2["Rate Limiter<br/>每源獨立限速"]
        B3["Executor<br/>並發執行"]
        B4["Validator<br/>Schema 驗證"]
        B1 --> B2 --> B3 --> B4
    end

    BULK --> STORE

    subgraph STORE["儲存層"]
        direction LR
        S1[("Warehouse<br/>Parquet (Apache Arrow)")]
        S2[("Metadata DB<br/>SQLite")]
        S3[("Watermark DB<br/>SQLite")]
        S1 -.metadata.-> S2
        S1 -.watermark.-> S3
    end

    STORE --> AUDIT

    subgraph AUDIT["完整性審計層"]
        direction TB
        A1["Unified Audit<br/>多源一致性檢查"]
        A2["Gap Analysis<br/>日期缺口偵測"]
        A3["Data Quality<br/>Schema + 分布"]
        A4["Discord 通知<br/>缺失 / 錯誤告警"]
        A1 --> A4
        A2 --> A4
        A3 --> A4
    end

    STORE --> CONSUMER["下游消費端<br/>(research / evolution-lab / plutus_ui)"]

    classDef highlight fill:#fff4d6,stroke:#b8860b,stroke-width:2px,color:#5c4500;
    classDef loop fill:#d6e8ff,stroke:#0050aa,stroke-width:2px,color:#002b66;
    classDef eval fill:#ffd6d6,stroke:#b30000,stroke-width:2px,color:#6b0000;
    classDef finlab fill:#cfeecf,stroke:#226622,stroke-width:2px,color:#1f4a1f;
    classDef baseline fill:#e0ccff,stroke:#5a2eb8,stroke-width:2px,color:#3a1488;
    classDef branch fill:#ffe0bf,stroke:#b35a00,stroke-width:2px,color:#6b3a00;
    class SOURCES,SRC1,SRC2,SRC3,SRC4,SRC5,SRC6,SRC7 highlight;
    class LOADERS,L1,L2,L3,L4,L5,L6 finlab;
    class QUEUE,Q1,Q2,Q3 loop;
    class BULK,B1,B2,B3,B4 branch;
    class STORE,S1,S2,S3 baseline;
    class AUDIT,A1,A2,A3,A4 eval;
```

---

## 二、Bulk Downloader 工作流（增量下載的核心）

Bulk Downloader 是倉儲的心臟，以 daemon 形式常駐，不斷從 Redis ZSET 拉任務、限速下載、驗證、寫入。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    START(["啟動 bulk_download.py daemon"]) --> INIT["讀取 source_registry<br/>+ 初始化 Rate Limiter"]
    INIT --> SCAN

    subgraph SCAN["批次掃描階段"]
        direction TB
        SC1["從 Redis ZSET 拉一批任務<br/>(--batch-size 10000)"]
        SC2["按 source 分組<br/>(finmind / binance / macro)"]
        SC1 --> SC2
    end

    SCAN --> EXEC

    subgraph EXEC["並發執行階段"]
        direction TB
        EX1["Executor 開 worker pool"]
        EX2{"每個任務"}
        EX2 --> EX3["呼叫對應 Loader<br/>拉 API"]
        EX3 --> EX4{"HTTP 狀態"}
        EX4 -- "200" --> EX5["Validator 驗證 schema"]
        EX4 -- "429 / 5xx" --> EX6["Error Classifier<br/>分類錯誤類型"]
        EX6 --> EX7["可重試？"]
        EX7 -- "是" --> EX8["退避後重排回 ZSET"]
        EX7 -- "否" --> EX9["標記為 error task"]
        EX5 --> EX10{"Schema 正確？"}
        EX10 -- "是" --> EX11["寫入 Parquet + 更新 watermark"]
        EX10 -- "否" --> EX9
    end

    EX11 --> PROG

    subgraph PROG["進度追蹤與通知"]
        direction TB
        PR1["Redis Progress<br/>實時任務狀態"]
        PR2["Update Log<br/>每日執行日誌"]
        PR3["Discord Notifier<br/>完成 / 異常告警"]
        PR1 --> PR2 --> PR3
    end

    PROG --> NEXT{"還有任務？"}
    NEXT -- "是" --> SCAN
    NEXT -- "否" --> SLEEP["等待下個排程<br/>(或 idle)"]
    SLEEP --> SCAN

    classDef loop fill:#d6e8ff,stroke:#0050aa,stroke-width:2px,color:#002b66;
    classDef eval fill:#ffd6d6,stroke:#b30000,stroke-width:2px,color:#6b0000;
    classDef highlight fill:#fff4d6,stroke:#b8860b,stroke-width:2px,color:#5c4500;
    classDef baseline fill:#e0ccff,stroke:#5a2eb8,stroke-width:2px,color:#3a1488;
    classDef branch fill:#ffe0bf,stroke:#b35a00,stroke-width:2px,color:#6b3a00;
    class SCAN,SC1,SC2 loop;
    class EX2,EX3,EX4,EX5,EX6,EX7,EX8,EX9,EX10,EX11 eval;
    class EX1 branch;
    class PR1,PR2,PR3 highlight;
    class NEXT,SLEEP baseline;
```

### 設計亮點

| 設計 | 為什麼這樣做 |
|---|---|
| **掃描窗 10000** | 百萬級 binance 任務會埋住 finmind，必須用大掃描窗輪詢所有源 |
| **Watermark 水位線** | 每個 entity（股票代號 + 資料集）獨立記錄最新時間，增量下載不重複 |
| **ZSET 排序** | 用時間戳當 score，舊任務自動排前面，補缺比新資料優先 |
| **Schema Validator** | API 偶爾會回不完整 JSON，必須在寫入前擋下，避免污染 Parquet |
| **Dedup Key 鐵律** | `全部非 float64 欄 + strike_price`（曾因只用 `(id, date)` 靜默損毀 99% 籌碼資料） |
| **配額安全鐵律** | 見下方——**慢補是常態，不是要修的效能問題** |


---

## 三、SmartLoader 查詢路徑（下游怎麼讀資料）

研究端不直接呼叫 FinMind API，而是透過 SmartLoader 統一介面。它會**自動偵測缺口、觸發補檔、再回傳資料**。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart LR
    RESEARCH["研究端 / 策略端<br/>loader.finmind_stock_daily(...)"] --> SMART

    subgraph SMART["SmartLoader 統一介面"]
        direction TB
        SM1["接收請求<br/>(dataset, entity, date_range)"]
        SM2["Cache Manager<br/>查詢本地快取"]
        SM1 --> SM2
        SM2 --> SM3{"快取命中？"}
    end

    SM3 -- "完整命中" --> RETURN1["直接回傳 DataFrame"]
    SM3 -- "部分命中" --> GAP

    subgraph GAP["缺口偵測與補檔"]
        direction TB
        G1["Gap Calculator<br/>對比 watermark 找缺口"]
        G2["生成補任務<br/>丟入 Redis ZSET"]
        G3["等待 Bulk Downloader 補完<br/>(輪詢 watermark)"]
        G1 --> G2 --> G3
    end

    GAP --> READ

    subgraph READ["從倉儲讀取"]
        direction TB
        R1["DuckDB 查詢 Parquet"]
        R2["欄位對齊 + 型別轉換"]
        R3["寫回 Cache Manager<br/>(命中用)"]
        R1 --> R2 --> R3
    end

    READ --> RETURN2["回傳完整 DataFrame"]

    subgraph PARALLEL["平行：可選 API 直取"]
        direction TB
        P1["Fallback: 呼叫 FinMind API"]
        P2["寫入 Parquet"]
        P3["更新 watermark"]
        P1 --> P2 --> P3
    end

    SMART -.FINMIND_SMART_MODE=false.-> PARALLEL

    RETURN1 --> CONSUMER["研究端拿到資料"]
    RETURN2 --> CONSUMER

    classDef finlab fill:#cfeecf,stroke:#226622,stroke-width:2px,color:#1f4a1f;
    classDef loop fill:#d6e8ff,stroke:#0050aa,stroke-width:2px,color:#002b66;
    classDef highlight fill:#fff4d6,stroke:#b8860b,stroke-width:2px,color:#5c4500;
    classDef baseline fill:#e0ccff,stroke:#5a2eb8,stroke-width:2px,color:#3a1488;
    classDef branch fill:#ffe0bf,stroke:#b35a00,stroke-width:2px,color:#6b3a00;
    class SMART,SM1,SM2,SM3 finlab;
    class GAP,G1,G2,G3 loop;
    class READ,R1,R2,R3 highlight;
    class PARALLEL,P1,P2,P3 branch;
    class RETURN1,RETURN2,CONSUMER baseline;
```

### 雙模式切換

| 環境變數 | 模式 | 行為 |
|---|---|---|
| `FINMIND_SMART_MODE=true` | SmartLoader | 缺口偵測 + 自動補檔 + 倉儲讀取（推薦） |
| `FINMIND_SMART_MODE=false` | CachedDataLoader | 快取優先，miss 時直接打 API + 寫倉儲 |
| `FINMIND_WRITE_TO_WAREHOUSE=true` | 任何模式 | API 呼叫後自動寫入 Parquet |

---

## 四、資料完整性保證機制

> **核心鐵律**：研究與交易決策直接依賴倉儲資料 —— 缺一天、漏一個類別，下游結論就是錯的。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#555555','lineColor':'#555555','secondaryColor':'#e0e0e0','tertiaryColor':'#f0f0f0','fontFamily':'"Noto Sans TC", "Microsoft JhengHei", sans-serif'}}}%%
flowchart TD
    WRITE["任何寫入操作<br/>(下載 / 補檔 / 合併)"] --> LAYER1

    subgraph LAYER1["第一層：寫入時驗證"]
        direction LR
        W1["Schema Validator<br/>型別 + 必填欄位"]
        W2["Dedup Key 鐵律<br/>(全部非 float + strike_price)"]
        W3["Atomic Merge<br/>_merge_and_write"]
    end

    LAYER1 --> LAYER2

    subgraph LAYER2["第二層：每日審計"]
        direction LR
        D1["Unified Audit<br/>(每源獨立執行)"]
        D2["Gap Analysis<br/>(MAX/MIN/日期序列)"]
        D3["Data Quality<br/>(分布 / 極端值)"]
    end

    LAYER2 --> LAYER3

    subgraph LAYER3["第三層：多源交叉校驗"]
        direction LR
        C1["FinMind vs FinLab<br/>同一欄位應一致"]
        C2["Watermark vs Parquet<br/>MAX(date) 應對齊"]
        C3["Redis Queue 殘留<br/>pending/error 歸零"]
    end

    LAYER3 --> VERDICT{"完整性 OK？"}
    VERDICT -- "是" --> CLEAN["✅ 通過"]
    VERDICT -- "否" --> ALERT

    subgraph ALERT["告警與補救"]
        direction TB
        AL1["Discord 通知"]
        AL2["生成補任務丟回 ZSET"]
        AL3["重跑審計直到通過"]
        AL1 --> AL2 --> AL3
    end

    ALERT --> LAYER1

    classDef eval fill:#ffd6d6,stroke:#b30000,stroke-width:2px,color:#6b0000;
    classDef highlight fill:#fff4d6,stroke:#b8860b,stroke-width:2px,color:#5c4500;
    classDef loop fill:#d6e8ff,stroke:#0050aa,stroke-width:2px,color:#002b66;
    classDef baseline fill:#e0ccff,stroke:#5a2eb8,stroke-width:2px,color:#3a1488;
    classDef finlab fill:#cfeecf,stroke:#226622,stroke-width:2px,color:#1f4a1f;
    class LAYER1,W1,W2,W3 eval;
    class LAYER2,D1,D2,D3 highlight;
    class LAYER3,C1,C2,C3 loop;
    class VERDICT,CLEAN baseline;
    class ALERT,AL1,AL2,AL3 finlab;
```

### 已知陷阱與防線

| 陷阱 | 防線 |
|---|---|
| Dedup key 用 `(id, date)` 會把同日多類別列去重成 1 列 | 強制 `全部非 float64 欄 + strike_price`，並有 `test_storage_atomic.py::TestDedupKeyFix` 守門 |
| 百萬級 binance backlog 會埋住 finmind 任務 | 加 `--batch-size 10000` 加大掃描窗，按 source 輪詢 |
| 單次短快照會誤判下載吞吐 | 用 ≥60–90 秒穩態窗口兩點取樣 |
| API 回不完整 JSON | Schema Validator 在寫入前擋下，避免污染 Parquet |

---

## 五、韓股 KRX：三源組合

> **這題被問到時的定位要先講清楚**：不是「破解付費牆」，而是「**KRX 官方 Open API 不提供的欄位，
> 用三個各自合法的公開來源拼出量化需要的覆蓋**」。

KRX（韓國交易所）的完整資料要會員資格，但量化研究需要的三塊各有公開替代路徑：

| 來源 | 拿什麼 | 為什麼用它 |
|---|---|---|
| **FinanceDataReader (FDR)** | 全市場清單 / OHLCV | 套件維護者自行維護 GitHub cache，使用者匿名讀取公開 cache |
| **Naver Finance** | 籌碼面（外資買賣超、外資持股比） | 公開網頁資料，HTML 解析 |
| **pykrx** | 衍生品 28 類別 metadata | KRX Open API 不含衍生品 OHLCV，只能取 metadata |

實際串了 4 支 API：韓股全市場清單（KOSPI / KOSDAQ / KONEX）、投資人買賣超、
外資持股比、衍生品 28 類別 metadata。前兩者每日增量、後兩者整批覆蓋。

> **講法建議**（briefing 也有列為地雷）：強調「用開源 cache 套件 + 公開網頁資料」，
> 不要把「繞過會員牆」講成功勞。被問合規就答：**都是公開端點，沒有帳號共用、沒有反爬對抗，
> 且限速壓到 2 workers / 1800 req-hr 比對方的軟限流更保守。**

---

---

> 本文件的流程圖採 Mermaid 語法，GitHub / GitLab / Obsidian 原生支援；
> VS Code 需安裝 *Markdown Preview Mermaid Support*。
