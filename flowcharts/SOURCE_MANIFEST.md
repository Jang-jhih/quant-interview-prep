# 流程圖目錄與原始碼對照（Source Manifest）

> **用途**：本目錄記錄 `docs/flowcharts/` 下每份流程圖文件實際參考的程式碼路徑，方便追溯每張圖的依據來源。
>
> **路徑標記**：
> - 🏠 host 路徑（`/home/user/Desktop/Plutus/...`）= 你本機看到的路徑
> - 🐳 容器路徑（`/home/work/...`）= jupyter container 內部路徑
> - 兩者映射：`/home/user/Desktop/Plutus/` ↔ `/home/work/`
>
> **角色標記**：
> - 🎯 **主來源**：流程圖核心內容直接取自這裡
> - 📚 **SSOT 規範**：定義方法論、契約、鐵律（被引用但不是程式碼）
> - 🔍 **輔助調查**：用於交叉驗證或補充細節
> - 📓 **議題實例**：具體研究案例，作為流程圖的範例節點

---

## 目錄總覽

| # | 流程圖文件 | 主題 | 子專案根目錄 |
|---|---|---|---|
| 1 | [`example_universe_selection.md`](./example_universe_selection.md) | GA 演化 + YoY 加權選股策略 | `Finlab_/jupyter/strategy/GA/deap/`（Plutus 之外）|
| 2 | [`evolution_lab.md`](./evolution_lab.md) | LLM 驅動因子自動演化實驗室 | `evolution-lab/` |
| 3 | [`datawarehouse.md`](./datawarehouse.md) | 多源金融資料倉儲系統 | `datawarehouse/` |
| 4 | [`services.md`](./services.md) | 統一 AI 服務編排層 | `services/{hermes,n8n,data-api}` + `plutus_ui/` |
| 5 | [`market_risk.md`](./market_risk.md) | 事件型市場風險評估研究平台 | `market-risk/` |

---

## 1. `example_universe_selection.md` — 範例：GA 演化 + YoY 加權選股策略

> 以 DEAP 遺傳演算法搜尋台股複合條件選股策略，YoY 營收加權持倉，IS/OOS 驗證 + PBO 過擬合懲罰。

