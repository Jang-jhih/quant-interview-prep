# 產業輪動風險監控 — 流程圖

> 履歷用途：以流程圖呈現「cmoney 37 集團 × TSE/OTC 個股 → rotation_intensity + theme_strength 雙指標 → 1-5 風險分數 → Discord 通知 + UI snapshot」的完整產線；同時記錄 **12 輪 autoresearch** 中 1 個 baseline KEEP + 11 個 DISCARD 的迭代紀律，以及 v8/v9 之間形成的 Pareto 邊界。

> 父架構見 [`../market_risk.md`](../market_risk.md) §二「Pack C · auxiliary_signal」。本圖為 Pack C 底下其中一個獨立研究專案。

> ⚠️ **不要跟 `research/market-analysis/theme_industry_correlation/` 搞混**——那是學術式 5760 組歷史回測（毛 Sharpe 0.80 → 淨 -2.31）；本模組是**生產即時監控**（每日排程 + Discord 通知）。

---

## 一、模組定位

| 項目 | 內容 |
|---|---|
| **核心假設** | 資金在產業間快速輪動（Rotation Intensity ↑）且缺乏明確主線（Theme Strength ↓）時，市場波動加劇 |
| **議題角色** | **市場狀態描述器**（不是漲跌預測訊號）—— 高風險分數代表「主線不明、產業分歧擴大」的環境，**不是**「大盤要跌」|
| **資料來源** | `/home/work/core/cmoney_concepts.json`（集團股分類）+ warehouse TSE/OTC close parquet |
| **生產指標** | `rotation_intensity`（10 日 Z-score）、`theme_strength`（10 日 Z-score）、綜合 `risk_score ∈ [1, 5]` |
| **驗證主軸** | Pack C auxiliary：`state_icc ≥ 0.30`、`sign_flip_ratio ≤ 0.05`、`lag1_autocorr ∈ [0.55, 0.85]`、`switch_per_Q ≤ 12` |
| **迭代紀律** | **12 輪 autoresearch**：1 baseline KEEP + 11 DISCARD，v8/v9 形成 Pareto 邊界 |
| **每日入口** | n8n trigger `/api/research/run_daily/industry_rotation_risk` → `scripts/run_daily.py` |
| **下游通知** | Discord webhook（4 色：綠 / 黃 / 橘 / 紅）+ Plotly gauge PNG + UI snapshot |

> 📖 **讀法**：想快速理解看 **§2.0 白板版**（≤7 個框）；想看細節往下讀。標示 `>` 引言與「地雷 / 講法」的區塊是作者自己的面試準備筆記，**可直接略過**。

---

## 二、整體 Pipeline（cmoney → indicator → score → Discord）

### 2.0 白板版

> 5 個框。口訣：**集團日報酬 → 兩條指標（輪動多亂 / 主線多穩）→ Z-score → 四個觸發加總 → 1-5 分。**

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','fontSize':'14px'}}}%%
flowchart LR
    G["cmoney 37 集團<br/>等權日報酬"]
    R["rotation_intensity<br/>(越高越亂)"]
    T["theme_strength<br/>(越低越沒主線)"]
    Z["252d Z-score<br/>min_periods=60"]
    S["risk_score 1-5<br/>4 個觸發加總"]

    G --> R --> Z
    G --> T --> Z
    Z --> S

    classDef src fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66;
    classDef calc fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14;
    classDef out fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488;
    class G src;
    class R,T,Z calc;
    class S out;
