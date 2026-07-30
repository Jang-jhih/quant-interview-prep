# 面試說明稿（Interview Briefing）

> **用途**：針對 `docs/flowcharts/` 五份架構流程圖，準備面試時口語說明用的稿本。每份流程圖獨立一章，每章包含：
>
> 1. **30 秒電梯簡報** — 一上來怎麼開口
> 2. **架構說明要點** — 講解時的邏輯順序
> 3. **專有名詞對照** — 英文術語 + 白話解釋（面試官聽到要能立刻反應）
> 4. **預期面試問題與回答範本** — 模擬追問
> 5. **地雷與停損** — 不要主動講、被問到要怎麼兜
>
> 配合閱讀：[`SOURCE_MANIFEST.md`](./SOURCE_MANIFEST.md) 列出每份流程圖參考的程式碼路徑。

---

## 一、GA 演化選股策略（ga_yoy_v1）

### 30 秒電梯簡報

> 這是我用**遺傳演算法**自動搜尋台股選股條件組合的專案。我把它設計成：把選股條件編碼成 0/1 染色體，每個個體代表「挑 4 到 8 個條件 AND 在一起」的策略，再用 **DEAP 框架**跑 400 代演化，每代 70 個個體，適應度是 10 個績效指標的加權分數。為了避免過擬合，我做了三件事——**六四分內外樣本驗證**、**YoY 營收加權持倉**讓部位跟基本面連動、以及用 **PBO 機率**懲罰那些「跟隨機策略比起來沒顯著贏」的個體。

### 架構說明要點（按這個順序講）

1. **先講「搜尋什麼」**——條件清單從 YAML 載入，每個個體是 0/1 字串，1 表示選該條件，限制 4~8 個條件 AND 組合（避免選太多或太少）
2. **再講「怎麼評分」**——條件組合轉成持倉（YoY 加權 + 流動性篩選）→ 餵 FinLab `sim()` 回測 → 抽 10 個指標（Sharpe、年化、MDD、勝率、Calmar、索提諾等）→ 加權得到適應度
3. **最後講「怎麼避免過擬合」**——這是核心亮點：
   - **IS/OOS 六四分**：訓練用 60% 資料，剩下 40% 完全沒看過
   - **PBO 機率懲罰**：把個體跟「隨機生成的策略」對賭，如果贏的機率低於門檻，適應度打折
   - **YoY 加權**：避免選股只看技術面，營收年增率高的個股權重加大

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **遺傳演算法 GA** | 模仿生物演化——交配、突變、優勝劣敗——在巨量解中找最佳解 |
| **DEAP** | Python 的演化演算法框架，提供 Toolbox、HallOfFame、Logbook 等元件 |
| **染色體 / 個體 Individual** | 一組候選解。這裡是 0/1 字串，每個位置代表要不要選某個條件 |
| **錦標賽選擇 Tournament Selection** | 從族群隨機抽 k 個，最好的留下來繁殖。`tournsize=3` 表示每次抽 3 個比 |
| **兩點交叉 Two-point Crossover** | 在染色體隨機切兩刀，中段互換 |
| **位元翻轉突變 Bit-flip Mutation** | 每個基因以 `indpb=0.05` 機率翻轉（0 變 1、1 變 0） |
| **適應度 Fitness** | 個體好壞的分數。這裡是 10 指標加權後的單一數值 |
| **名人堂 HallOfFame** | 演化過程中看過的最佳個體保存區，最後回傳這裡的冠軍 |
| **IS / OOS（In-Sample / Out-of-Sample）** | 內樣本/外樣本。訓練/測試切分，避免對訓練資料過擬合 |
| **PBO（Probability of Backtest Overfitting）** | 回測過擬合機率。把策略跟隨機策略對賭，贏的比例低 → 過擬 |
| **YoY（Year-over-Year）** | 年增率。營收 YoY = 今年同期 / 去年同期 - 1 |
| **檢查點 Checkpoint** | 每隔 10 代存一個 pickle，中斷可恢復 |
| **Sharpe / Calmar / Sortino / MDD** | 績效指標：夏普值 / 卡瑪值 / 索提諾值 / 最大回撤 |
| **Logbook** | DEAP 的演化日誌，記錄每代 avg/min/max |

