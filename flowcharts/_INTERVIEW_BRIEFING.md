# 面試說明稿（Interview Briefing）

> 口語說明用的稿本，章節順序與 [README](../README.md) 一致。每章含：
> **30 秒簡報** → **說明順序** → **專有名詞** → **預期追問** → **地雷**。

| 章 | 主題 | 結論 / 性質 |
|---|---|---|
| 一 | 事件型市場風險評估（總架構） | 方法論主體 |
| **二** | **槓桿守門 Overlay（Pack D）** | **CONDITIONAL** — 紀律最嚴 |
| 三 | FinGPT 恐慌指數（Pack C） | 降格為 overlay |
| **四** | **恐慌抄底訊號（Pack B）** | ✅ **IS+OOS 雙 KEEP** |
| 五 | 產業輪動風險（Pack C） | v1 LOCK |
| 六 | LLM 因子自動演化 | 研究框架 |
| 七 | GA 選股策略 | 研究框架，未實盤 |
| 八 | AI 服務編排層 | 生產運行 |
| 九 | 多源資料倉儲 | 生產運行 |
| 十 | 策略回測報告（17 份） | 研究層候選篩選 |

> **只有 10 分鐘就講二 + 四**——一個「紀律最嚴」，一個「真的過了」。其餘是背景鋪陳。

---

## 一、事件型市場風險評估（總架構）

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
| **n_eff（Effective Observations）** | 有效獨立觀測數——重疊報酬會讓 n 虛高。⚠️ ETH 議題：全歷史事件上限 **35**、OOS 獨立事件 **4**；**35 不是 n_eff** |
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
> **檢力失敗（power failure），不是證據失敗**。意思是「樣本數不夠到統計顯著」，不是「訊號沒用」。
> ETH/TWII 議題**全歷史獨立事件天花板 35 次**，而 **OOS 兩年期間只有 4 個獨立事件**——
> 這才是檢力不足的真正原因。嚴重度階梯單調放大（−5% → RR 1.79×、−7% → 2.36×、−10% → 3.32×、−12% → 3.87×），
> 方向不隨機；但 `probability_lift` 的 bootstrap 95% CI 是 `[-0.0005, +0.3443]`，**下界仍微幅低於 0**。
> 所以保留為人工減碼 overlay 參考，不安裝為自動交易訊號。

**Q：那你的 n_eff 是多少？**（⚠️ 這題答錯就露餡）
> **35 不是 n_eff**。35 是「全歷史獨立事件數上限」，是這個議題最多能拿到的樣本。
> `n_eff` 要看**評估區間內的有效獨立觀測數**——OOS 期間是 **4 個獨立事件**。
> 這正是 `n_eff` 存在的理由：**OOS 有 2 年、481 個交易日，看起來樣本很多，但事件只有 4 個。**
> 「期間夠長」不等於「樣本夠多」，把 481 天當 481 個獨立觀測就是典型的 p 值虛低。

**Q：這個議題有跑實戰回測嗎？**
> **沒有**。依議題規範，vectorbt 扣成本對帳是 KEEP 前的關卡；本議題判 PIVOT 而**止步於 gate**，
> 所以沒有扣成本後的結論。這點 README 裡有明列（L8 未跑 vectorbt 實戰回測）。
> 真正做到扣成本、含融資成本、還開了 hold-out 的是 Pack D 的槓桿守門議題（見第二章）。

**Q：兩層（訊號發明 / 獨立策略）為什麼分開？**
> 兩個本質不同：訊號發明只問「這個 trigger 有沒有預測力」，輸出一條 P(down) 序列；策略層自己決定部位、方向、進出場，把訊號當輸入。混在一起的話——把預測訊號直接當交易訊號——會忽略成本、滑價、流動性，回測漂亮實盤崩盤。

**Q：Block Bootstrap 跟一般 Bootstrap 差在哪？**
> 一般 Bootstrap 假設樣本獨立，但金融事件不是——35 個崩盤事件可能擠在 3 波行情裡，每波 10 個事件高度相關。一般 Bootstrap 會把相關樣本當獨立，p 值樂觀上界。Block Bootstrap 以「波」為單位重抽，把相關性保留在區塊內，p 值才可信。

**Q：FDR 校正是什麼？為什麼必要？**
> 我同時測多個訊號，每個都做顯著檢定。單一檢定 p < 0.05 表示 5% 偽陽率，但 20 個訊號一起測，預期有 1 個偽陽性「顯著」。FDR（False Discovery Rate）校正控制「宣稱顯著的訊號中偽發現的比例」，避免被多重比較偏誤騙。

### 地雷

- **不要主動講「PIVOT 等於失敗」**——是檢力失敗，要區分清楚
- **不要宣稱「訊號能預測崩盤」**——是「在特定嚴重度下有方向性」，不是預測
- **不要把 35 說成 n_eff**——35 是全歷史事件上限，OOS 獨立事件只有 4 個。
  這題答錯特別致命，因為 `n_eff` 正是本平台反覆強調的概念
- **不要只報 3.87×**——要接著講「但 lift 的 bootstrap CI 下界還是低於 0」
- **被問「實盤用了沒」**：誠實說「目前是 overlay 參考，不是自動交易訊號」
- **被問「ETH 跟台股為什麼相關」**：說「流動性傳導假設——ETH 對全球流動性敏感，台股也受外資影響。但這個假設的因果沒被證實，所以 PIVOT」，不要過度解讀
- **不要把 path_labels.py 的 shift(-N) 當 bug 講**——這是 label 白名單，唯一允許的例外

---

## 二、槓桿守門 Overlay（Pack D）★ 紀律最嚴

### 30 秒電梯簡報

> 這是我唯一做到「**訊號怎麼變成部位**」的議題。問題設定很具體：
> **已經在扛槓桿持有台股指數的人，每天該持有幾倍曝險？**
> 不是問要不要進場，是部位規模管理。我拿上游的期貨籌碼訊號跟 ETH 強度訊號合議，
> 輸出一條逐日曝險倍數曲線，然後評估它相對「固定槓桿長抱」的回撤改善**跟保費成本**。
> 方法論上這題我做得最嚴：**規則跟判定門檻在跑第一格程式之前就寫進 `plan.md` 凍結**，
> hold-out 只開封一次、不因結果回頭調參。
> 結果是最大回撤從 −56.3% 砍到 −12.1%（改善 44.1 個百分點），
> 但**同期指數漲 91%，守門讓我少賺一半**——所以判定是 **CONDITIONAL，不是 KEEP**。

### 架構說明要點

1. **先把問題設定講對**——這是本題最容易被誤解的地方。
   不是「要不要進場」（那是 Pack A/B），是「**已經在場內的人該扛幾倍**」
2. **講事前登記**：`plan.md` 在跑第一格前 FROZEN，含規則、判定門檻、**以及開封前寫好的預期**；
   §7 設計變更紀錄**為空**，代表中途沒改規則
3. **講 phase1 的六種接法**：只有 R3（E02 或 ETH 任一亮就砍）過事前門檻
4. **講一條「等於沒裝」的腿**——`market_volatility` 加碼腿只改變 1742 天裡的 79 天（4.5%），
   我把它記為「**我這個接法沒給它作用空間**」，不是「這個訊號沒用」