```

### 2.1 細節版

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart LR
    classDef source fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef warehouse fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef compute fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef compose fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef output fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    CM["cmoney_concepts.json<br/>group='集團股'<br/>37 集團 / 248 檔"]:::source
    TSE["TSE close parquet<br/>/finlab_price/_market/all.parquet"]:::warehouse
    OTC["OTC close parquet<br/>/finlab_rotc_price/_market/all.parquet"]:::warehouse
    WIDE["load_close_wide()<br/>pivot → [date × stock]"]:::compute
    GROUP["compute_group_mean_return<br/>equal-weight per 集團"]:::compute

    subgraph IND["雙指標（10d window）"]
        direction TB
        RI["rotation_intensity<br/>= diff().abs().mean(axis=1)<br/>.rolling(10).mean()"]:::compute
        TS["theme_strength<br/>= (top3_pct × 0.5<br/>+ (1-leader_pct) × 0.5) × 100"]:::compute
    end

    CACHE[("data/indicators.parquet<br/>cache")]:::warehouse
    Z["calculate_z_score(window=252<br/>min_periods=60)"]:::compute
    SCORE["calc_risk_score(z_rot, z_theme)<br/>= 1 + (z_rot>0.5) + (z_rot>1.5)<br/>+ (z_theme<-0.5) + (z_theme<-1.5)<br/>clip(1, 5)"]:::compose
    ACTION["get_action_suggestion(score)<br/>3 分支查表"]:::compose
    ASSESS["RotationRiskAssessment dataclass"]:::compose
    REPORT["report.create_gauge_figure()<br/>→ Plotly gauge PNG"]:::output
    DISC["send_to_discord()<br/>4 色 embed"]:::output
    UI["export_ui_snapshot()<br/>→ results/ui/history.csv"]:::output

    CM --> WIDE
    TSE --> WIDE
    OTC --> WIDE
    WIDE --> GROUP --> IND
    IND --> CACHE
    CACHE --> Z --> SCORE --> ACTION --> ASSESS
    ASSESS --> REPORT --> DISC
    ASSESS --> UI

    class CM source
    class TSE,OTC,CACHE warehouse
    class WIDE,GROUP,RI,TS,Z compute
    class SCORE,ACTION,ASSESS compose
    class REPORT,DISC,UI output
```

---

## 三、資料載入（cmoney 37 集團 + 雙市場）

> 從兩個來源組出「集團 → 成員」映射與 wide 收盤表，多歸屬語意：**同一檔股票可屬於多個集團**。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef source fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef transform fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef warehouse fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef decision fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00

    JSON["/home/work/core/cmoney_concepts.json<br/>d['concepts'][cid]['group']<br/>∈ {集團股, 產業, 概念股}<br/>['stocks'] = list of stock_ids"]:::source
    FILTER["CMONEY_GROUP = '集團股'<br/>→ 篩出 37 集團 / 248 檔"]:::decision
    TSE["TSE close<br/>/data_g/warehouse/<br/>finlab_price/_market/all.parquet<br/>cols: date, stock_id, close"]:::warehouse
    OTC["OTC close<br/>/data_g/warehouse/<br/>finlab_rotc_price/_market/all.parquet"]:::warehouse
    CONCAT["concat + pivot<br/>load_close_wide()<br/>→ [date × stock]"]:::transform
    MAP["load_cmoney_groups()<br/>→ dict[group → [stock_ids]]"]:::transform

    JSON --> FILTER --> MAP
    TSE --> CONCAT
    OTC --> CONCAT
    CONCAT --> GRPMEAN

    subgraph GRPMEAN["compute_group_mean_return  (cmoney_data.py:107-133)"]
        direction TB
        RET["returns = close_wide.pct_change<br/>(fill_method=None)"]:::transform
        MEAN["each group →<br/>equal-weight mean (skipna)"]:::transform
        MULTI["multi-membership:<br/>same stock 可在 N 個集團<br/>都被計算"]:::transform
        RET --> MEAN --> MULTI
    end

    class JSON source
    class TSE,OTC warehouse
    class FILTER decision
    class CONCAT,MAP,RET,MEAN,MULTI transform