### 預期面試問題

**Q：為什麼選 DEAP 不選 pygad 或自己寫？**
> DEAP 是 Python 演化演算法最有口碑的框架，自帶 multiprocessing 支援——我用 15 個核心並行評分，每代 70 個個體幾秒就跑完。pygad 比較新但社群小，自己寫維護成本高。

**Q：400 代是怎麼決定的？**
> 經驗值 + 收斂觀察。我觀察 logbook 的適應度均值，通常 200 代後變化趨緩，跑到 400 代是為了讓少數 late bloomer 有機會被選到。設太大會浪費算力，太小會沒收斂。

**Q：PBO 怎麼算？會不會太慢？**
> 我們在每代結束後，從名人堂抽樣跟隨機生成的 N 個策略對賭，算贏的比例。N 不用太大（30~50），計算成本可接受。重點不是精確 PBO，而是給個相對排名訊號。

**Q：條件清單怎麼來？會有偏見嗎？**
> 條件來自 FinLab 已發表的選股池 + 我手動整理的常用技術指標。偏見一定有——這是 GA 的本質限制。我用 YoY 加權和流動性篩選稀釋單一條件影響力，並定期更新條件池。

### 地雷

- **不要主動提「這套策略會賺錢」**——這是研究框架，不是賺錢保證
- **被問「目前實盤用了沒」**：回答「框架跑通了，目前用在研究層篩選候選策略，實盤還在評估滑價與手續費影響」
- **被問「GA 會不會過擬合」**：直接承認「會，所以才有 IS/OOS + PBO」，不要否認

---

## 二、LLM 驅動因子自動演化（evolution_lab）

### 30 秒電梯簡報

> 這是我把 **LLM 跟演化演算法結合**，讓 AI 自動寫量化因子的實驗室。我用 **OpenEvolve** 當主引擎——它不是讓 LLM 重新寫整段程式，而是用 **SEARCH/REPLACE Diff** 機制，只改該改的那幾行，這樣 LLM 不會破壞已經能跑的程式碼。我設計了三條賽道：**Alpha 軌挖布林因子**用 IC/ICIR 評分、**Condition 軌優化進場濾網**、**Strategy 軌直接生成完整策略**接到真實回測。為了保持多樣性，我用了 **MAP-Elites 演算法**——把候選因子用兩個維度（特徵 × 品質）分箱，每格只留最好的，確保搜尋覆蓋整個特徵空間。

### 架構說明要點

1. **先講為什麼用 LLM**——傳統 GA 只能組合既有條件，LLM 可以發明新公式
2. **再講 Diff-based 的關鍵**——LLM 寫整段程式容易把可跑的東西搞壞，只改 diff 大幅提升成功率
3. **三軌分工**：
   - Alpha 軌：布林因子池（true/false 訊號），評分用 IC + ICIR + DSR
   - Condition 軌：事件濾網（進場時機），用 T-stat + Hit Rate + Coverage
   - Strategy 軌：完整策略，直接接 FinLab `sim()`，用 Sharpe / Calmar / MDD