5. **講 phase3 的結論**：槓桿上限不是一個數字，**取決於有沒有守門**
6. **講 phase5 hold-out 開封**——重點在「保護在、保費貴」跟 §6.5 那個紀律問題
7. **主動講樣本窗的代價**：約 7 年、**測不到 2008 與 2011**，而那是保護價值最大的兩段

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **Overlay（部位規模管理）** | 不決定買什麼，只決定「已經持有的部位要放大或縮小」 |
| **曝險倍數 / 水位** | 當日持有的槓桿倍數（0 = 空手、2.5x = 兩倍半） |
| **`mdd_improvement`** | 相對同槓桿不守門基準的最大回撤改善（pp = 百分點） |
| **`net_edge`** | 相對基準的年化報酬增減——**這就是「保費」** |
| **殘餘 MDD** | 裝了守門之後**還剩下**的回撤（強制揭露項） |
| **事前登記 Pre-registration** | 跑第一格程式前先寫定規則與判定門檻並凍結，事後不得反推 |
| **一次性 hold-out** | 只開封一次的考試區間，開完不得因結果回頭調參 |
| **CONDITIONAL** | 判定：部分門檻過、部分沒過——不是 KEEP 也不是 DISCARD |
| **逐日再平衡 vs 固定口數** | 前者每天調整曝險、後者固定口數；**在 2008 的結果完全不同**（固定口數必爆倉） |
| **探索期 informative** | 階段性結果，明標「不下 KEEP、未做 FDR、未接 vectorbt 對帳」 |
| **Kelly** | 最適下注比例；phase3 用「約半個 Kelly」形容有守門下的 2.5x |

### 關鍵數字

**phase1（IS 2017-11 ~ 2022-12 / OOS 2023-2024，L=2.5x、成本 5bps 單邊）**

| 規則 | IS MDD | IS 改善 | OOS 改善 | 平均水位 | 空手% |
|---|---:|---:|---:|---:|---:|
| R0 恆定 2.5x（對照） | −63.7% | — | — | 2.50x | 0% |
| R1 E02 單腿（現況基準） | −40.0% | +23.7pp | +28.6pp | 1.68x | 33% |
| **R3 E02 或 ETH ✅ 唯一過關** | **−29.6%** | **+34.0pp** | +28.6pp | 1.11x | 56% |

**phase5 hold-out（2025-01-02 ~ 2026-07-27，377 交易日 / 1.5 年）**

| 項目 | 值 |
|---|---|
| 同期指數報酬 | **+91.1%**；指數最深回撤 −26.7% |
| R0 不守門 | 終值 3.937x、CAGR 149.9%、**MDD −56.3%** |
| **R3 主規則** | 終值 1.894x、CAGR 53.3%、**MDD −12.1%** |
| MDD 改善 | **+44.1pp** ✅（事前門檻 ≥ +5pp） |
| `net_edge` | **−96.7pp** ❌（事前門檻 ≥ −15pp） |
| 平均水位 / 空手 | 0.82x / **67%** |
| 八次亮燈 | **只有一次真的躲對**，其餘七次虛驚 |
| **判定** | **CONDITIONAL** |

**phase3 槓桿上限**：沒守門 2.5x 已超上限；有守門 2.5x 偏保守、3x 有證據支持。
Calmar 隨槓桿**單調遞減**（1x 0.50 → 5x 0.42）；5x baseline 17 年 CAGR **−7.1%**。

### 預期面試問題

**Q：回撤從 −56% 砍到 −12%，這不是很成功嗎？**
> 一半成功。**保護確實有效，但保費很貴**——同期指數漲 91%，
> 不守門的話資產變 3.94 倍，裝了守門只有 1.89 倍，**等於少賺一半**。
> 而且八次亮燈裡只有一次真的躲對，其他七次都是虛驚、每次都空手看它漲。
> 所以判定是 CONDITIONAL：`mdd_improvement` 遠超門檻，但 `net_edge` 遠低於門檻。
> **只講前半段是行銷，講完整才是研究。**

**Q：⭐ hold-out 開出來，ETH 單腿（R2）表現最好，你為什麼不改用它？**（**這題答對是大加分**）
> 因為那會讓 hold-out 作廢。R2 在 hold-out 拿到 5.170x、`net_edge` **+49.9pp**，
> 是唯一「保護又賺更多」的規則——但**主規則 R3 是在 IS/OOS 階段事前選定的**。
> 如果我開封後改口說「其實 ETH 單腿才是我的主規則」，
> 這次考試就從「一次性驗證」變成「第三次調參」，那 hold-out 就沒有意義了。
>
> 所以我照事前登記報 R3 的 CONDITIONAL，然後把 R2 的結果**記錄下來當下一輪的假設**——
> **它現在是一個待驗證的觀察，不是一個結論。**

**Q：什麼叫事前登記？為什麼要這樣做？**
> 規則、判定門檻、甚至「我預期會看到什麼」都在跑第一格程式之前寫進 `plan.md` 並凍結。
> 例如 hold-out 開封前我就寫了：「2025~2026 是強多頭，守門必然少賺，
> 所以 `net_edge` 為負是**預期內**的，判定重點是 `mdd_improvement` 是否仍為正。」
> 事後對照——預期完全命中。
>
> 為什麼要這樣：**因為看到結果之後再訂門檻，等於用結果證明結果**。
> 事前登記是唯一能防止自己事後合理化的方法。

**Q：八次亮燈只對一次，這訊號不是很差嗎？**
> 這是保險的本質——保費就是為了少數幾次真的有事的時候。
> 問題不在命中率，在**保費是否划算**。而本議題的結論正是「**在這 1.5 年的多頭裡不划算**」，
> 所以我判 CONDITIONAL 而不是 KEEP。如果窗內有 2008，結論可能完全不同——
> 但我測不到，這也是我主動揭露的限制。

**Q：為什麼 `market_volatility` 那條腿沒效果？**
> 我不會說「這個訊號沒用」，因為**問題在我的接法**。
> 它的觸發條件要「恐慌反彈訊號亮 **且** 兩個減碼訊號都熄 **且** 還在 10 天回補等待窗內」——
> 三個條件同時成立的日子本來就稀少，結果它只改變了 1742 天裡的 79 天（4.5%）。
> 這是**「實作沒給假設機會」，不是「假設被否證」**——兩件事的歸因完全不同。

**Q：你引用的 ETH 訊號，上游判定不是 PIVOT 嗎？**
> 是，而且這需要說明。PIVOT 是**檢力失敗**（事件天花板 35、OOS 獨立事件僅 4），**不是方向隨機**。
> 上游議題自己的處置建議就是「保留作為人工減碼 overlay 警示參考」——**字面上就是我在做的事**。
> 我的引用姿勢是：ETH 強度當**減碼加成層**，不當獨立 KEEP 宣稱，
> 而且每次引用都要附「上游判定為 PIVOT（檢力不足），本議題僅作 overlay 權重輸入」。

**Q：加槓桿有讓風險調整後報酬變好嗎？**
> **沒有。** Calmar 從 1x 的 0.50 單調遞減到 5x 的 0.42。
> 所以「該開幾倍」本身就是要研究的變數，不是外生給定的參數。
> phase3 的結論是：**上限不是一個固定數字，取決於你有沒有在風險亮燈時把部位放掉**——
> 同一個 2.5x，沒守門是「長期會被磨死」的水位，有守門只是約半個 Kelly。

### 地雷

- **不要只講 −56% → −12%**——必須接著講「代價是少賺一半」
- **不要說這是 KEEP**——是 **CONDITIONAL**；phase1/2/3 還只是探索期 informative
- **不要漏講樣本窗**：約 7 年、**測不到 2008 與 2011**（保護價值最大的兩段）
- **不要說「已實盤」**——未接 vectorbt 對帳、未扣完整交易成本鏈
- **不要引用「降槓桿反而賺更多」**——README 明文禁止，那是 2008 專屬現象不是通則
- **不要漏講 OTC 未涵蓋**——前置研究只做 TAIEX，且這個單市場例外**尚未核准**
- **被問「這算策略嗎」**：算 Pack D，但角色是 **overlay（部位規模管理）**，不決定進場方向

---

## 三、FinGPT 恐慌指數（Pack C）

### 30 秒電梯簡報