| 角色 | 路徑 | 內容 |
|---|---|---|
| 🎯 主來源 | 🏠 `/home/user/Desktop/Finlab_/jupyter/strategy/GA/deap/ga_yoy_v1.ipynb` 🐳 `/home/work/strategy/GA/deap/ga_yoy_v1.ipynb` | 整份流程圖的主要參照——DEAP Toolbox 建構、演化迴圈（400 代 × 70 個體）、適應度函式（10 指標加權）、IS/OOS 切分（60/40）、PBO 懲罰、YoY 加權持倉函式、checkpoint 機制全在此 notebook 內 |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Finlab_/jupyter/strategy/GA/deap/` 同層其他 `ga_*.ipynb`（`ga_GVI_v2`、`ga_peg`、`ga_prg`）| 對照同系列 GA 策略變體，確認 DEAP 設定與 config 組裝慣例一致 |
| 📚 框架參考 | `DEAP` 官方文件（外部）| 錦標賽選擇 `tournsize=3`、兩點交叉、位元翻轉變異 `indpb=0.05`、`HallOfFame`、`Logbook`、`Statistics` |
| 📚 框架參考 | `finlab.backtest` `sim()` API | 回測引擎、`Report.stats` 績效指標鍵值 |
| 🔍 歷史追溯 | 上一輪 explore session `ses_050f619dfffeRTcailJCtGYSvN`（background `bg_f9157b51`）| 當初 trace GA 呼叫鏈的調查紀錄 |

---

## 2. `evolution_lab.md` — LLM 驅動量化因子自動演化實驗室

> OpenEvolve（LLM + Diff-based Evolution + MAP-Elites）三軌（Alpha/Condition/Strategy）自動因子發現。

| 角色 | 路徑 | 內容 |
|---|---|---|
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/evolution-lab/CLAUDE.md` 🐳 `/home/work/evolution-lab/CLAUDE.md` | 子專案定位、三軌分工、ShinkaCompat 評分器角色、結果層契約 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/evolution-lab/AGENTS.md` | OpenCode 進入點 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/openevolve/financial_evolution/` 🐳 `/home/work/evolution-lab/openevolve/financial_evolution/` | OpenEvolve 主引擎實作——LLM prompt 組裝、SEARCH/REPLACE Diff、沙盒執行、MAP-Elites 分箱、12 步驟演化迴圈 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/shinka-evolve/` | ShinkaCompat (icir) 評分器——Alpha 軌 IC/ICIR + 去氣夏普比 DSR 計算；含 `factor_metadata.py`、`generate_metadata.py`、`initial.py` |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/configs/modes/{alpha,condition,strategy}/*.yaml` | 三軌配置（quick/standard/full 強度）、`experiment_metadata` 欄位 |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/shared/` | 共用組件（ResultsStore、資料源路由 SSOT、雲端 promote CLI）|
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/openfe/` | OpenFE 替代引擎（`main.py`、`openfe_utils.py`） |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/evolution-lab/examples/`（`sample_alpha_factor.py`、`sample_boolean_factor.py`、`vif_*_example.py`）| 因子樣板與 VIF 共線性檢查範例 |
| 🔍 歷史追溯 | 上一輪 explore session `ses_050d76799ffeySRjGHFutm0oqw`（background `bg_a67f3ea3`）| 當初 trace OpenEvolve financial_evolution loop 的調查紀錄 |
| 🔗 下游消費 | 🏠 `/home/user/Desktop/Plutus/plutus_ui/`（Page 6 因子唯讀瀏覽器）| 演化結果的視覺化出口 |

---

## 3. `datawarehouse.md` — 多源金融資料倉儲系統

> 7 種資料源（含已暫停 J-Quants）+ 韓股 KRX（Phase 12 已整合，流程圖尚未補入），Redis ZSET 任務佇列 + Watermark + Gap Calculator + 嚴格審計。

| 角色 | 路徑 | 內容 |
|---|---|---|
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/datawarehouse/CLAUDE.md` 🐳 `/home/work/datawarehouse/CLAUDE.md` | 子專案定位、資料源分工、嚴格度、完整性保證原則 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/src/bulk_downloader/registry.py` | Source registry——所有 loader/API 註冊與寫入策略（含 `_PHASE12_KRX_APIS` 韓股四 API）|
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/src/bulk_downloader/constants.py` | Source prefix 對照（含 `"krx": {"prefixes": ["krx_"]}`）、首批啟用 API 清單 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/src/bulk_downloader/{scheduler,executor,storage,rate_limiter,watermark_store,id_fetcher,validator,error_classifier,redis_progress,progress,update_log,discord_notifier}.py` | Bulk Downloader daemon 全鏈路實作 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/scripts/bulk_download.py` | daemon 入口 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/src/{smart_loader,gap_calculator,lock_manager,cache_manager,metadata_store,data_loader,api_connector,source_policy,config}.py` | SmartLoader 查詢路徑、缺口計算、鎖管理、metadata DB |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/src/{finmind_schema,finlab_schema,jquants_schema,finlab_registry,congress_loader,cftc_*,jquants_loader}.py` | 各資料源 schema 與 loader |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/scripts/{cftc_download,verify_all_apis,verify_binance_warehouse,generate_incremental_tasks,rebuild_watermark_from_redis,rebuild_finlab_catalog,init_metadata,generate_schemas,cleanup_krx_redo_tasks,reset_krx_for_redownload}.py` | 審計/補檔/重置腳本 |
| 📓 韓股 ADR | 🏠 `/home/user/Desktop/Plutus/datawarehouse/docs/decisions/ADR-013-韓股資料源-Pykrx-整合.md` | 三源組合（Pykrx + FinanceDataReader + Naver Finance）決策紀錄——⚠️ 流程圖尚未補入 KRX 節點 |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/tests/test_scheduler_krx_no_param.py` 等 | KRX 排程器測試（佐證韓股整合已落地）|
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/datawarehouse/docs/ai-context/{progress,technical-debt,project-structure}.md` | 子專案進度日誌與技術債追蹤 |
| 🔗 下游消費 | research / evolution-lab / plutus_ui / market-risk | 倉儲 parquet 唯一合法讀者 |

---

## 4. `services.md` — 統一 AI 服務編排層

> Hermes Agent Runtime（5 profile）+ n8n（39 workflow）+ data-api FastAPI + Streamlit Portal。

| 角色 | 路徑 | 內容 |
|---|---|---|
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/CLAUDE.md`（子專案分層 §能力暴露層）| 雙層架構定義、services 子專案清單 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/services/CLAUDE.md` | 服務層入口規範 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/services/AGENTS.md` | 服務層 OpenCode 進入點 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/hermes/config.yaml` | Hermes 5 個 agent profile 設定——ops / steward / librarian / risk / quantix 的 model 對應（ops/steward→GLM-5.2；librarian/risk/quantix→MiniMax M3）|
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/hermes/gateway-adapter/` | Hermes Adapter（FastAPI :18790），把 HTTP `/tools/invoke` 轉 Hermes CLI `chat -q` |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/hermes/{scripts,docker-compose.yml,CLAUDE.md,README.md}` | Hermes runtime 啟停、健康檢查、profile 維運 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/n8n/scripts/` + 🏠 `/home/user/Desktop/Plutus/services/n8n/data/` | n8n workflow 定義（hermes 19 / risk 15 / system 5 = 39 個）|
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/n8n/{CLAUDE.md,AGENTS.md,docs/}` | n8n 唯一業務自動化定位、workflow 分類規範 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/services/data-api/app/` + `scripts/` | FastAPI 9 個 router（active_etf / breadth / commentary / dw / evolution / research / risk / health）、5 個 reader、分級 cache TTL |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/plutus_ui/`（⚠️ **root 層，不在 services/ 下**） | Streamlit Portal——DW 血緣、資料集探索、回測模組、爬蟲 hub |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/services/poc/` | 證明概念區（非生產）|
| 🔗 上游依賴 | datawarehouse / research / evolution-lab / core（唯讀依賴）| 服務層只暴露，不重新實作 |