```

**面試亮點**

- **集團分類的選擇**：從原本 FinLab 46 產業（v1）改為 cmoney 37 集團（v2），`external icc` 提升 **2.9×**（`notes/cmoney_classification_test/`）
- **`pct_change(fill_method=None)`**：明確禁用 pandas 預設的 forward-fill，避免停牌日假造報酬

---

## 四、雙指標計算（rotation_intensity + theme_strength）

> 兩條指標都用 `window=10`，但**公式語意相反**——rotation 看「輪動劇烈程度」（越大越亂），theme 看「主線穩定程度」（越大越有序）。組合兩條才看得出「無主線的高輪動」這個風險狀態。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef input fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef compute fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef intermediate fill:#d6e8ff,stroke:#002b66,stroke-width:1.5px,color:#002b66
    classDef output fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    GRP["group_ret DataFrame<br/>(compute_group_mean_return 結果)"]:::input

    subgraph RI["compute_rotation_intensity  (cmoney_data.py:136-154)"]
        direction TB
        D["group_ret.diff().abs()<br/>每集團日報酬差的絕對值"]:::compute
        DM[".mean(axis=1)<br/>跨集團當日平均變動"]:::compute
        RM[".rolling(10).mean()<br/>10 日平滑"]:::compute
        D --> DM --> RM
    end

    subgraph TS["compute_theme_strength  (cmoney_data.py:181-214)"]
        direction TB
        ABS["abs_ret = |group_ret|"]:::compute
        TOP3["top3_share =<br/>abs_ret.apply(<br/>  x.nlargest(3).sum())"]:::compute
        LEADER["top_industry =<br/>每日報酬最強集團"]:::intermediate
        FREQ["leader_freq =<br/>(top_industry ≠ shift1)<br/>.rolling(10).sum()<br/>10 日內主線換幾次"]:::compute
        RANK3["top3_pct =<br/>_rolling_pct_rank(<br/>  top3_share, 252, 60)"]:::compute
        RANKL["leader_pct =<br/>_rolling_pct_rank(<br/>  leader_freq, 252, 60)"]:::compute
        COMB["output =<br/>(top3_pct × 0.5<br/>+ (1 - leader_pct) × 0.5) × 100"]:::compute
        ABS --> TOP3 --> RANK3
        ABS --> LEADER --> FREQ --> RANKL
        RANK3 --> COMB
        RANKL --> COMB
    end

    OUT["DataFrame:<br/>{rotation_intensity, theme_strength}<br/>via compute_industry_rotation() :217"]:::output

    GRP --> RI
    GRP --> TS
    RI --> OUT
    TS --> OUT

    class GRP input
    class D,DM,RM,ABS,TOP3,FREQ,RANK3,RANKL,COMB compute
    class LEADER intermediate
    class OUT output
```

**`_rolling_pct_rank` 公式（cmoney_data.py:157-178）**

```
滾動窗口 252 天 / min_periods=60
rank = (x.iloc[-1] > x[:-1]).mean()
```

→ **lookback-only percentile**，無 lookahead bias。

**指標語意對照**

| 指標 | 高值代表 | 數學直覺 |
|---|---|---|
| `rotation_intensity` | 集團報酬變動大、輪動快 | 投資人共識換邊站 |
| `theme_strength` | top3 集團穩定、換主線次數少 | 市場有明確主線 |

→ 風險狀態 = **高 rotation + 低 theme** = 沒人帶頭但大家在亂跑。

---

## 五、風險分數組裝（1-5 + 4 色通知）

> `risk_score` 用 4 個獨立 if 觸發加總，最後 `clip(1, 5)`——不是連續函數，是**離散階梯**，方便下游 rule-based 決策與 Discord 視覺。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef input fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef trigger fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef compose fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef tier fill:#e0ccff,stroke:#3a1488,stroke-width:2px,color:#3a1488

    ZR["z_rotation<br/>(252d Z-score, min_periods=60)"]:::input
    ZT["z_theme"]:::input

    T1["+(z_rotation > 0.5)"]:::trigger
    T2["+(z_rotation > 1.5)"]:::trigger
    T3["+(z_theme < -0.5)"]:::trigger
    T4["+(z_theme < -1.5)"]:::trigger

    SUM["score = 1 + T1 + T2 + T3 + T4<br/>clip(1, 5)<br/>(indicators.py:86-109)"]:::compose
    ACTION["get_action_suggestion(score)<br/>3 分支查表<br/>(indicators.py:375-394)"]:::compose
    ASSESS["RotationRiskAssessment dataclass<br/>(assess.py:25-38)"]:::compose

    L12["score 1-2 · 低風險<br/>Discord 0x2ECC40 綠"]:::tier
    L3["score 3 · 中風險<br/>Discord 0xFFDC00 黃"]:::tier
    L4["score 4 · 高風險<br/>Discord 0xFF851B 橘"]:::tier
    L5["score 5 · 極高風險<br/>Discord 0xFF4136 紅"]:::tier

    ZR --> T1
    ZR --> T2
    ZT --> T3
    ZT --> T4
    T1 --> SUM
    T2 --> SUM
    T3 --> SUM
    T4 --> SUM
    SUM --> ACTION --> ASSESS
    ASSESS --> L12
    ASSESS --> L3
    ASSESS --> L4
    ASSESS --> L5

    class ZR,ZT input
    class T1,T2,T3,T4 trigger
    class SUM,ACTION,ASSESS compose
    class L12,L3,L4,L5 tier