> 這是我用 **Llama-3-8B + FinGPT LoRA** 把 cnyes 新聞做輿情推論，建立 **12 年（2015~2026）涵蓋 ~2900 檔股票**的 sentiment warehouse，再算出當下市場恐慌程度的 [0, 1] 百分位指標。關鍵是：這個指標**不預測漲跌方向**，只描述當下的恐慌環境，給下游策略當 regime 條件用。這一題我連續錯了兩次、也連續改了兩次——**第一次錯在把 baseline drift 當成訊號退化，第二次錯在把啟動門檻當成物理上限**。兩次都是我自己查出來改掉的，而且改對之後，同一份資料在 `bottom_dip` 軸上做出了整個平台唯一的 IS+OOS 雙 KEEP 訊號（第四章）。

### 架構說明要點（按這個順序講）

1. **先講資料**——cnyes 新聞清單 → NewsScraper 抓正文 → Llama-3-8B + FinGPT LoRA 8-bit 推論 → `fingpt_stock_sentiment` warehouse（12 年 ~290 萬筆）
2. **再講指標**——cross-sectional Z-score → 4 個並聯子指標（panic_index / volatility / anomaly_count / trend）→ 各自 expanding percentile（`min_periods=60`）→ 主指標 `panic_index_rank`
3. **講驗證**——Pack C auxiliary 不看 IC/IR，改看「狀態相關性」：state_icc（η²）≥0.05、state_spearman |ρ|>0.3 且 p<0.01、quantile_separation>0；目標狀態變數是 TAIEX/OTC 的 20d rvol + 5d MDD
4. **講生產**——n8n 每日 22:30 TST cron trigger → GPU 防呆（pgrep 4 個衝突 process）→ atomic UI snapshot（schema v2）→ Discord 通知
5. **最後講兩次 pivot**——這是最大亮點，但**必須講成一條因果鏈，不是兩個獨立事件**：

   | # | 內容 |
   |---|---|
   | ① | 實測 OOS IC 0.0296 / IR 0.2599 vs README 0.0360 / 0.3134 → **表面**退化 17~18% |
   | ② | **追查後推翻自己的退化結論**：90% 屬 baseline drift——0.0296 是「50 天 OOS + 18 個月 hold-out」的**混合基準**，跟 README 的數字不同基準、不可比 |
   | ③ | 所以降格理由不是「效果變差」，而是**軸契約要求 OOS ≥ 1 年、當時只有 50 天** → 結構上無法滿足 → 改掛 `auxiliary_signal` |
   | ④ | **隔天發現 ③ 的前提也錯了**：「只有 50 天」被歸因為「FinGPT 2024 才部署」，實查 warehouse 有 **12 年 4141 天**。真正限制只是 `expanding(min_periods=60)` 啟動門檻 → README 全面改寫 |
   | ⑤ | 用修正後的全歷史重跑子議題 → **`fingpt_panic_rebound` 取得 IS+OOS 雙 KEEP**（第四章） |

   > ⚠️ **千萬不要簡化成「IC 退化所以降格」**——我自己的 4 份文件
   > （`plan.md:35`、`notes/brainstorming.md:27-28`、`versions/v0_aux_pivot/README.md:12`、
   > `docs/ai-context/progress.md:22`）都寫了「90% 屬 baseline drift 而非訊號崩壞」。
   > 講簡化版一被追問就會被自己的 repo 打臉。

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **FinGPT** | 用 Llama 底座 + 金融語料 LoRA 微調的 LLM，專做財金輿情推論 |
| **LoRA（Low-Rank Adaptation）** | 只微調少量低秩矩陣，不用動主模型權重；8-bit 版本省 VRAM |
| **Cross-sectional Z-score** | 每日把所有股票的 sentiment 標準化（x-μ_daily)/σ_daily，消除大盤情緒漂移 |
| **Expanding percentile** | 每天用「歷史至今日」累積分佈算百分位，往前看不往後看（避免 lookahead）|
| **`min_periods=60`** | 啟動門檻——前 60 天不產出 rank，避免小樣本噪聲 |
| **Pack C · auxiliary_signal** | 不預測方向的市場狀態研究軸，禁止用方向 IC 評估 |
| **state_icc（η²）** | Intraclass Correlation——把分數切 4 分位看狀態變數的組間變異比 |
| **state_spearman** | 分數跟狀態變數的 rank 相關，越負代表越能抓高波動 |
| **quantile_separation** | Q4 平均 − Q1 平均，必須 > 0 才代表分數有區分力 |
| **sign_flip_ratio** | 滾動相關翻號比例，過高 = 信號不穩定 |
| **lag1_autocorr** | lag 1 自相關，過低 = 雜訊、過高 = 鈍化 |
| **Atomic UI snapshot** | 用臨時檔 + rename 寫入，下游不會讀到半成品 |
| **Pivot（研究軸變更）** | 從一個研究假設換到另一個；不是失敗，是誠實回應實證 |

### 預期面試問題

**Q：為什麼用 Llama-3-8B + LoRA 而不是直接呼叫 GPT-4 API？**
> 三個原因：1) 成本——12 年 ~290 萬筆推論，API 費用會爆；2) 隱私——研究資料不上傳第三方；3) FinGPT 是金融語料預訓練的 LoRA，對財金語意的掌握比通用 API 更精準。

**Q：12 年輿情資料怎麼可能？LLM 不是 2024 才部署？**
> 這正是 2026-07-15 我 README 修正的重點。LLM 確實 2024 才部署，但**回推**了所有 cnyes 歷史新聞——warehouse 有 2015~2026 完整 12 年 sentiment 推論結果。原本 README 寫錯把「`expanding(min_periods=60)` 啟動門檻」當成「物理上限」，其實只是契約選擇的 OOS 起點。

**Q：2026-07-14 的降格 pivot 是什麼意思？訊號失敗嗎？**
> 不是失敗，也**不是因為訊號退化**——這點我要先講清楚，因為我自己一開始也判斷錯。
>
> 我看到 OOS IC/IR 比 README 記載低了 17~18%，第一反應是訊號衰退。但我去追比較基準，
> 發現 **0.0296 是「50 天 OOS + 18 個月 hold-out」的混合基準，README 的 0.0360 是另一個時間點**——
> 兩個數字根本不同基準、不可比，**90% 的落差是 baseline drift，不是訊號崩壞**。
>
> 那為什麼還是降格？因為**真正的卡點是契約而不是績效**：`top_risk` 軸要求 OOS 至少 1 年，
> 當時我只有 50 天 → **結構上無法滿足契約**，那就不該掛在那個軸上宣稱方向預測。
> 狀態相關性還在，所以改到 `auxiliary_signal` 當環境描述器。
>
> 這件事的重點不是「我誠實承認訊號變差」，而是「**我連自己的負面結論都再驗證了一次**」。

**Q：那第二次修正跟第一次有關係嗎？**
> 有，而且是直接推翻。第一次降格的理由建立在「OOS 只有 50 天」，
> 而 README 把原因寫成「FinGPT 模型 2024 才部署、無法往前補」。隔天我實查 warehouse——
> **2015~2026 共 12 年、4141 天、~2900 檔都在**。「只有 50 天」不是物理上限，
> 只是 `expanding(min_periods=60)` 的啟動門檻加上發佈時間。
>
> 所以我把 README 全面改寫，並釘死「**物理不可能**」跟「**契約選擇**」的差別——
> 前者不能改，後者是我自己選的、可以改。然後子議題用全歷史重跑，
> 拿到了原本被這個錯誤前提擋掉的結果：**IS+OOS 雙 KEEP**。

**Q：n8n 排程的 GPU 防呆是怎麼做的？**
> `pgrep -f` 同時檢查 4 個衝突 process（`run_daily_update / run_backfill / run_inference / ingest_news`），任一在跑就跳 skip 並發 Discord 通知。避免 LLM 推論疊加 OOM。

### 地雷

- **不要主動講「以前宣稱預測下跌」**——主動講會被認為是 bug。被問到才講 pivot 故事
- **不要把降格講成「訊號退化」**——自己的 4 份文件都寫「90% 屬 baseline drift」。
  正確理由是**軸契約 OOS 不足 1 年**
