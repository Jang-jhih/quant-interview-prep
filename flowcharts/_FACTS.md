# 數字 SSOT（Single Source of Truth）

> **用途**：本 repo 所有**可機械驗證的數字**都以本檔為唯一來源。
> 其他文件引用數字時應與此對齊；發現不一致時**以本檔 + 驗證指令的實查結果為準**。
>
> **為什麼要這份檔**：2026-07-30 的全面複查發現，多數矛盾都源於「同一個數字寫在 5 個檔案」
> ——n8n workflow 數（39 vs 48）、evolution LLM（DeepSeek vs GLM-5.2 vs 實際 MiniMax-M3）、
> plutus_ui 技術（Streamlit vs Next.js）都漂移過。集中管理 + 腳本驗證是唯一可靠的解。
>
> **驗證**：跑 `scripts/check_facts.sh`（需能存取 `/home/user/Desktop/Plutus`）。
>
> **最後核對**：2026-07-30

---

## 一、服務層（services）

| 項目 | 值 | 驗證指令 / 來源 |
|---|---|---|
| n8n workflow 總數 | **48** | `find services/n8n/workflows -name '*.json' \| wc -l` |
| — `workflows/hermes/` | 25 | `find services/n8n/workflows/hermes -name '*.json' \| wc -l` |
| — `workflows/risk/` | 18 | 同上換路徑 |
| — `workflows/system/` | 4 | 同上換路徑 |
| — 根層單檔 | 1（`FinGPT_Daily_Update.json`） | `find services/n8n/workflows -maxdepth 1 -name '*.json'` |
| data-api 已註冊 router | **9** | `grep -c include_router services/data-api/app/main.py` |
| — 清單 | `health` `dw` `research` `evolution` `risk` `commentary` `active_etf` `passive_etf` `breadth` | `app/main.py:62-70` |
| — 未註冊的 router 檔 | `etf_bh_metrics.py`（存在但未 include）| `ls app/routers/` 對照 main.py |
| — 共用 prefix | `commentary` 與 `research` 都掛 `/api/research` | `app/main.py:64,67` |
| data-api readers | **5**：`warehouse_breadth` `etf_snapshots` `risk_snapshots` `breadth_snapshots` `ai_commentary` | `ls services/data-api/app/readers/` |
| Hermes 業務 profile | **5**：`ops` `steward` `librarian` `risk` `quantix` | `services/hermes/config.yaml`（`agent.personalities`） |
| Hermes 排程角色（不計入 5） | `orchestrator`、`researcher`（kanban dispatcher） | `config.yaml:50-61` |
| Hermes 全域預設模型 | **MiniMax-M3**（provider `minimax`） | `config.yaml:26-30` |
| Hermes 429 fallback | **glm-4.5** | `config.yaml:36-39` |
| Hermes 維運 profile 覆寫 | **glm-5.2**（zai provider，1M context，2026-07-03 切換，`ZAI_API_KEY`） | `services/hermes/README.md:107` |
| Hermes Adapter port | **18790**（FastAPI，`/tools/invoke` → CLI `chat -q`） | `services/hermes/gateway-adapter/` |
| plutus_ui 前端 | **Next.js 16.2 + React 19.2**（唯一前端，ADR-003） | `plutus_ui/web/package.json` |
| plutus_ui 兩個 app | `web/`（內網，走 data-api）／`web-public/`（對外，Supabase build 時預取） | `plutus_ui/CLAUDE.md` |
| 對外站禁上架路由 | `/ops` `/evolution` `/research-lab` `/quantix` `/chat` `/dw` | `plutus_ui/CLAUDE.md` |

> ⚠️ **Streamlit 已完全汰除**，僅存在於歷史 ADR 與 docs。任何文件寫「Streamlit Portal」都是過期資訊。

---

## 二、資料倉儲（datawarehouse）