4. **MAP-Elites 保多樣性**——避免全部收斂到同一個高 IC 因子

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **OpenEvolve** | Google 工程師開源的 LLM-driven code evolution 框架 |
| **Diff-based Evolution** | 用 SEARCH/REPLACE Diff 改 code，不是重寫整段 |
| **MAP-Elites** | 雙維度分箱保留精英的演化演算法，多樣性高 |
| **Alpha 軌 / Condition 軌 / Strategy 軌** | 三個目的不同的演化賽道——因子 / 濾網 / 策略 |
| **IC（Information Coefficient）** | 因子值跟未來報酬的相關係數，|IC| > 0.03 算有用 |
| **ICIR** | IC 的穩定性（IC 均值 / IC 標準差），越高越穩 |
| **DSR（Deflated Sharpe Ratio）** | 去氣夏普比——把多重比較偏誤扣掉的 Sharpe |
| **T-stat / Hit Rate / Coverage** | 統計顯著 / 命中率 / 覆蓋率 |
| **ShinkaCompat** | 我接的舊評分系統 Shinka 的相容層，給 Alpha 軌用 |
| **布林因子 Boolean Factor** | true/false 訊號，不是連續值 |
| **沙盒執行 Sandboxed Execution** | 候選程式碼在隔離環境跑，掛了不影響主流程 |
| **Side-channel Feedback** | 把失敗的 traceback 餵回 LLM 當下次參考 |
| **SQLite Staging** | 本地暫存結果 |
| **Supabase** | 雲端 PostgreSQL，最終結果上傳處 |
| **Promote CLI** | 把本地結果推到雲端的指令 |

### 預期面試問題

**Q：為什麼不用 GPT 直接寫因子？**
> 直接寫的問題是 LLM 會重新產生整段，把可跑的邏輯搞壞。Diff-based 的優點是 LLM 只改該改的——它看到「這裡 IC 是 0.02，目標 0.05」，就針對那行 SEARCH/REPLACE。成功率從 30% 提升到 70% 以上。

**Q：MAP-Elites 跟一般 GA 差在哪？**
> 一般 GA 收斂到一個最優解就停。MAP-Elites 強制保留每個生態格的最佳——例如「高 IC + 低覆蓋」、「中 IC + 高覆蓋」各留一個，最後我得到一整個帕列托前緣，可以挑適合當下市場狀態的因子。

**Q：LLM 用哪個？成本可控嗎？**
> 主用 GLM-5.2（智譜），單次 prompt 約幾千 token。一天跑 20 代、每代 5 個候選，成本幾塊美元。改用 Diff 之後 token 數比 rewrite 少 80%。

**Q：怎麼驗證 LLM 寫的因子不是過擬合？**
> 三層驗證：1) 因子要在 IS 期間顯著；2) OOS 期間 IC 衰減 < 30%；3) DSR 校正後仍顯著。沒過這三關的因子直接丟棄。

### 地雷

- **不要說「LLM 會取代量化分析師」**——這是工具，不是替代品
- **不要宣稱「自動找到聖杯因子」**——這是搜尋框架，找到的因子還是要人審
- **被問「LLM 寫的因子可解釋嗎」**：誠實說「部分可，LLM 會附 rationale，但有的純數學技巧要事後解讀」

---

## 三、多源金融資料倉儲（datawarehouse）

### 30 秒電梯簡報

> 這是我搭的**金融資料倉儲**，整合了 7 個資料源——FinMind、FinLab、yfinance、Binance、FRED、EIA、CFTC，還有最近整合的韓股 KRX 用 Pykrx + FinanceDataReader + Naver Finance 三源組合，繞過了 KRX 會員牆。設計理念是「**資料完整性優先於一切**」——我搭了一套 **Redis ZSET 全域任務佇列**，每次查詢都會比對水位線發現缺口，自動補下載。每天跑審計腳本確認無缺，有問題就發 Discord 告警。百萬級歷史資料全存 Parquet 格式，方便 pandas 直接讀。

### 架構說明要點

1. **先講問題**——「錯的資料比沒資料可怕」，缺一筆法人買超不會拋例外，但會讓下游籌碼因子錯
2. **三層架構**：
   - Loader 層：每個源一個獨立 loader
   - 任務佇列：Redis ZSET 排序任務，Watermark 記水位，Gap Calculator 算缺
   - 儲存層：Parquet 檔 + SQLite metadata + SQLite watermark