```

**面試亮點**

- **離散階梯而非連續**：4 個 boolean trigger 加總 → 易於 rule-based downstream 與人類解讀
- **不對稱軸**：rotation 用 `> 0.5 / > 1.5`（高於平均）；theme 用 `< -0.5 / < -1.5`（低於平均）—— 反映「高輪動 + 弱主線」風險本質
- **v1 鎖定值**（2026-07-01）：score=4/5 高風險、Z_rot=+1.57、Z_theme=-1.08

---

## 六、12 輪 autoresearch 迭代歷程（v1 KEEP + 11 DISCARD）

> 每一輪嘗試一個機制改良（median 平滑、min_periods、hysteresis、cooldown），全部必須過 Pack C gate 才能KEEP；**只有 v1 baseline 過得了**，其餘 11 輪全 DISCARD。v8/v9 之間形成 Pareto 邊界——icc 跟 switch_per_Q 無法同時優化。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef phase fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef keep fill:#e1f5e1,stroke:#145a14,stroke-width:2px,color:#145a14
    classDef discard fill:#ffe1e1,stroke:#7a0000,stroke-width:1.5px,color:#7a0000
    classDef pareto fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef invalid fill:#eeeeee,stroke:#666,stroke-width:1px,color:#1a1a1a

    subgraph P0["Phase 0 · baseline"]
        V1["v1 · baseline<br/>state_icc=0.3585<br/>switch/Q=22.62<br/>→ KEEP"]:::keep
    end

    subgraph P1["Phase 1 · 參數微調 (v2-v5)"]
        direction TB
        V2["v2 · smooth_window=5<br/>icc=0.1983 switch=7.66<br/>DISCARD (icc 失守, lag1=0.92)"]:::discard
        V3["v3 · smooth_window=3<br/>icc=0.2619 switch=12.12<br/>DISCARD (icc<0.30)"]:::discard
        V4["v4 · min_periods=120<br/>icc=0.2864 switch=17.18<br/>DISCARD (差 0.0136)"]:::discard
        V5["v5 · min_periods=180<br/>icc=0.1541 switch=13.23<br/>DISCARD (icc 崩壞)"]:::discard
    end

    subgraph P2["Phase 2 · 機制層 (v6-v11)"]
        direction TB
        V6["v6 · hysteresis_up(cd=2)<br/>icc=0.21 switch=9.27<br/>DISCARD (extreme=1.46%)"]:::discard
        V7["v7 · hysteresis_both(cd=2)<br/>icc=0.23 switch=6.68<br/>DISCARD"]:::discard
        V8["v8 · cooldown(cd=1)<br/>icc=0.31 switch=15.58<br/>DISCARD (switch 未過)<br/>★ Pareto 邊界左點"]:::pareto
        V9["v9 · cooldown(cd=2)<br/>icc=0.26 switch=11.62<br/>DISCARD (icc 未過)<br/>★ Pareto 邊界右點"]:::pareto
        V10["v10 · cooldown_upward(cd=1)<br/>icc=0.30 switch=18.30<br/>DISCARD"]:::discard
        V11["v11 · cooldown_upward(cd=2)<br/>icc=0.23 switch=15.08<br/>DISCARD"]:::discard
    end

    subgraph P3["Phase 3 · 評估嘗試 (v12)"]
        direction TB
        V12["v12 · state_var=rotation_raw<br/>icc=0.73<br/>★ 無效評估 (circular:<br/>用衍生指標當 state_var)"]:::invalid
    end

    CONCL["結論: v1 baseline 為<br/>Pareto 最優解<br/>(versions/v1_baseline/README.md L46-58)"]:::keep

    V1 --> P1
    P1 --> P2
    P2 --> P3
    P3 --> CONCL

    class P0,P1,P2,P3 phase
    class V1,CONCL keep
    class V2,V3,V4,V5,V6,V7,V10,V11 discard
    class V8,V9 pareto
    class V12 invalid
```