- **不要把 `min_periods=60` 講成「物理限制」**——那是啟動門檻，跟物理上限不同
- **被問「跑得起來嗎 / 測試綠嗎」**：⚠️ 這個模組有 **3 個 pytest 失敗 + 17 個 skipped**，
  記在 `KNOWN_ISSUES.md`。主動說明：性質是**測試沒跟上重構**（欄位 `sentiment_volatility` 已改名 `volatility`）
  跟**舊 IC 路徑殘留**，不是指標算錯；指標正確性由 Pack C 驗證腳本 + notebook Restart & Run All 保證；
  處置原則是**修之前先補對應單測**。**不要說「測試都是綠的」**。
  對照組：姊妹議題 `fingpt_panic_rebound` 是 **61 passed 全綠**
- **被問「實盤用了沒」**：誠實說「目前是 overlay 參考，下游策略還沒正式上線自動交易」
- **不要把 state_icc 跟方向 IC 混為一談**——η² 是狀態變異比，IC 是預測相關，**完全不同語意**

---

## 四、恐慌抄底訊號（Pack B）★ 唯一雙 KEEP

### 30 秒電梯簡報

> 這是我唯一一個**通過完整穩健性驗證**的訊號。假設很簡單：**輿情恐慌到極端、而且價格已經跌下來**，
> 這兩個條件同時成立時，未來 5 天出現反彈的機率顯著高過 baseline。
> 我用前面那套 FinGPT 恐慌百分位當輿情端、技術超跌當價格端，
> 訊號是 `panic_index_rank > 0.85 AND market_drawdown < -0.05`。
> 驗證做得比我其他議題都完整——**內樣本 8 年 69 次訊號、外樣本 2 年 13 次，兩邊都 KEEP**，
> 再加 4 段 walk-forward、4 次危機事件、以及 25 個參數變體全部通過。
> 不過我要先說：**目前只做到 paper trading，10 筆交易、沒扣滑價**，所以我不會說它能賺錢。

### 架構說明要點

1. **先講它是誰的續集**——用的是第三章那個 FinGPT 恐慌指數。
   因為第三章修正了「只有 2024 之後資料」的錯誤前提，這題才拿得到全歷史 4141 天
2. **再講三條假設，兩條死掉**：
   - H1 恐慌極值（單條件）→ 只有極端閾值 0.93-0.96 才成立，**需要 dd 條件配合**
   - H2 恐慌降溫（轉折型）→ **OOS 25 次全滅**，典型 IS-only effect
   - H3 恐慌 + 技術超跌 → **25/30 雙 KEEP**
3. **講「H2 失敗是好消息」**——H2 是最直覺的那條（等恐慌退了再進場），它 OOS 全滅，
   反而證明這套流程不是在幫我找想要的答案
4. **講切分紀律**：IS 2015-2022（8 年）/ OOS 2023-2024（2 年，**sealed final-only**）/ Hold-out 2025+（永久禁觸）。
   100 iterations 全在 IS 內做完，**OOS 只在 iter 100 開封一次**
5. **講穩健性的四個維度**（這是本題價值所在）：跨期、跨危機、跨參數、跨市場性質
6. **最後主動講限制**：paper trading、不含成本

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **MFE（Maximum Favourable Excursion）** | 未來 h 日**最大漲幅**（曾經最高漲到哪），Pack B 的 label |
| **`probability_lift`** | 訊號亮燈時的事件率 − baseline 事件率 |
| **`magnitude_lift`** | 事件的**幅度**差（bps），與 prob_lift **必須同向**才算 KEEP |
| **雙 KEEP** | `probability_lift` 與 `magnitude_lift` 同時通過且同向 |
| **sealed final-only** | OOS 不參與調參，跑完 IS 才開封、只考一次 |
| **IS-only effect** | 只在訓練期成立的假象效應（H2 就是） |
| **regime-independent** | 跨不同市場狀態都成立（盤整 / 崩盤 / 空頭都過） |
| **Paper trading** | 紙上交易模擬——按訊號記錄進出，但**不真的下單** |
| **Topic-local code** | 議題間不互相 import runtime，只透過匯出檔案傳資料 |

### 關鍵數字

| 項目 | 值 |
|---|---|
| IS（2015-2022，8 年） | n=69，5d `prob_lift` **+13.32%**，`mag_lift` +24 bps → KEEP |
| OOS（2023-2024，2 年） | n=13 → KEEP |
| Walk-forward | 4/4 段 KEEP（2015-17 盤整 / 2018-19 貿易戰 / **2020 COVID 雙 KEEP** / 2022 空頭） |
| Crisis events | 3/4 KEEP（2020 COVID / 2022 bear / 2018 trade war；2015 China 樣本不足不宣稱） |
| 參數穩健 | **25 個變體全部雙 KEEP**（panic_th 0.65~0.90 × dd_th −0.03~−0.10） |
| 100 iterations 總計 | IS KEEP 74/91、OOS KEEP 36/91、**雙 KEEP 35/91** |
| 測試 | **61 passed 全綠** |
| Paper trading | 10 筆 OOS trades，持有 10 日為 sweet spot |

### 預期面試問題

**Q：為什麼要三條假設？一條不就好了？**
> 因為**一條成立很可能是運氣**。三條裡有兩條死掉、一條在整片參數空間都成立，這個 pattern 才像真效應。
> 特別是 H2（恐慌降溫）是我直覺最看好的那條，它 OOS 全滅——這反而讓我對 H3 更有信心，
> 因為說明流程不是在幫我背書。

**Q：OOS 只有 13 次訊號，樣本會不會太少？**
> 會，我不會硬撐這個數字。所以我的說服力不是放在「OOS n=13 通過」，
> 而是放在**一致性**：IS 69 次通過、4 段不同市場性質的 walk-forward 都通過、
> 4 次危機事件通過 3 次、25 個參數變體全部通過。
> **單一數字可以是運氣，這麼多維度同時一致就不太像。**

**Q：為什麼參數穩健比績效重要？**
> 因為**單點最優通常是過擬合的症狀**。如果只有 `panic > 0.85 AND dd < -0.05` 這一組能過、
> 隔壁 0.84 或 −0.06 就掛掉，那我找到的是資料的噪音。
> 我找到的是 `[0.65, 0.90] × [-0.03, -0.10]` 這**一整片**都能過——那才像結構性的效應。

**Q：同一個 panic 指標，第三章說不能宣稱方向，這裡又說能預測反彈？**
> 因為**問的不是同一件事**。第三章（Pack C）問「這個分數能不能描述當下的波動狀態」——那是同期相關；
> 這裡（Pack B）問「這個分數**加上價格已經跌下來**之後會不會漲」——那是條件事件機率。
> **關鍵在 H3 不是單用 panic**：光靠輿情不夠（H1 只有極端閾值才成立），必須配上技術超跌這個條件。

**Q：paper trading 的結果如何？**
> 10 筆 OOS 交易，持有 10 日是 sweet spot。但我要先講清楚它的四個限制——
> **不是真實下單、不含手續費稅滑價、用 TAIEX 報酬指數當 proxy（實際會用 0050 這種 ETF，有追蹤誤差）、
> hold-out 2025+ 嚴格禁觸**。這四條是 simulator 的 docstring 自己列的。
> 下一步才是接 vectorbt 扣成本對帳，那之前我不會說它能賺錢。

**Q：為什麼不打開 hold-out 看看？**
> 因為打開就沒有 hold-out 了。2025+ 留著是為了未來還有一次乾淨的考試機會。

### 地雷