3. **完整性保證機制**：
   - Watermark：記每個標的最新下載到哪天
   - Gap Calculator：跟應有日期比對，缺的丟回佇列
   - Bulk Downloader daemon：常駐，從佇列拉任務、限速、驗證、寫入
   - Audit：每日跑，缺漏發 Discord
4. **並發治理**：Rate Limiter 每源獨立限速 + Lock Manager 防同一標的被多 worker 撞

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **資料倉儲 Data Warehouse** | 集中存放多源資料的中央倉庫 |
| **Parquet** | Apache Arrow 的列式儲存格式，pandas 讀很快、壓縮比高 |
| **Redis ZSET（Sorted Set）** | Redis 的有序集合，我用 score 排任務優先順序 |
| **水位線 Watermark** | 每個標的「下載到哪一天」的紀錄 |
| **缺口計算 Gap Calculator** | 比對應有日期跟實際日期，找出缺失 |
| **Bulk Downloader** | 批量下載 daemon，常駐輪詢任務佇列 |
| **Rate Limiter** | 限速器，每個資料源獨立設定，避免被 API 封 |
| **Schema Validator** | 驗證下載回來的欄位結構正確 |
| **Error Classifier** | 把錯誤分類——可重試 / 不可重試 / 限流 |
| **Lock Manager** | 鎖管理器，防止同一標的被多 worker 同時下載 |
| **SmartLoader** | 給下游研究端的統一查詢介面，隱藏各源差異 |
| **FinMind / FinLab / yfinance / Binance / FRED / EIA / CFTC** | 各種資料源——台股 / 美股 / 加密 / 總經 / 期貨持倉 |
| **J-Quants** | 日股資料源（已暫停）|
| **Pykrx / FinanceDataReader / Naver Finance** | 韓股三源組合，繞過 KRX 會員牆 |
| **KOSPI / KOSDAQ / KONEX** | 韓國三個交易市場——主板 / 創業板 / 新興市場 |
| **Embargo** | 禁制期，下載資料時跳過最近 N 天避免資料修訂 |
| **Metadata DB** | SQLite，記錄每個 parquet 的 schema、來源、更新時間 |
| **Discord Notifier** | Discord 通知，缺漏 / 錯誤告警 |

### 預期面試問題

**Q：為什麼用 Parquet 不用 PostgreSQL 或 InfluxDB？**
> 三個原因：1) pandas 原生支援，研究端不用換工具；2) columnar format 對時間序列壓縮比高，磁碟成本低 60%；3) 沒有寫入鎖問題——研究端讀、daemon 寫，parquet 的不可變特性天然避免衝突。代價是即時查詢慢，但我們是批次更新，可接受。

**Q：Redis ZSET 為什麼比 Celery 或 RabbitMQ 好？**
> 我需要的是「任務有優先順序 + 可重排」——緊急補檔的任務 score 高，常規任務 score 低。ZSET 天然支援這個，且 Redis 已經在別處用了，不引入新依賴。Celery 太重，我沒有那麼複雜的工作流需求。

**Q：怎麼處理 API 限流？**
> 兩層：1) Rate Limiter 在 Executor 層用 token bucket，每源獨立設定（FinMind 20,000 req/hr）；2) Error Classifier 識別 429，用指數退避後重排回 ZSET，不是直接放棄。

**Q：韓股 KRX 會員牆怎麼繞過的？**
> 三源分工：FinanceDataReader 的維護者自己登入 KRX 抓資料推 GitHub cache，使用者匿名讀；Naver Finance 用 HTML scraping 拿籌碼面（外資買賣超）；Pykrx 拿衍生品 metadata。組合起來覆蓋韓股 95% 量化需求，零會員摩擦。