**面試必講 — Pareto 邊界的故事**

| 版本 | icc | switch/Q | 結果 |
|---|---|---|---|
| **v8** | **0.31 ✅** | 15.58 ❌ | icc 過、switch 沒過 |
| **v9** | 0.26 ❌ | **11.62 ✅** | switch 過、icc 沒過 |

→ 兩個版本各過一個 gate，沒有任何候選能同時滿足——這就是「真實研究中 gate 互相拉扯」的教科書案例。

### 🚨 這張圖有一個必須自己先講清楚的前提

上圖 v1–v12 的 `state_icc` **全部是用 `theme_strength` 當 state variable 算出來的**，
而 `theme_strength` 本身就出現在 score 公式裡（見 §七 circular trap）。所以：

| | 結論 |
|---|---|
| **絕對值** | **不可信**。v1 的 0.3585 換成真正外部的 `twii_vol` 重算只有 **0.038** |
| **相對排序** | **仍然有效**。12 輪用的是**同一個**（有偏但一致的）評估函數，所以「v2 比 v1 差」這種比較沒有失效 |
| **「v1 是 Pareto 最優」** | 成立，但語意要限縮成「**在這個內部一致性指標下**，v1 位於邊界」，不是「v1 有 0.36 的外部解釋力」 |
| **外部效力怎麼證** | 另立驗證：8 個台股寬度指標（`scripts/breadth.py`，n=481，8/8 跨期同向，最高 ρ=−0.40）——見 §七 |

> **被追問時的答法**：「12 輪的 icc 都是同一個 circular 指標，所以我用它做**排序**、不用它做**宣稱**。
> 絕對效力我另外用外部寬度指標驗，那組才是我對外的證據。」
>
> ⚠️ 反過來說：**如果對方先問「你的 0.36 是怎麼算的」，就代表他已經看出來了**——
> 這時候要直接承認並馬上接到外部驗證，不要試圖辯護那個數字。

**v1 LOCK 後續狀態（2026-07-01）**

- 評估基準日：2026-07-01
- v1 風險分數：4/5（高風險）
- 歷史資料範圍：2007-04-23 ~ 2026-07-01

---

## 七、Pack C 驗證閘門 + 外部寬度驗證

> Pack C gate 來源是 `scripts/autoresearch_v2.py`（gate dict 約 L243-249）——**注意 README 跟實際 gate 數字不一致**（README 寫 sign_flip ≤30% / lag1 ∈ [0.40, 0.85]，實際是 ≤5% / [0.55, 0.85]）。**以程式碼為準**，這是 README 未同步的舊版門檻。