- **不要說「這個訊號能賺錢」**——只到 paper trading，未扣滑價、未接 vectorbt 對帳
- **不要漏講「不含手續費 / 稅 / 滑價」**——simulator 自己標了，主動說是誠實，被抓到是扣分
- **不要把 OOS n=13 講得太滿**——說服力在多維度一致性，不在單一數字
- **不要說「2015 China 也過了」**——樣本不足，**不宣稱**
- **不要 import 混淆**：本議題**不 import** `fingpt_risk` 模組，只讀它匯出的 CSV（檔案層依賴）。
  理由是避免一個議題改實作就悄悄改掉另一個議題的歷史結論

---

## 五、產業輪動風險（Pack C）

### 30 秒電梯簡報

> 這是我用 cmoney 集團股分類（37 個集團、248 檔成員）+ TSE/OTC 收盤價，設計兩條指標：**rotation_intensity**（10 日內集團報酬變動平均，越高越亂）跟 **theme_strength**（top3 集團穩定度，越低越沒主線）。兩條 Z-score 組成 1-5 風險分數，每日推 Discord 4 色通知。我跑 **12 輪 autoresearch**，**只有 v1 baseline 過得了 gate，其餘 11 輪全 DISCARD**。最大收穫是發現 v1 README 的 η²=0.36 是 **circular 評估**——用 theme_strength 當 state_var 算的（公式裡有 theme_raw），真正外部 twii_vol 重算只有 0.038，所以我誠實揭露並補上外部寬度驗證。

### 架構說明要點（按這個順序講）

1. **先講資料**——cmoney 37 集團（從 FinLab 46 產業改過來，external icc 提升 2.9×）+ TSE/OTC close parquet
2. **再講指標**——rotation_intensity 公式 `diff().abs().mean(axis=1).rolling(10).mean()`；theme_strength 公式 `(top3_pct × 0.5 + (1-leader_pct) × 0.5) × 100`，兩條都先 lookback-only percentile（window=252 min_periods=60）
3. **講風險分數**——`score = 1 + (z_rot>0.5) + (z_rot>1.5) + (z_theme<-0.5) + (z_theme<-1.5)` clip(1,5)，4 色 Discord（綠黃橘紅）
4. **講 12 輪 autoresearch**——v1 baseline KEEP 後試了 5 種參數微調（median 平滑、min_periods）+ 6 種機制層（hysteresis、cooldown）+ 1 個 circular 評估，**全 DISCARD**。v8/v9 形成 Pareto 邊界（v8 icc=0.31 過/switch=15.58 沒過，v9 反之）
5. **最後講 circular trap**——這是最大誠實亮點：v1 README 的 η²=0.36 是用 theme_strength 當 state_var 算的，公式本身引用 theme_raw → 用真正外部 twii_vol 重算只有 0.038。我補上台股 8 寬度指標 + 美股 11 寬度指標做外部驗證

### 專有名詞對照

| 中文 / 英文 | 白話解釋 |
|---|---|
| **cmoney 集團股** | cmoney 平台的分類——把有集團關係的股票聚合（例如台塑集團 = 台塑+南亞+台化+台塑化）|
| **Rotation Intensity** | 集團報酬變動的 10 日平均——越高代表資金在集團間快速輪動 |
| **Theme Strength** | top3 集團穩定度——越高代表市場有明確主線 |
| **Pareto 邊界** | 多目標最佳化——icc 跟 switch_per_Q 互相拉扯，無法同時最優 |
| **Autoresearch** | 自動化研究迭代框架——每輪改一個機制，全過 gate 才 KEEP |
| **Circular Evaluation** | 循環評估——用衍生指標當 state_var，公式跟指標有相關性 → 分數膨脹 |
| **state_icc ≥ 0.30** | Pack C auxiliary 的主決策門檻（η²） |
| **switch_per_Q ≤ 12** | 每季切換次數——過高代表信號跳來跳去不穩定 |
| **sign_flip_ratio ≤ 5%** | 滾動 15 天相關翻號比例（注意：README 寫 30% 是舊版）|
| **lag1_autocorr ∈ [0.55, 0.85]** | lag 1 自相關範圍（注意：README 寫 [0.40, 0.85] 是舊版）|
| **Cohen's d** | 標準化效果量——兩組均值差除以合併標準差，0.5 算中等效果 |
| **Spearman ρ** | rank 相關——比 Pearson 對極端值更穩健 |
| **RSP / SPY** | RSP = S&P 500 Equal-Weight ETF；SPY = 一般市值加權版 |
| **lead-lag** | 領先-落後關係——A 先動 B 後動？

### 預期面試問題

**Q：12 輪全 DISCARD 只留 v1，會不會是過度堅持？**
> 不會——這是 Pack C gate 的設計目的。gate 嚴格是為了擋偽顯著。v1 是 baseline，後續 11 輪都「試著改良」，但每次改良要嘛傷 icc、要嘛傷 switch，沒有任何一個能同時滿足——這恰恰證明 v1 已經在 Pareto 邊界上，無法被進一步優化。
>
> 但這裡我要主動補一個前提（見下一題）：**12 輪用的 icc 都是同一個 circular 指標**，
> 所以我用它做**排序**，不用它做**對外宣稱**。

**Q：等一下——v1 KEEP 用的 icc=0.3585 不就是你說 circular 的那個數字？**（⚠️ 最致命的追問）
> 對，**就是那個**。所以我的立場要說清楚：
>
> | | 立場 |
> |---|---|
> | **絕對值** | **不可信**——換成真正外部的 `twii_vol` 重算只有 **0.038** |
> | **相對排序** | **仍有效**——12 輪用的是同一個（有偏但一致的）評估函數，「v2 比 v1 差」這種比較沒失效 |
> | 「v1 是 Pareto 最優」 | 成立，但語意限縮成「**在這個內部一致性指標下**位於邊界」，不是「有 0.36 的外部解釋力」 |
> | **外部效力** | 另立驗證：8 個台股寬度指標（n=481，8/8 跨期同向，最高 ρ=−0.40 `above_ma60`） |
>
> 一句話：**我用 circular 指標排序，用外部寬度指標宣稱。**
> 如果對方是先問「你的 0.36 怎麼算的」——代表他已經看出來了，這時候直接承認、
> 馬上接到外部驗證，**不要試圖辯護那個數字**。

**Q：v8/v9 Pareto 邊界是什麼意思？**
> v8 cooldown=1：icc=0.31 過門檻、switch_per_Q=15.58 超過 12 → 卡在 switch。v9 cooldown=2：switch=11.62 過、icc=0.26 不過 0.30 → 卡在 icc。兩個版本各過一個 gate，**沒有候選能同時滿足**——這就是多目標最佳化裡的 Pareto 邊界，沒有「最好」只有「互換」。

**Q：circular trap 是怎麼發現的？**
> v1 README 宣稱 η²=0.36（很高），但我懷疑——v1 公式裡 score 用 theme_strength 算，如果 state_var 也選 theme_strength，等於用公式產物評估公式本身。我用真正外部 twii_vol（TAIEX 波動率）重算，η² 掉到 0.038。這發現寫在 `notes/cmoney_classification_test/findings.md`，**我沒有刪掉 v1 紀錄，而是誠實揭露並補上外部驗證**。

**Q：外部寬度驗證（8 台股 + 11 美股指標）的結論是什麼？**
> 台股 8 指標全跨期同向、翻號比都 < 5%，最高 ρ=-0.40（above_ma60），驗證 v1 是台股內部狀態描述器。但美股 11 指標跨期同向 0/11，只有 RSP/SPY 20d 變化率 Cohen's d=+0.51（中等效果）——**跨市場用途需要重新設計，不能直接套用**。

**Q：為什麼用 cmoney 集團股不用一般產業分類？**
> 我做了 A/B test。原本 v1 用 FinLab 46 產業分類，後來改 cmoney 37 集團股，external icc 提升 **2.9×**（`notes/cmoney_classification_test/`）。集團股的好處是成員有真實股權關係（母子公司、交叉持股），資金流動比產業分類更同步。

### 地雷