| 項目 | 值 | 驗證指令 / 來源 |
|---|---|---|
| **限速群組數** | **6** | `SOURCE_CONFIG` keys（`bulk_downloader/constants.py:99`） |
| — 群組清單 | `finmind` `jquants` `binance` `macro` `yfinance` `krx` | 同上 |
| **對外供應方數** | **8**（FinMind / FinLab(+US) / yfinance / Binance / Macro 群組 / KRX / J-Quants） | `datawarehouse/CLAUDE.md:40` |
| `macro` 群組包含 | FRED · EIA · CFTC · US Congress · CNN F&G · crypto F&G · 黃金 · 公債殖利率 · 原油 | `constants.py:115-131`（prefixes） |
| FinMind 配額 | Sponsor Pro，**20,000 req/hr**，4 workers | `constants.py:100-104` |
| Binance 配額 | 2,400 weight/min（獨立配額），4 workers | `constants.py:110-114` |
| KRX 限速 | **1,800 req/hr、2 workers**（Naver 軟限流 ~2 req/s，刻意保守） | `constants.py:137-141` |
| J-Quants | **已暫停**（registry 保留、無 worker、無 workflow） | `CLAUDE.md:40,117` |
| IP ban 冷卻 | **2100 秒 = 35 分鐘**（FinMind ban 30 分 + 5 分緩衝） | `constants.py:97` |
| 掃描窗 | `--batch-size 10000` | `datawarehouse.md` §二 |
| KRX API 支數 | **4**：`krx_universe` `krx_investor_trend` `krx_foreign_ownership` `krx_future_universe` | `registry.py:1704-1738`（`_PHASE12_KRX_APIS`） |
| KRX 三源 | FinanceDataReader（公開 GitHub cache）／Naver Finance（HTML）／pykrx（衍生品 metadata） | `registry.py:1701`、ADR-013 |
| 資料量級 | **百萬級歷史 K 線** | ⚠️ **不要說 PB 級**（舊版誤述，已修正） |
| 進程管理 | supervisord `worker-{finmind,binance,yfinance,macro}`，`--daemon --max-runtime 86400` + autorestart | ADR-012 / `CLAUDE.md:113` |
| n8n 對倉儲的角色 | **enqueue-only**（`POST /api/warehouse/update?source=X`） | `CLAUDE.md:114` |

---

## 三、因子演化實驗室（evolution-lab）

| 項目 | 值 | 驗證指令 / 來源 |
|---|---|---|
| **LLM 模型** | **MiniMax-M3** | `openevolve/financial_evolution/src/configs/boolean_factor_config.yaml:20,30,43` |
| LLM 三個角色 | 主力生成（低溫）／高溫探索／評估回饋 | 同上 L16-56 |
| API base | `https://api.minimax.io/v1`（OpenAI 相容）+ `MINIMAX_API_KEY` | 同上 L22,55-56 |
| 三軌配置路徑 | `openevolve/financial_evolution/configs/modes/{alpha,condition,strategy}/*.yaml` | ⚠️ **不是** `evolution-lab/configs/` |
| Diff 格式 | SEARCH/REPLACE（token 降 **80–90%**） | `evolution_lab.md` §二 |
| `experiment_id` 分組 | 1-6 Alpha ／ 7 Condition ／ 8 Strategy | `evolution_lab.md` §六 |
| 演化結果出口 | `plutus_ui/web/` 的 `/evolution` 路由（唯讀） | ⚠️ **不是** 「Streamlit Page 6」 |

> ⚠️ **不要說 DeepSeek 或 GLM-5.2**——那兩個都是舊稿的錯誤。GLM 是 Hermes 維運 profile 用的。

---

## 四、GA 選股（example_universe_selection）