**Q：怎麼知道資料是對的？**
> 三層驗證：1) Schema Validator 確認欄位型別；2) 多源交叉比對（同一標的在 FinMind 跟 yfinance 價格差 < 1%）；3) 每日審計腳本跑分布檢查，找出異常值。

### 地雷

- **不要主動說「我繞過了 KRX 會員牆」當功勞**——這是灰色地帶，要講就強調「用開源 cache 套件」
- **被問「資料源 API key 怎麼管理」**：只說「在 .env 用環境變數注入容器」，不要展開講
- **被問「實際資料量」**：說「百萬級歷史 K 線」，不要掰 PB 級

---

## 四、統一 AI 服務編排層（services）

### 30 秒電梯簡報

> 這是我搭的**服務編排層**——上游是 datawarehouse、research、evolution-lab 這些「實作層」，我把它們的能力對外暴露成四種形態：**Hermes 是 AI Agent Runtime**，承載 5 個 agent profile；**n8n 是自動化引擎**，排程、webhook、資料 pipeline 全走這裡；**data-api 是 FastAPI**，把倉儲查詢變 REST endpoint；**plutus_ui 是 Streamlit Portal**，研究產出的視覺化入口。設計理念是「**實作跟暴露分離**」——研究端寫策略不用管 UI，UI 不用懂策略。

### 架構說明要點

1. **先講雙層分工**：
   - 實作層（上游）：datawarehouse / research / evolution-lab / core
   - 暴露層（本層）：hermes / n8n / data-api / plutus_ui
2. **判準**：「需要領域知識才能回答的決策」（Sharpe 門檻、因子篩選）屬實作；「對外暴露的機制」屬暴露
3. **四個子服務**：
   - Hermes 5 profile：ops / steward（管理） → GLM-5.2；librarian / risk / quantix（分析）→ MiniMax M3
   - n8n 39 workflow：Hermes 觸發 19 / 風險評估 15 / 系統 5
   - data-api：9 個 REST router + 5 個 reader + 分級 cache TTL
   - plutus_ui：DW 血緣 / 資料集探索 / 回測模組 / 爬蟲 hub
4. **Hermes Adapter**：FastAPI :18790，把 HTTP `/tools/invoke` 轉 Hermes CLI `chat -q`，給 n8n 用

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **Agent Runtime** | AI Agent 的執行環境 |
| **Hermes** | Nous Research 出的 Agent 框架，這裡指本平台的 runtime |
| **Profile** | Agent 的角色設定檔（SOUL.md + AGENTS.md） |
| **SOUL.md / AGENTS.md** | Hermes profile 的人格設定 / 工具規則 |
| **Adapter / Gateway** | 轉接器——把 HTTP 請求轉 CLI 呼叫 |
| **n8n** | 開源自動化引擎，類似 Zapier 但可自架 |
| **Workflow** | n8n 的工作流，節點連節點 |
| **Webhook** | 事件觸發的 HTTP 回呼 |
| **FastAPI** | Python 的 async web framework，有自動文檔 |
| **REST Router** | RESTful API 路由器，每個路徑對應一個 handler |
| **Reader** | data-api 的資料讀取層，從倉儲撈資料 |
| **Cache TTL（Time-to-Live）** | 快取存活時間，分級——熱資料短 TTL、冷資料長 TTL |
| **Streamlit** | Python 的 data app 框架，免前端 |
| **GLM-5.2 / MiniMax M3** | LLM 模型——編排用 / 輕量分析用 |
| **Model Routing** | 不同任務路由到不同模型，控制成本 |
| **Docker Compose** | 多容器編排工具 |
| **子專案 Subproject** | monorepo 內的獨立子專案 |

### 預期面試問題

**Q：為什麼要分「實作層」跟「暴露層」？**
> 兩個理由：1) 關注點分離——研究端改策略不用動 UI，UI 改 layout 不用碰回測邏輯；2) 部署獨立——Hermes 重啟不影響 datawarehouse，n8n 升級不影響策略。