- **不要主動講 circular trap**——自己講等於自爆。被問「v1 的 0.36 怎麼來的」才講，並強調「我**主動**補上外部驗證」
- **不要把 switch_per_Q=22.62 講成 bug**——v1 LOCK 時已經知道超過 12，是契約選擇下的 Pareto 最優解，不是疏漏
- **不要混淆兩個產業輪動**——Plutus 的 `research/market-analysis/theme_industry_correlation/` 是學術式 5760 組回測，跟這個生產監控完全不同
- **被問「實盤用了沒」**：誠實說「目前是每日 Discord 通知 + UI snapshot，下游策略還沒正式接入自動交易」
- **被問「v1 還在用嗎」**：是，v1 從 2026-07-01 LOCK 到現在沒換，後續沒有任何候選能同時過 gate

---

## 六、LLM 因子自動演化

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
> 用 **MiniMax-M3**（走 OpenAI 相容介面，`api.minimax.io`）。選它的原因是程式碼生成能力加上 1M context——
> 我要在 prompt 裡塞菁英程式碼、失敗 traceback 跟資料 schema，短 context 塞不下。
> 而且它跟 Hermes 的研究類 profile 同一個 provider，**只管一組 API key 跟一份配額**。
> 配置上同一個模型指派三個角色：主力生成（低溫）、高溫探索（跳出區域最佳）、評估回饋（把分數翻成自然語言提示）。
> 成本控制主要靠 Diff——token 數比整檔 rewrite 少 80~90%。

> ⚠️ **這題以前答錯過**：舊版稿子寫「GLM-5.2（智譜）」，文件另一處寫「DeepSeek」，
> **實際 config 是 MiniMax-M3**。GLM 是 Hermes 維運 profile 用的，不是因子演化用的——不要混。

**Q：怎麼驗證 LLM 寫的因子不是過擬合？**
> 三層驗證：1) 因子要在 IS 期間顯著；2) OOS 期間 IC 衰減 < 30%；3) DSR 校正後仍顯著。沒過這三關的因子直接丟棄。

### 地雷

- **不要說「LLM 會取代量化分析師」**——這是工具，不是替代品
- **不要宣稱「自動找到聖杯因子」**——這是搜尋框架，找到的因子還是要人審
- **被問「LLM 寫的因子可解釋嗎」**：誠實說「部分可，LLM 會附 rationale，但有的純數學技巧要事後解讀」

---

## 七、GA 選股策略

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

## 八、AI 服務編排層

### 30 秒電梯簡報

> 這是我搭的**服務編排層**——上游是 datawarehouse、research、evolution-lab 這些「實作層」，我把它們的能力對外暴露成四種形態：**Hermes 是 AI Agent Runtime**，承載 5 個 agent profile；**n8n 是自動化引擎**，排程、webhook、資料 pipeline 全走這裡；**data-api 是 FastAPI**，把倉儲查詢變 REST endpoint；**plutus_ui 是 Next.js Portal**，而且刻意拆成內網站跟對外站兩個獨立 app。設計理念是「**實作跟暴露分離**」——研究端寫策略不用管 UI，UI 不用懂策略。而對外那一半還多一層：**演算法細節不能離開內網**，這件事我是用腳本把關的，不是靠記得。

### 架構說明要點

1. **先講雙層分工**：
   - 實作層（上游）：datawarehouse / research / evolution-lab / core
   - 暴露層（本層）：hermes / n8n / data-api / plutus_ui
2. **判準**：「需要領域知識才能回答的決策」（Sharpe 門檻、因子篩選）屬實作；「對外暴露的機制」屬暴露
3. **四個子服務**：
   - Hermes 5 profile：ops / steward（維運）→ GLM-5.2；librarian / risk / quantix（研究）→ MiniMax-M3
   - n8n **48 個 workflow**：Hermes 25 / Risk 18 / System 4 / 根層 1
   - data-api：9 個 REST router + 5 個 reader + 分級 cache TTL
   - plutus_ui：**Next.js**，`web/` 內網站（DW 血緣 / 資料集探索 / 回測 / 演化 / 爬蟲 hub）+ `web-public/` 對外站
4. **Hermes Adapter**：FastAPI :18790，把 HTTP `/tools/invoke` 轉 Hermes CLI `chat -q`，給 n8n 用
5. **最後講內外網隔離**（這是本章最強的一段，見下方 Q&A）

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
| **Next.js / React** | 前端框架；本專案 Next 16 + React 19，[ADR-003](./services.md) 定為唯一前端 |
| **內網站 / 對外站** | `web/`（走 data-api，即時）vs `web-public/`（走 Supabase，build 時預取） |
| **`service_role`** | Supabase 的最高權限 key——**對外站禁止出現** |
| **路由白名單 ALLOWED_ROUTES** | `check-public-isolation.sh` 的允許清單，新增公開路由沒同步就過不了檢查 |
| **GLM-5.2 / MiniMax-M3 / GLM-4.5** | LLM 模型——維運 profile / 研究 profile（亦為全域 default）/ 429 fallback |
| **Model Routing** | 不同任務路由到不同模型，控制成本 |
| **Docker Compose** | 多容器編排工具 |
| **子專案 Subproject** | monorepo 內的獨立子專案 |

### 預期面試問題

**Q：為什麼要分「實作層」跟「暴露層」？**
> 兩個理由：1) 關注點分離——研究端改策略不用動 UI，UI 改 layout 不用碰回測邏輯；2) 部署獨立——Hermes 重啟不影響 datawarehouse，n8n 升級不影響策略。

**Q：Hermes 跟 n8n 怎麼分工？**
> Hermes 是大腦（AI Agent），n8n 是神經（流程編排）。n8n 觸發事件（cron、webhook）→ 透過 adapter 問 Hermes → Hermes 做決策（風險分析、自動報告）→ n8n 接著動作（發 Discord、寫 DB）。Hermes 不主動觸發，n8n 不做 AI 推理。

**Q：5 個 profile 怎麼決定的？**
> 按職責分：ops（系統維運）、steward（總管）、librarian（資料查詢）、risk（風險分析）、quantix（量化研究）。
> 維運那兩個用 GLM-5.2（任務結構化、對中文意圖理解強、成本可控），
> 研究那三個用 MiniMax-M3（1M context，要讀大量文件與程式碼）。模型分層省成本。
>
> ⚠️ **如果對方打開 `config.yaml` 會看到不一樣的東西，要能解釋層級**：
> `config.yaml` 的 `model.default` 是**全域預設 MiniMax-M3**、429 fallback 是 `glm-4.5`；
> 維運類的 `glm-5.2` 是**profile 層覆寫**（每個 profile 有自己的 config），決策紀錄在 `services/hermes/README.md`。
> 另外 `config.yaml` 還有 `orchestrator` / `researcher` 兩個 **kanban 排程角色**，
> 不算在「5 個業務 profile」內——被問「到底幾個」要分清「業務 profile」與「排程角色」。

**Q：data-api 跟直接讀 parquet 差在哪？**
> data-api 提供 REST 介面，外部服務（如 n8n workflow）不用懂 parquet 路徑與 schema；統一上 cache 跟 audit log；對外暴露的合約穩定，後端改 schema 不影響呼叫端。
>
> 補充口徑：`main.py` 實際註冊 **9 個** router。`etf_bh_metrics.py` 檔案存在但**沒註冊**，
> 而 `commentary` 跟 `research` 共用 `/api/research` prefix——如果對方數檔案數到 10，差異就在這。

**Q：為什麼從 Streamlit 換成 Next.js？（ADR-003）**
> 早期是 Streamlit，優點是研究端自己就能寫頁面、不用排前端。但兩個問題逼出遷移：
> 1) **無法做內外分離**——Streamlit 的 server-side 執行模型下，很難「證明」對外站沒碰內網；
> 對外要的是 build 時就把資料烤成靜態頁、執行期完全不連內網。
> 2) **對外站需要真正的前端控制權**——路由白名單、CSP、預取策略，在 Streamlit 裡都是繞路。
>
> 誠實補充：遷移成本不低（頁面全部重寫）。換來的是「**對外曝光面可以被腳本驗證**」，
> 在會碰到策略細節的專案上這是必要的，不是為了跟流行。