| 項目 | 值 | 來源 |
|---|---|---|
| 族群大小 | **70** | `ga_yoy_v1.ipynb` cell 3 `population_size` |
| 演化代數 | **400** | `ngen` |
| 並行核心 | **15** | `num_cores` |
| 交叉 / 變異機率 | 0.5 / 0.2（`indpb=0.05`） | `crossover_prob` / `mutation_prob` |
| 特徵數範圍 | **4–8** | `min_num_features` / `max_num_features` |
| 最小交易數 | **200** | `min_total_trade_count` |
| 驗證模式 | `IS_OOS`（60/40） | `validation_mode` |
| 評分模式 | `weighted`，10 指標 | `socre_mode` / `weights` |
| 權重（重壓風險） | Calmar **0.6**、maxDrawdown **0.6**，其餘 8 項各 0.1 | `weights` dict |
| 流動性門檻 | 日成交額 > **15,000,000** | `get_position()` |
| 持股數 | `is_largest(10)` → 每期 10 檔 | `get_position()` |
| **引擎位置** | `Finlab_/jupyter/strategy/pakage/GA_v3/`（`main.py` `evaluate.py` `score.py` `validation.py`） | ⚠️ notebook 只有 **3 個 cell**，引擎不在裡面 |

---

## 五、市場風險平台（market-risk）

### 5.1 框架

| 項目 | 值 | 來源 |
|---|---|---|
| 評估契約 | **Pack A / B / C / D 四類** | `market-risk/CLAUDE.md:598` |
| 研究方法 | **六類**（⚠️ 不同維度，別跟四 Pack 混） | `CLAUDE.md:543` |
| 預設嚴重度階梯 | **−3% / −5% / −8%** | `path_labels.py:33 DEFAULT_SEVERITY_THRESHOLDS` |
| `path_labels.py` 函式 | `mae_depth` `mae_label` `mfe_label` `severity_ladder` | `grep '^def ' path_labels.py` |
| `validation.py` 函式 | `purged_walk_forward` `episode_ids` `n_eff` `episode_block_bootstrap` `probability_lift` `fisher_lift_test` `bh_fdr` | `grep '^def ' validation.py` |
| BH-FDR 預設 q | **0.1** | `validation.py:276` |
| `auxiliary_signal/` 子模組 | **7** | `ls market-risk/analyses/auxiliary_signal/ \| wc -l` |
| 前視偏差偵測 | `core/package/data_leakage_detection/`：`check_future_data_leakage`（`detector.py:45`）+ `_create_patched_get` / `_create_patched_indicator` | 上線前**必跑**（`CLAUDE.md:302`） |

### 5.2 Pack A · ETH/TWII

| 項目 | 值 |
|---|---|
| 判定 | **PIVOT**（`physical ceiling concluded`，2026-07-20）— 檢力失敗非證據失敗 |
| **全歷史獨立事件數** | **35**（物理天花板） |
| **OOS 獨立事件數** | **4**（2023-01 ~ 2024-12，2 年 / 481 交易日） |
| ⚠️ 口徑 | **35 不是 `n_eff`**。35 是全歷史上限；檢力不足的原因是 OOS 只有 4 個獨立事件 |
| 嚴重度階梯（RR） | −5% → **1.79×**；−7% → **2.36×**；−10% → **3.32×**；−12% → **3.87×**（單調） |
| `probability_lift` 95% CI | **[-0.0005, +0.3443]**（下界仍微幅低於 0） |
| 訊號起點 | 2017-11-09（ETH-USD 上市日 = 物理上限） |
| 實戰回測 | ⚠️ **未跑 vectorbt**（判 PIVOT 止步於 gate） |
| 正當用法 | 人工減碼 overlay 警示（`intensity > 0.20`），不安裝為自動交易訊號 |

### 5.3 Pack B · fingpt_panic_rebound ★ 唯一雙 KEEP