**Q：Hermes 跟 n8n 怎麼分工？**
> Hermes 是大腦（AI Agent），n8n 是神經（流程編排）。n8n 觸發事件（cron、webhook）→ 透過 adapter 問 Hermes → Hermes 做決策（風險分析、自動報告）→ n8n 接著動作（發 Discord、寫 DB）。Hermes 不主動觸發，n8n 不做 AI 推理。

**Q：5 個 profile 怎麼決定的？**
> 按職責分：ops（系統維運）、steward（總管）、librarian（資料查詢）、risk（風險分析）、quantix（量化研究）。前兩個用便宜的 GLM-5.2（編排為主），後三個用 MiniMax M3（需要 reasoning）。模型分層省成本。

**Q：data-api 跟直接讀 parquet 差在哪？**
> data-api 提供 REST 介面，外部服務（如 n8n workflow）不用懂 parquet 路徑與 schema；統一上 cache 跟 audit log；對外暴露的合約穩定，後端改 schema 不影響呼叫端。

**Q：Streamlit 不會太慢嗎？**
> 對內 Portal 夠用——研究端使用者少。對外公開會換 React + FastAPI，但目前需求沒到。重點是 Streamlit 讓研究端自己寫頁面，不用排前端工程師。

### 地雷

- **不要說「Hermes 是我自己寫的」**——是 Nous Research 的開源框架，我只做整合
- **被問「GLM-5.2 / MiniMax M3 怎麼選的」**：說「成本跟效果權衡——編排任務不需要大模型，分析任務才上」，不要展開講 PoC 數據
- **被問「服務怎麼部署」**：說「docker-compose 多容器，每個子服務一個 container」，不要展開 k8s 細節（除非真有）

---

## 五、事件型市場風險評估（market_risk）

### 30 秒電梯簡報

> 這是我做的**市場風險評估研究平台**。先講個重點——它**不是傳統 VaR 或 GARCH 那種參數化風險模型**，而是用**事件研究法**：我定義「未來 20 天內曾經跌超過 10%」這種事件 label，然後尋找能預測這類事件的訊號，用嚴格的統計驗證確認訊號不是運氣。整個平台分成**訊號發明層**跟**獨立策略層**兩層，搭配四種 Pack 評估契約——A/B/C 在訊號層（預測下跌 / 反彈 / 狀態），D 在策略層（完整交易）。為了避免前視偏差跟假顯著，我搭了一套統計驗證基礎設施——purged walk-forward、block bootstrap、FDR 校正。

### 架構說明要點

1. **先強調「不是 VaR」**——很多面試官會誤以為是傳統風險模型，要先導正
2. **兩層四 Pack**：
   - 訊號發明層：Pack A（top_risk 預測下跌）/ B（bottom_dip 預測反彈）/ C（auxiliary_signal 狀態）
   - 獨立策略層：Pack D（完整交易）
3. **Label 工程**：
   - 路徑型 MAE（Maximum Adverse Excursion）——未來 h 天曾經最深跌到哪
   - 嚴重度階梯——跌 5% / 10% / 12% 各算一次，看 RR 是否單調放大
   - 尾端 h 日強制 NaN——「未知」跟「未發生」要分開
4. **統計驗證四組工具**：
   - Purged walk-forward：訓練資料不能偷看測試期，label 重疊要挖掉
   - Episode cluster + n_eff：事件擠在幾波行情裡，不是幾天
   - Block bootstrap：以「波」為單位重抽
   - Fisher + BH-FDR：檢定 + 多重比較校正