**Q：對外站怎麼確保不洩漏策略細節？**（這題答好很加分）
> 我把它變成**機械化規則**，不是靠自覺：
> - `web-public/` 是獨立 app，**不得引用 `services/data-api`**、不得有寫入型 route handler、不得出現 `service_role`
> - 禁上架路由白名單：`/ops`、`/evolution`、`/research-lab`、`/quantix`、`/chat`、`/dw`
> - 明文禁止外流的語彙：**因子代號、閾值、OOS 統計、進場／出場／停損／停利**
> - 新增公開路由必須同步 `scripts/check-public-isolation.sh` 的 `ALLOWED_ROUTES` 與 `docs/public-scope.md`
>   → **忘記更新就過不了檢查**
>
> 重點：這類規則如果只寫在文件裡，半年後一定會被違反。**要讓違反它的人當下就過不了。**

### 地雷

- **不要說「Hermes 是我自己寫的」**——是 Nous Research 的開源框架，我只做整合
- **不要說「plutus_ui 是 Streamlit」**——已全面遷移 Next.js（ADR-003）。
  也不要說「對外要換 React 但需求還沒到」——**已經換了**，這句話講出來就露餡
- **不要說「Page 6 因子瀏覽器」**——那是 Streamlit 時代的頁碼語彙，現在是 `/evolution` 路由
- **不要把 n8n workflow 數說成 39**——目前 **48**，而且會長。說「目前 48 個」而不是當固定規格
- **被問「GLM-5.2 / MiniMax-M3 怎麼選的」**：說「成本跟效果權衡——維運任務不需要大 context，研究任務才上」，不要展開講 PoC 數據
- **被問「服務怎麼部署」**：說「docker-compose 多容器，每個子服務一個 container」，不要展開 k8s 細節（除非真有）

---

## 九、多源資料倉儲

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
> 三層，而且第三層是**紀律不是技術**：
> 1) Rate Limiter 在 Executor 層用 token bucket，每源獨立設定（FinMind 20,000 req/hr、KRX 只給 1,800/hr）；
> 2) Error Classifier 識別 429，指數退避後重排回 ZSET，不直接放棄；
> 3) **配額安全鐵律**——我把「絕不可為了加速補 backlog 而調高 workers / rate-limit」寫成規則檔
> （`.claude/rules/finmind-throughput-safety.md`），因為佔滿配額會觸發停權跟 IP ban，
> 而且會**同時打掉所有資料源**的當日更新。`IP_BAN_COOLDOWN_SECONDS = 2100`（35 分鐘）也寫死在 constants。
>
> 這條的重點是：**backlog 積壓時「加大並行」是最直覺的動作，但懲罰是延遲發生的**。
> 所以我把它變成規則，而不是靠當下的自覺。**慢補是常態，不是要修的效能問題。**

**Q：進程怎麼管？排程會不會疊起來？**
> ADR-012：jupyter 內用 supervisord 持有 `worker-{finmind,binance,yfinance,macro}`，
> `--daemon --max-runtime 86400` + autorestart。**n8n 只負責 enqueue**
> （`POST /api/warehouse/update?source=X` 是 enqueue-only），排程器不直接下載——
> 這樣排程重疊也不會變成並行放大。

**Q：韓股 KRX 的資料怎麼拿？**
> 先講定位：**KRX 官方 Open API 不提供部分欄位（例如衍生品 OHLCV、籌碼面），
> 我用三個各自合法的公開來源拼出量化需要的覆蓋**——
> FinanceDataReader（維護者自建的公開 GitHub cache，匿名讀）、
> Naver Finance（公開網頁，取外資買賣超與持股比）、pykrx（衍生品 28 類別 metadata）。
> 落地是 registry 裡 4 支 API。合規上：都是公開端點、沒有帳號共用、沒有反爬對抗，
> 而且我把限速壓到 2 workers / 1800 req-hr，比對方的軟限流更保守。決策紀錄在 ADR-013。

**Q：怎麼知道資料是對的？**
> 三層驗證：1) Schema Validator 確認欄位型別；2) 多源交叉比對（同一標的在 FinMind 跟 yfinance 價格差 < 1%）；3) 每日審計腳本跑分布檢查，找出異常值。

### 地雷

- **不要說「我繞過了 KRX 會員牆」**——這個講法會被聽成灰色地帶。
  正確說法是「Open API 沒提供的欄位，用三個公開來源補齊」，並主動提限速比對方要求更保守
- **被問「資料源 API key 怎麼管理」**：只說「在 `.env` 用環境變數注入容器」，不要展開講
- **被問「實際資料量」**：說「**百萬級歷史 K 線**」。**絕對不要說 PB 級**——
  數量級差太多，一被追問「你怎麼存 PB」就崩。（舊版 flowchart 寫過 PB 級，已修正）
- **被問「幾個資料源」**：答「**6 個獨立限速群組、8 個對外供應方**」，
  不要含糊說「七八個」——CFTC / FRED / EIA / Congress / CNN 都掛在 `macro` 一個群組下共用限速器

---

## 十、策略回測報告

### 30 秒電梯簡報

> 這是我研究早期用 FinLab 回測篩策略候選的產出，17 份報告。
> 我先講定位：**這些是研究層的候選篩選，不是實盤績效，也不是我的成績單。**
> 成本扣了手續費跟證交稅，但**沒扣滑價、沒做 IS/OOS 切分、也有倖存者偏誤**——
> 被淘汰的組合我沒留報告。所以裡面的年化報酬應該當**上界**看。
> 它的用途是展示我熟回測工具鏈跟策略直覺；**統計嚴謹度那部分在 market-risk 那條線**。

### 為什麼要主動降低這區的權重

報告裡年化 34%~111%、Sharpe 1.8~2.6。**這個量級應該引起懷疑，不是引起讚嘆。**
如果不主動框定，面試官只會有兩種反應：不信，或者認為你不懂。
**主動說出限制，才能把它從「可疑的績效」變成「誠實的研究紀錄」。**

### 關鍵數字與設定

| 項目 | 值 |
|---|---|
| 份數 | 17（其中 2 份資料重複，見下方） |
| 年化報酬範圍 | 33.6% ~ 111.4% |
| Sharpe 範圍 | 1.80 ~ 2.59 |
| 最大回撤範圍 | −22.2% ~ −34.4% |
| 期間 | 各異，最早 2013-06，統一到 2026-07-30 |
| **已扣成本** | 手續費 `feeRatio` 0.000314 / 0.000428（2.2 折 / 3 折）+ 證交稅 `taxRatio` 0.3% |
| **未納入** | 滑價、流動性 / 容量、借券與融資成本、漲跌停無法成交 |
| 換股頻率 | 多為月頻（依月營收發布日） |

### 預期面試問題

**Q：年化 100% 是真的嗎？**
> 回測是真的算出來的，但**不能當成可實現的報酬**。誠實歸因有五點：
> 1) 台股中小型股的動能與營收成長因子在 2013~2026 這段確實強勢；
> 2) **沒扣滑價**——這類策略集中在中小型股又月頻換股，滑價會顯著吃掉報酬；
> 3) **沒做容量分析**——`is_largest(10)` 選 10 檔，資金一放大就推動自己的成交價；
> 4) **沒做 IS/OOS 切分**——停損、選股數這些參數是全期最佳化的，帶樣本內偏誤；
> 5) **倖存者偏誤**——留下來的 17 份是我主觀篩過的。