---

## 5. `market_risk.md` — 事件型市場風險評估研究平台

> 兩層四 Pack（A/B/C/D）+ 路徑型 Label + Purged Walk-forward + Block Bootstrap + FDR 校正。⚠️ **不是傳統 VaR/GARCH**。

| 角色 | 路徑 | 內容 |
|---|---|---|
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/CLAUDE.md` 🐳 `/home/work/market-risk/CLAUDE.md` | 子專案嚴格度、工作原則 #1–#10、六類評估契約、市場覆蓋規則、文件用途對照表 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/AGENTS.md` | 進入點 + Pre-Flight Checklist + skill 路由 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/.opencode/rules/risk-analysis-workflow.md` | `analyses/` 工作流——六類設計、Lookahead 禁止、版本迭代、抽取門檻 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/.opencode/rules/folder-organization.md` | 兩層資料夾結構、Pack 對應、新任務分類決策樹 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/.opencode/rules/data-source-usage.md` | 資料源治理——warehouse parquet 強制、禁 FinLab API / pickle |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/.opencode/rules/minimum-sample-window.md` | 樣本效度——最小樣本窗、§7 `n_eff` 有效獨立觀測數 |
| 📚 SSOT | 🏠 `/home/user/Desktop/Plutus/market-risk/_research/methodology.md` | HOW-SSOT——方向鎖死、事件 vs 因子分流、研究流程與驗證分級 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/market-risk/src/market_risk_common/path_labels.py` | 路徑型 Label——`mae_depth` / `mae_label` / `mfe_label` / `severity_ladder`、尾端 NaN 約定 |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/market-risk/src/market_risk_common/validation.py` | 統計驗證基礎設施——`purged_walk_forward` / `episode_ids` / `n_eff` / `episode_block_bootstrap` / `probability_lift` / `fisher_lift_test` / `bh_fdr` |
| 🎯 主來源 | 🏠 `/home/user/Desktop/Plutus/market-risk/src/market_risk_common/{otc_index,signal_gate,risk_notebook}.py` | TAIEX/OTC 報酬指數載入、訊號 gate 排序、Plotly 風險監控圖 |
| 📓 議題實例 | 🏠 `/home/user/Desktop/Plutus/market-risk/analyses/top_risk/eth_twii_risk/` 全包（`README.md` + `scripts/{data_loader,indicators,assess,report}.py` + `evaluation/metrics.py` + `versions/h_*/`） | Pack A · top_risk 代表案例——ETH 20 日強度訊號預測 TWII 崩盤，含 PIVOT 結論、嚴重度階梯、雙市場（TAIEX+OTC）驗證 |
| 📓 議題實例 | 🏠 `/home/user/Desktop/Plutus/market-risk/analyses/top_risk/eth_twii_risk/notebooks/eth_twii_20d_risk_drop_estimation_report.md` | §3.3、§4.2 嚴重度階梯與正當用法（intensity > 0.20 overlay 警示）|
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/market-risk/_research/scripts/sector_short/{capm,equity}.py` | CAPM event-study beta、abnormal return、CAGR/Sharpe/Sortino/MDD |
| 🔍 輔助 | 🏠 `/home/user/Desktop/Plutus/market-risk/examples/us_stock_sector_analysis/query_us_stock_sectors.py` | 美股 S&P 500 / Nasdaq-100 產業宇宙查詢（延伸範例）|
| 🔗 下游消費 | 🏠 `/home/user/Desktop/Plutus/market-risk/analyses/leverage_guard_overlay/` 等獨立策略層 | Pack D 策略消費 Pack A/B/C 訊號做 overlay |

---

## 製作方法與追溯性

每份流程圖的產出流程一致：

1. **並行 explore agents** 啟動 2 個 `task(subagent_type="explore")`，分別追蹤「整體結構」與「具體分析/演算法內容」
2. **直接讀 SSOT**——CLAUDE.md、`.opencode/rules/*.md`、AGENTS.md、ADR、`_research/methodology.md`
3. **綜合→寫 Mermaid**——淺底深字配色，每張圖 `%%{init}%%` 主題，附判讀表
4. **追溯 session**——保留 explore subagent session_id 與 background_task_id，可事後 resume 補問

### 已知 gap（尚未補入流程圖）

| 流程圖 | 缺漏 | 已確認於何處 |
|---|---|---|
| `datawarehouse.md` | 韓股 KRX（Pykrx + FDR + Naver Finance 三源組合）尚未畫入 | `datawarehouse/src/bulk_downloader/registry.py:1701-1811`、`constants.py:85-138`、`docs/decisions/ADR-013-韓股資料源-Pykrx-整合.md` |