5. **ETH/TWII 範例**：PIVOT 結論——檢力失敗（樣本不足）但方向不隨機

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **VaR（Value at Risk）** | 傳統風險指標——某信心水準下最大虧損。**本平台不是這套** |
| **CVaR / Expected Shortfall** | VaR 的尾巴版本——超過 VaR 的期望虧損 |
| **GARCH** | 波動度模型——本平台**沒用** |
| **Event Study 事件研究法** | 觀察事件前後的異常報酬，本平台的核心方法 |
| **CAPM-adjusted AR** | 用 CAPM 模型算「正常報酬」，實際減正常 = 異常 |
| **CAR（Cumulative Abnormal Return）** | 累積異常報酬 |
| **MAE（Maximum Adverse Excursion）** | 持有期間最大不利偏移——盤中曾經最深跌到哪 |
| **MFE（Maximum Favourable Excursion）** | 最大有利偏移——曾經最高漲到哪 |
| **路徑型 Label Path-type Label** | 看「未來 h 天的路徑」，不是「第 h 天的點」 |
| **嚴重度階梯 Severity Ladder** | 不同跌幅門檻（-3% / -5% / -8%）各算一次 |
| **Pack A / B / C / D** | 四種評估契約——下跌預測 / 反彈預測 / 狀態 / 完整策略 |
| **top_risk / bottom_dip / auxiliary_signal** | 三種研究軸——下跌 / 反彈 / 狀態 |
| **Trigger 軸** | 訊號的本質方向（不可反轉）|
| **Purged Walk-forward** | 滾動 forward 驗證 + purge 挖空重疊 |
| **Embargo** | 訓練跟測試之間的禁制期，等於 label horizon |
| **Episode Cluster** | 把事件依照「屬於哪一波行情」分群 |
| **n_eff（Effective Observations）** | 有效獨立觀測數——重疊報酬會讓 n 虛高 |
| **Block Bootstrap** | 區塊拔靴法——以「波」為單位重抽 |
| **Fisher Exact Test** | 費雪精確檢定——小樣本顯著性檢定 |
| **BH-FDR（False Discovery Rate）** | Benjamini-Hochberg 偽發現率校正 |
| **Probability Lift** | 訊號亮燈時事件率 − baseline 事件率 |
| **PIVOT** | 研究結論——轉軸停止。**注意：不是訊號無效，是樣本不足以統計顯著** |
| **檢力 Power** | 統計檢定能偵測真實效果的機率 |
| **TAIEX / OTC** | 台灣上市 / 上櫃兩個市場 |
| **Total Return Index 報酬指數** | 還原除權息的指數，跟「價格指數」不同 |
| **Overlay** | 訊號當「參考」而不是主決策——人工減碼參考 |
| **Gate（門檻）** | 多階段驗證的關卡——樣本數、方向一致、顯著性 |

### 預期面試問題

**Q：為什麼不用 VaR？**
> VaR 回答的是「常態下最大虧損」，但台股最大的風險是**尾部事件**——崩盤。VaR 對崩盤沒輒（CVaR 好一點但仍是分布假設）。我用事件研究法直接建模「崩盤事件」本身，不假設分布。重點是：VaR 給你「平常日的數字」，我給你「崩盤日的預警」。

**Q：怎麼避免前視偏差 Lookahead Bias？**
> 三道防線：1) Label 計算層（path_labels.py）是唯一允許用 shift(-N) 的地方，其他模組嚴禁；2) Label 計算後尾端 h 天強制 NaN，不補 0——避免下游當成「沒跌」；3) Walk-forward 切分時 embargo = label horizon，訓練段最後 h 天挖掉，防止 label 跟測試重疊。

**Q：PIVOT 是什麼意思？訊號無效嗎？**
> **檢力失敗（power failure），不是證據失敗**。意思是「樣本數不夠到統計顯著」，不是「訊號沒用」。ETH/TWII 議題事件數天花板 35 次，p 值差一點，但嚴重度階梯單調放大（跌 5% → RR 1.79×、跌 10% → 3.32×、跌 12% → 3.87×），方向不隨機。所以保留為人工減碼 overlay 參考，不安裝為自動交易訊號。