**Q：那你怎麼證明你懂過擬合？**
> 看我後來做的事。這批回測是我的**起點**，不是我的證據。
> 之後我把重心移到 `market-risk`，那條線每個結論都要過 purged walk-forward、
> block bootstrap、FDR 校正，而且**大部分議題的結論是 PIVOT 或 CONDITIONAL，不是 KEEP**。
> 唯一雙 KEEP 的那個訊號（第四章），我還是只敢說做到 paper trading。
> **從這批回測到那條線，就是我對過擬合理解的變化過程。**

**Q：`small_cap` 跟 `strong_breakout` 的數字怎麼一模一樣？**（⚠️ 已自曝，要準備）
> 這是我自己標出來的資料問題。兩個檔案除了 `<title>` 不同（小市值 / 強勢突圍），
> **績效指標與交易紀錄逐位元一致**——表示其中一份是用錯誤的策略設定產出的，
> 很可能是複製後只改了標題。**待重跑，在此之前這兩份只能算一份有效樣本。**
> 我把它寫在 README 裡，因為與其讓人自己發現兩條一樣的權益曲線掛不同名字，不如自己標。

**Q：super8888 是什麼意思？**
> 老實說是開發期的迭代編號，沒有語意。檔名待改成語意化命名。
> （**不要現場編一個聽起來有道理的解釋。**）

### 地雷

- **不要主動炫耀年化報酬**——先講限制，再講數字
- **不要說「含所有成本」**——只含手續費與證交稅，**滑價沒有**
- **不要說「有做樣本外驗證」**——這批是全期回測，**沒有 IS/OOS 切分**
- **不要迴避重複檔案問題**——已經寫在 README，被問就照講
- **被問「哪個策略最好」**：不要選一個吹。答「這批的用途是挑方向，
  真正被我拿去做完整驗證的是恐慌抄底那個訊號」——把話題導回第四章

---

## 共通問答（跨主題）

**Q：這些是你一個人做的嗎？**
> 個人研究專案，全程自架。AI 工具（Claude Code、OpenCode）協助產生程式碼與審查，但架構決策、方法論選擇、bug 處理自己來。

**Q：哪個專案最難？**
> market_risk——金融統計的細節多（lookahead、n_eff、FDR），錯一個地方整個結論翻盤。其次是 datawarehouse，並發跟資料完整性問題很多。

**Q：你怎麼驗證這些系統是對的？**
> 四層：
> 1) **單元測試（pytest）**——⚠️ 但要誠實：`fingpt_risk` 有 3 個 pre-existing 失敗（記在 `KNOWN_ISSUES.md`，
>    性質是測試沒跟上重構）；`fingpt_panic_rebound` 是 61 passed 全綠。**不要一概說「測試都綠」**
> 2) **Notebook Restart + Run All** 確認可重現
> 3) **機械化前視偏差偵測**——`core/package/data_leakage_detection` 的兩階段驗證：
>    靜態掃描（找 `shift(-N)` / `bfill` / `center` / 全期統計，白名單只有 `path_labels.py`）
>    ＋動態時間一致性測試（把資料源 monkeypatch 成「只到某個截止日」重算，
>    **如果沒偷看未來，重疊區間的值必須完全相同**）。這條寫在 `market-risk/CLAUDE.md`：風險模型上線前**必跑**
> 4) **人工審計**——抽樣跟外部資料源比對（例如跟 FinLab 網頁對指數收盤價）

**Q：你最強的防過擬合手段是什麼？**（有機會就講這題）
> 不是某個統計工具，是**事前登記**。Pack D 那個議題我把規則、判定門檻、
> 甚至「我預期會看到什麼」都在跑第一格程式之前寫進 `plan.md` 凍結，
> hold-out 只開封一次。結果開出來**我沒選的那條規則表現最好，我也沒改去用它**。
>
> 統計工具（purged walk-forward、block bootstrap、FDR）擋的是「運氣被當成效應」；
> **事前登記擋的是「我自己事後合理化」**——後者才是研究者最難防的那一種過擬合。

**Q：這些研究裡有幾個真的成功？**（誠實回答比包裝好）
> 訊號層級只有一個做到完整驗證——恐慌抄底那個（IS+OOS 雙 KEEP + 4 段 WF + 4 次危機 + 25 個參數變體）。
> Pack D 的槓桿守門是 CONDITIONAL（保護有效但保費超標）。
> 其他多數是 PIVOT 或 DISCARD——ETH/台股是檢力失敗、產業輪動 12 輪只留 baseline、
> FinGPT 恐慌指數降格成 overlay。
>
> **我刻意把失敗紀錄留在 repo 裡**，因為在這個領域，
> 「我做了 20 個題目、19 個判失敗」比「我做了 20 個題目、20 個都有效」可信得多。

**Q：怎麼管理這麼多子專案？**
> monorepo + 子專案獨立 CLAUDE.md + taskmaster 任務追蹤 + progress.md 進度日誌。每個子專案有獨立嚴格度——research / market-risk 嚴格（影響交易決策），工具層寬鬆。

**Q：用 AI 寫 code 不會有問題嗎？**
> 會。我搭了一套審查流程——每個 PR 用 AI subagents 跑 bug review、標準審查、架構審查三組平行，未通過不合併。AI 寫的 code 一定要人審，不能盲信。

---

## 面試前最後準備 checklist

### 內容正確性
- [ ] 跑 `scripts/check_facts.sh` —— 數字沒漂移、Mermaid 沒壞
- [ ] 每份流程圖在 IDE（VS Code + Markdown Preview Mermaid Support）能正確渲染
- [ ] README 的聯絡方式 / 履歷佔位符**已填掉或刪掉**

### 口說演練
- [ ] 反覆練習每個 30 秒電梯簡報——錄音聽一次，**超過 35 秒要剪**
- [ ] **每個主題的白板版（§1.0 / §2.0）要能徒手畫出來**——面試最常見的就是「你畫一下」
- [ ] 專有名詞對照表至少讀過 3 遍，重點術語（MAP-Elites / PBO / MAE / Block Bootstrap / FDR / PIVOT /
      事前登記 / CONDITIONAL）要能即時白話解
- [ ] 10 分鐘版本的取捨演練：**只講第二章（事前登記）+ 第四章（雙 KEEP）**

### 記憶點（挑 2~3 個，不要全講）
- [ ] **Pack B 雙 KEEP**：IS n=69 `prob_lift` +13.32% / OOS n=13 / 25 個參數變體全過
- [ ] **Pack D hold-out**：MDD −56.3% → −12.1%（+44.1pp），但少賺一半 → CONDITIONAL
- [ ] **ETH 議題**：事件上限 35、**OOS 獨立事件 4**、RR 階梯 1.79× → 3.87×
- [ ] **GA**：400 代 × 70 個體 / 15 核並行
- [ ] **倉儲**：6 個限速群組、8 個供應方（**不要說 PB 級**）
- [ ] **服務層**：5 profile、48 workflow、9 router

### 高風險追問（一定要演練）
- [ ] 「你的 `n_eff` 是多少」→ **不是 35**，OOS 獨立事件 4
- [ ] 「v1 的 icc 0.36 怎麼算的」→ circular，承認 + 接外部寬度驗證
- [ ] 「hold-out 開出來 R2 最好，為什麼不用」→ 事前登記不得事後改選
- [ ] 「FinGPT 是不是訊號退化了」→ 90% baseline drift，真因是軸契約 OOS 不足
- [ ] 「測試都綠嗎」→ `fingpt_risk` 有 3 個 pre-existing 失敗，主動說明
- [ ] 「年化 100% 是真的嗎」→ 先講五點限制，再把話題導向 market-risk
- [ ] 「plutus_ui 是 Streamlit 嗎」→ **已遷 Next.js（ADR-003）**

### 現場準備
- [ ] 帶筆電可以現場開流程圖檔，被問細節直接展示
- [ ] ⚠️ 若要現場開 GA 程式碼：**開 `Finlab_/jupyter/strategy/pakage/GA_v3/`，不是 notebook**
      （notebook 只有 3 個 cell：import / `get_position` / `config`）