> **實際 gate（已逐行核對 `autoresearch_v2.py`）**：
> `state_icc_ge_0.30`（≥0.30）、`sign_flip_le_0.05`（≤0.05）、`lag1_in_range`（0.55–0.85）、
> `extreme_in_range`（0.01–0.20）、`switch_le_12`（≤12）；
> **KEEP 規則 = `gate_pass >= 3` AND `state_icc_ge_0.30`**——icc 是必要條件，其餘湊 3 個即可。
> 這也解釋了為什麼 v1 的 `switch_per_Q=22.62` 超標卻仍 KEEP（見下方地雷）。

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#ececec','primaryTextColor':'#1a1a1a','primaryBorderColor':'#666666','lineColor':'#444444','secondaryColor':'#f4f4f4','fontSize':'14px'}}}%%
flowchart TB
    classDef input fill:#fff4d6,stroke:#5c4500,stroke-width:2px,color:#5c4500
    classDef primary fill:#ffe1e1,stroke:#7a0000,stroke-width:2px,color:#7a0000
    classDef guard fill:#fff4d6,stroke:#5c4500,stroke-width:1.5px,color:#5c4500
    classDef decision fill:#ffe8cc,stroke:#8a4a00,stroke-width:2px,color:#8a4a00
    classDef external fill:#d6e8ff,stroke:#002b66,stroke-width:2px,color:#002b66
    classDef warning fill:#eeeeee,stroke:#666,stroke-width:1px,color:#1a1a1a

    SCORE["v1 risk_score"]:::input

    subgraph INTERNAL["內部 gate (autoresearch_v2.py:163-249)"]
        direction TB
        ICC["state_icc<br/>pd.qcut(score,5) → η²<br/>門檻: ≥ 0.30"]:::primary
        SF["sign_flip_ratio<br/>(window=15)<br/>門檻: ≤ 0.05 (5%)"]:::guard
        LAG["lag1_autocorr<br/>門檻: ∈ [0.55, 0.85]"]:::guard
        EXT["extreme_4_5_pct<br/>score≥4 比例<br/>門檻: ∈ [1%, 20%]"]:::guard
        SWITCH["switch_per_Q<br/>n_switches / (len/63)<br/>門檻: ≤ 12"]:::primary
        RULE["KEEP rule:<br/>gate_pass ≥ 3<br/>AND state_icc_ge_0.30"]:::decision
        ICC --> RULE
        SF --> RULE
        LAG --> RULE
        EXT --> RULE
        SWITCH --> RULE
    end

    WARN["⚠️ circular trap<br/>(notes/cmoney_classification_test/findings.md)<br/>v1 README η²=0.36 是用 theme_strength<br/>當 state_var 算的（公式含 theme_raw）<br/>→ 真正外部 twii_vol 重算 η²=0.038"]:::warning

    subgraph EXTVAL["外部驗證 · 市場寬度 (2026-07-13)"]
        direction TB
        TWB["台股 8 指標 (n=481)<br/>above_ma60 ρ=-0.40 (最高)<br/>8/8 跨期同向<br/>63d 翻號比 0.2%-3.3% (全過)"]:::external
        USB["美股 11 指標 (n=463)<br/>跨期同向 0/11<br/>★ RSP/SPY 20d Cohen's d=+0.51<br/>(n=84 vs 379, 中等效果量)"]:::external
        LAG2["lead-lag lag=0/1/2<br/>ρ diff < 0.03<br/>→ 同步性非預測性"]:::external
    end

    CONCL2["結論: v1 是台股內部狀態描述器<br/>跨市場用途需重新設計"]:::decision

    SCORE --> INTERNAL
    SCORE -. "外部對照" .-> EXTVAL
    INTERNAL --> WARN
    WARN --> CONCL2
    EXTVAL --> CONCL2

    class SCORE input
    class ICC,SWITCH primary
    class SF,LAG,EXT guard
    class RULE,CONCL2 decision
    class TWB,USB,LAG2 external
    class WARN warning
```

**面試亮點 — 8 個台股寬度指標**

`ad_ratio`、`pct_advancing`、`above_ma20`、`above_ma60`、`return_dispersion`、`nh_nl_index`、`new_high_ratio`、`new_low_ratio`

**樣本結構的不平衡**

| score | 天數 | 比例 |
|---|---|---|
| 1 | 269 | 55.9% |
| 4 | 12 | 2.5% |
| 5 | 3 | 0.6% |

→ 高風險事件稀少，gate 不能只用平均相關，必須看 `extreme_4_5_pct` 這種分位檢定。

---

---

> 本文件的流程圖採 Mermaid 語法，GitHub / GitLab / Obsidian 原生支援；
> VS Code 需安裝 *Markdown Preview Mermaid Support*。