| 項目 | 值 |
|---|---|
| Canonical 訊號 | `panic_index_rank > 0.85 AND market_drawdown < -0.05`，horizon **5d** |
| IS（2015-2022，8 年 / 1958 交易日） | **n=69**，5d `prob_lift` **+13.32%**，`mag_lift` **+24 bps** → KEEP |
| OOS（2023-2024，2 年 / 481 交易日） | **n=13** → KEEP（**sealed final-only**） |
| Hold-out | 2025-01-01 ~ **永久禁觸** |
| Walk-forward | **4/4** KEEP（2015-17 n=26 / 2018-19 n=9 / **2020 COVID n=10 雙 KEEP** / 2022 n=22） |
| Crisis events | **3/4** KEEP（2020 n=8 / 2022 n=22 / 2018 n=6；2015 China 樣本不足不宣稱） |
| 參數穩健 | **25 個變體全部雙 KEEP**（panic_th 0.65~0.90 × dd_th −0.03~−0.10） |
| 假設成績 | H3 **25/30** 雙 KEEP ／ H2 **0/25** OOS KEEP（IS-only）／ H1 **3/25**（僅 0.93-0.96） |
| 100 iterations 總計 | IS KEEP **74/91** ／ OOS KEEP **36/91** ／ **雙 KEEP 35/91** |
| 測試 | **61 passed 全綠**（13 + 23 export_ui_snapshot + 25 paper_trading） |
| Paper trading | **10 筆 OOS trades**，持有 10 日 sweet spot；⚠️ **不含手續費 / 稅 / 滑價** |
| 資料 | `data/fingpt_panic_rank_full_history.csv`（**4141 天**） |

### 5.4 Pack C · fingpt_risk

| 項目 | 值 |
|---|---|
| 判定 | 降格為 **overlay**（2026-07-14 從 `top_risk/` pivot 到 `auxiliary_signal/`） |
| warehouse 範圍 | **2015 ~ 2026-07-09、12 年、~2900 檔**（每年 17-32 萬 rows） |
| panic rank 天數 | **4141 天**（IS 2015-2022 / OOS 2023-2024 / Hold-out 2025+） |
| 表面退化數字 | 實測 IC **0.0296** / IR **0.2599** vs README IC 0.0360 / IR 0.3134 |
| ⚠️ 真正結論 | **90% 屬 baseline drift 而非訊號崩壞**（0.0296 是「50 天 OOS + 18 個月 hold-out」混合基準） |
| ⚠️ 真正降格理由 | **軸契約要求 OOS ≥ 1 年，當時只有 50 天** → 結構上無法滿足 |
| `min_periods` | **60**（expanding percentile 啟動門檻，**不是**物理上限） |
| `history.csv` 起點 | 2024-11-13（= 啟動門檻 + 發佈時間） |
| 4 個子指標 | `panic_index`（Z<−1.5 佔比）／`sentiment_volatility`（rolling5 std）／`anomaly_count`（\|Z\|>2）／`sentiment_trend`（5d 斜率） |
| Pack C 主決策門檻 | `state_icc` ≥ **0.05** ／ `state_spearman` \|ρ\|>**0.3** 且 p<**0.01** ／ `quantile_separation` > **0** |
| 守門門檻 | `sign_flip_ratio` ≤ **5%**（window=15）／`lag1_autocorr` ∈ **[0.55, 0.85]**／`extreme_pct` ∈ **[1%, 20%]** |
| 模型 | `NousResearch/Meta-Llama-3-8B-Instruct` + `FinGPT/fingpt-mt_llama3-8b_lora`，8-bit，BATCH=16 | 
| n8n 排程 | cron `30 22 * * *` Asia/Taipei ＋ `pgrep` 4 process GPU 防呆 |
| ⚠️ 測試 | **3 個 pytest 失敗 + 17 skipped**（`KNOWN_ISSUES.md`，pre-existing 技術債） |

### 5.5 Pack C · industry_rotation_risk