**Q：兩層（訊號發明 / 獨立策略）為什麼分開？**
> 兩個本質不同：訊號發明只問「這個 trigger 有沒有預測力」，輸出一條 P(down) 序列；策略層自己決定部位、方向、進出場，把訊號當輸入。混在一起的話——把預測訊號直接當交易訊號——會忽略成本、滑價、流動性，回測漂亮實盤崩盤。

**Q：Block Bootstrap 跟一般 Bootstrap 差在哪？**
> 一般 Bootstrap 假設樣本獨立，但金融事件不是——35 個崩盤事件可能擠在 3 波行情裡，每波 10 個事件高度相關。一般 Bootstrap 會把相關樣本當獨立，p 值樂觀上界。Block Bootstrap 以「波」為單位重抽，把相關性保留在區塊內，p 值才可信。

**Q：FDR 校正是什麼？為什麼必要？**
> 我同時測多個訊號，每個都做顯著檢定。單一檢定 p < 0.05 表示 5% 偽陽率，但 20 個訊號一起測，預期有 1 個偽陽性「顯著」。FDR（False Discovery Rate）校正控制「宣稱顯著的訊號中偽發現的比例」，避免被多重比較偏誤騙。

### 地雷

- **不要主動講「PIVOT 等於失敗」**——是檢力失敗，要區分清楚
- **不要宣稱「訊號能預測崩盤」**——是「在特定嚴重度下有方向性」，不是預測
- **被問「實盤用了沒」**：誠實說「目前是 overlay 參考，不是自動交易訊號」
- **被問「ETH 跟台股為什麼相關」**：說「流動性傳導假設——ETH 對全球流動性敏感，台股也受外資影響。但這個假設的因果沒被證實，所以 PIVOT」，不要過度解讀
- **不要把 path_labels.py 的 shift(-N) 當 bug 講**——這是 label 白名單，唯一允許的例外

---

## 共通問答（跨主題）

**Q：這些是你一個人做的嗎？**
> 個人研究專案，全程自架。AI 工具（Claude Code、OpenCode）協助產生程式碼與審查，但架構決策、方法論選擇、bug 處理自己來。

**Q：哪個專案最難？**
> market_risk——金融統計的細節多（lookahead、n_eff、FDR），錯一個地方整個結論翻盤。其次是 datawarehouse，並發跟資料完整性問題很多。

**Q：你怎麼驗證這些系統是對的？**
> 三層：1) 單元測試（pytest）；2) Notebook Restart + Run All 確認可重現；3) 人工審計——抽樣跟外部資料源比對（例如跟 FinLab 網頁對指數收盤價）。

**Q：怎麼管理這麼多子專案？**
> monorepo + 子專案獨立 CLAUDE.md + taskmaster 任務追蹤 + progress.md 進度日誌。每個子專案有獨立嚴格度——research / market-risk 嚴格（影響交易決策），工具層寬鬆。

**Q：用 AI 寫 code 不會有問題嗎？**
> 會。我搭了一套審查流程——每個 PR 用 AI subagents 跑 bug review、標準審查、架構審查三組平行，未通過不合併。AI 寫的 code 一定要人審，不能盲信。

---

## 面試前最後準備 checklist

- [ ] 每份流程圖在 IDE（VS Code + Markdown Preview Mermaid Support）能正確渲染
- [ ] 反覆練習每個 30 秒電梯簡報——錄音聽一次，超過 35 移要剪
- [ ] 專有名詞對照表至少讀過 3 遍，重點術語（MAP-Elites / PBO / MAE / Block Bootstrap / FDR / PIVOT）要能即時白話解
- [ ] 預期問題的反應要演練——找人模擬面試，被追問地雷題
- [ ] 準備 1~2 個具體數字強化記憶點（例：n_eff 35 / RR 3.87× / 400 代 / 70 個體）
- [ ] 帶筆電可以現場開流程圖檔，被問細節直接展示