| 項目 | 值 |
|---|---|
| 判定 | **v1 baseline LOCK**（2026-07-01 起未換） |
| 分類 | cmoney **37 集團 / 248 檔**（`CMONEY_GROUP='集團股'`，`cmoney_data.py:51`） |
| 分類 A/B test | 從 FinLab 46 產業改 cmoney 37 集團，external icc 提升 **2.9×** |
| autoresearch | **12 輪：1 KEEP（v1）+ 11 DISCARD** |
| **實際 gate**（`autoresearch_v2.py`） | `state_icc` ≥ **0.30** ／ `sign_flip_ratio` ≤ **0.05** ／ `lag1_autocorr` ∈ **[0.55, 0.85]** ／ `extreme_4_5_pct` ∈ **[0.01, 0.20]** ／ `switch_per_Q` ≤ **12** |
| **KEEP 規則** | `gate_pass >= 3` **AND** `state_icc_ge_0.30`（icc 為必要條件） |
| ⚠️ README 舊門檻 | README 寫 `sign_flip ≤30%` / `lag1 ∈ [0.40, 0.85]` → **過期，以程式碼為準** |
| v1 指標 | `state_icc`=**0.3585**、`switch_per_Q`=**22.62**（超標但 KEEP 規則允許） |
| ⚠️ circular trap | v1 的 0.3585 是用 `theme_strength` 當 state_var 算的（公式含 `theme_raw`）→ **外部 `twii_vol` 重算僅 0.038** |
| ⚠️ 立場 | **12 輪都用同一個 circular 指標** → 相對排序有效、**絕對值不可信** |
| Pareto 邊界 | v8 cooldown=1：icc **0.31** ✅ / switch **15.58** ❌；v9 cooldown=2：icc **0.26** ❌ / switch **11.62** ✅ |
| Z-score 視窗 | `window=252, min_periods=60` |
| 風險分數 | `1 + (z_rot>0.5) + (z_rot>1.5) + (z_theme<-0.5) + (z_theme<-1.5)`，`clip(1,5)` |
| 外部驗證（台股） | **8 指標、n=481**，8/8 跨期同向，最高 ρ=**−0.40**（`above_ma60`），63d 翻號比 0.2%-3.3% |
| 外部驗證（美股） | **11 指標、n=463**，跨期同向 **0/11**；僅 RSP/SPY 20d Cohen's d=**+0.51** |
| 樣本不平衡 | score=1 → 269 天（55.9%）／score=4 → 12 天（2.5%）／score=5 → 3 天（0.6%） |
| 歷史範圍 | 2007-04-23 ~ 2026-07-01 |

### 5.6 Pack D · leverage_guard_overlay

| 項目 | 值 |
|---|---|
| 判定 | **CONDITIONAL**（phase5 hold-out 後） |
| 研究窗 | **2017-11-09 ~ 2024-12-31**（約 7 年；受 ETH-USD 上市日限制） |
| ⚠️ 樣本代價 | **測不到 2008 海嘯與 2011 歐債**（保護價值最大的兩段） |
| 成本口徑 | **5 bps 單邊 + 融資 2%/年** |
| 事前登記 | `plan.md` 跑第一格前 FROZEN；§7 設計變更紀錄**為空** |
| 主規則 | **R3 = E02 或 ETH 任一亮就砍**（phase1 四候選中唯一過事前門檻） |
| phase1 門檻 | 相對 R1，IS 與 OOS **同時**滿足 `mdd_improvement ≥ R1` 且 `net_edge ≥ R1 − 0.5pp` |
| phase1 R0（恆定 2.5x） | IS CAGR 8.5%、IS MDD **−63.7%** |
| phase1 R1（E02 單腿） | IS MDD −40.0%（+23.7pp）、OOS +28.6pp、平均水位 1.68x、空手 33% |
| phase1 R3 ✅ | IS MDD **−29.6%**（**+34.0pp**）、平均水位 1.11x、空手 56%；7/7 年份回撤改善為正，中位數 **+29.2pp** |
| `market_volatility` 加碼腿 | 只改變 **79 / 1742 天（4.5%）** → 記為「接法沒給空間」，非「訊號無效」 |
| phase3 結論 | 沒守門 2.5x 已超上限；有守門 2.5x 偏保守、**3x 有證據支持** |
| phase3 Calmar | 1x **0.50** → 5x **0.42**（**單調遞減**）；5x baseline 17 年 CAGR **−7.1%** |
| phase3 警告 | **固定口數 3x 在 2008 必然爆倉**（8 個最痛單日只罩住 3 個） |
| phase5 期間 | 2025-01-02 ~ 2026-07-27，**377 交易日 / 1.50 年** |
| phase5 市況 | 指數報酬 **+91.1%**、指數最深回撤 −26.7% |
| phase5 R0 | 終值 **3.937x**、CAGR 149.9%、MDD **−56.3%** |
| phase5 R3（主規則） | 終值 **1.894x**、CAGR 53.3%、MDD **−12.1%**、平均水位 0.82x、空手 **67%** |
| phase5 判定依據 | `mdd_improvement` **+44.1pp** ✅（門檻 ≥+5pp）／`net_edge` **−96.7pp** ❌（門檻 ≥−15pp） |
| ⚠️ phase5 R2（ETH 單腿） | 終值 **5.170x**、`net_edge` **+49.9pp**——**表現最好，但非事前選定，不得改選** |
| 亮燈命中 | **八次亮燈只有一次真的躲對** |
| 前置研究（凍結） | `index_futures_derisk` h3：**0/12 KEEP**（保險有效但保費太貴） |
| ⚠️ 雙市場 | **OTC 未涵蓋**，且此單市場例外**尚未核准** |

---

## 六、回測報告（backtest_reports）

| 項目 | 值 |
|---|---|
| 份數 | **17** |
| 年化報酬範圍 | 33.6% ~ **111.4%** |
| Sharpe 範圍 | 1.80 ~ 2.59 |
| MDD 範圍 | −22.2% ~ −34.4% |
| 期間 | 各異，最早 2013-06，統一到 2026-07-30 |
| **已扣成本** | `feeRatio` 0.000314 / 0.000428（2.2 折 / 3 折）＋ `taxRatio` **0.003**（證交稅 0.3%） |
| **未納入** | 滑價、流動性 / 容量、借券與融資成本、漲跌停無法成交 |
| 樣本切分 | ⚠️ **全期回測，無 IS/OOS 切分** |
| ⚠️ 已知資料問題 | `small_cap.html`（小市值）與 `strong_breakout.html`（強勢突圍）**除 title 外資料逐位元一致** → 其中一份設定錯誤，待重跑 |

---

## 七、跨主題口徑速查（最容易講錯的）

| 問題 | ✅ 正確答法 | ❌ 錯誤答法 |
|---|---|---|
| plutus_ui 用什麼？ | Next.js 16 + React 19（ADR-003） | Streamlit |
| n8n 幾個 workflow？ | 目前 48 個 | 39 個 |
| 因子演化用哪個 LLM？ | MiniMax-M3 | DeepSeek / GLM-5.2 |
| 幾個資料源？ | 6 個限速群組、8 個供應方 | 七八個 |
| 資料量級？ | 百萬級歷史 K 線 | PB 級 |
| ETH 議題的 `n_eff`？ | OOS 獨立事件 **4**（35 是全歷史上限） | 35 |
| v1 的 icc 0.36？ | circular，外部重算 0.038 | 直接報 0.36 |
| FinGPT 為何降格？ | 軸契約 OOS 不足 1 年（退化 90% 是 baseline drift） | 訊號退化 17-18% |
| 幾個 Pack？ | 評估契約 **4** 類（研究方法另有六類） | 六類契約 |
| 測試都綠嗎？ | `fingpt_panic_rebound` 全綠；`fingpt_risk` 有 3 個 pre-existing 失敗 | 都是綠的 |
| GA 引擎在哪？ | `Finlab_/jupyter/strategy/pakage/GA_v3/` | notebook 裡 |
| 有實盤嗎？ | 最遠只到 paper trading（10 筆、未扣成本） | 已實盤 / 沒有任何驗證 |
