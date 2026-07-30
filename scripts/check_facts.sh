#!/usr/bin/env bash
# check_facts.sh — 驗證文件裡的數字是否仍與 Plutus 原始碼一致，
#                  並檢查 Mermaid 語法、相對連結、過期用語與 repo 衛生。
#
# 用法：
#   ./scripts/check_facts.sh                 # 全部檢查（靜態）
#   ./scripts/check_facts.sh --mermaid-only  # 只檢查 Mermaid（不需要 Plutus）
#   ./scripts/check_facts.sh --render        # 額外用 mermaid-cli 真的渲染每張圖（較慢，需 npx）
#   PLUTUS=/path/to/Plutus ./scripts/check_facts.sh
#
# 離開碼：0 = 全部通過；1 = 有不一致

set -uo pipefail

PLUTUS="${PLUTUS:-/home/user/Desktop/Plutus}"
FINLAB="${FINLAB:-/home/user/Desktop/Finlab_}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
SKIP=0

c_ok=$'\033[32m'; c_bad=$'\033[31m'; c_warn=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
[ -t 1 ] || { c_ok=""; c_bad=""; c_warn=""; c_dim=""; c_off=""; }

ok()   { printf '  %sPASS%s  %s\n' "$c_ok" "$c_off" "$1"; PASS=$((PASS+1)); }
bad()  { printf '  %sFAIL%s  %s\n' "$c_bad" "$c_off" "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  %sSKIP%s  %s\n' "$c_warn" "$c_off" "$1"; SKIP=$((SKIP+1)); }
head_() { printf '\n%s\n' "$1"; }

# expect <描述> <期望值> <實際值>
expect() {
  local desc="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    ok "$desc = $got"
  else
    bad "$desc：文件寫 $want，實查是 ${got:-<空>}"
  fi
}

# grep_has <描述> <檔案> <pattern>
grep_has() {
  local desc="$1" file="$2" pat="$3"
  if [ ! -f "$file" ]; then skip "$desc（找不到 $file）"; return; fi
  if grep -qE "$pat" "$file"; then ok "$desc"; else bad "$desc（在 $(basename "$file") 找不到 /$pat/）"; fi
}

MERMAID_ONLY=0
DO_RENDER=0
for a in "$@"; do
  [ "$a" = "--mermaid-only" ] && MERMAID_ONLY=1
  [ "$a" = "--render" ] && DO_RENDER=1
done

# ─────────────────────────────────────────────────────────────
head_ "▸ Mermaid 靜態檢查（class / ::: 是否引用未定義的節點或 classDef）"

python3 - "$REPO" <<'PY'
import re, sys, glob, os
repo = sys.argv[1]
files = sorted(glob.glob(os.path.join(repo, 'flowcharts', '**', '*.md'), recursive=True))
files += [os.path.join(repo, 'README.md')]
problems = 0
blocks_checked = 0
for f in files:
    if not os.path.exists(f):
        continue
    txt = open(f, encoding='utf-8').read()
    for bi, b in enumerate(re.findall(r'```mermaid\n(.*?)```', txt, re.S), 1):
        blocks_checked += 1
        declared = set(re.findall(r'(?:^|\s|>|-)([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[|\(|\{)', b))
        declared |= set(re.findall(r'subgraph\s+([A-Za-z_][A-Za-z0-9_]*)', b))
        declared |= set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*(?:-->|-\.|--)', b))
        declared |= set(re.findall(r'(?:-->|\.->|--)\s*\|?[^|]*\|?\s*([A-Za-z_][A-Za-z0-9_]*)', b))
        classdefs = set(re.findall(r'classDef\s+([A-Za-z_][A-Za-z0-9_]*)', b))
        found = []
        for stmt in re.findall(r'^\s*class\s+([^;\n]+)', b, re.M):
            parts = stmt.strip().rstrip(';').split()
            if len(parts) < 2:
                continue
            ids, cls = parts[0].split(','), parts[-1]
            if cls not in classdefs:
                found.append(f'class 指向未定義的 classDef "{cls}"')
            for i in ids:
                i = i.strip()
                if i and i not in declared:
                    found.append(f'class 指向未定義的節點 "{i}"')
        for m in re.findall(r':::([A-Za-z_][A-Za-z0-9_]*)', b):
            if m not in classdefs:
                found.append(f'::: 指向未定義的 classDef "{m}"')
        for p in sorted(set(found)):
            print(f'  \033[31mFAIL\033[0m  {os.path.relpath(f, repo)} 圖{bi}：{p}')
            problems += 1
if problems == 0:
    print(f'  \033[32mPASS\033[0m  {blocks_checked} 個 Mermaid 區塊，class/::: 引用全部有定義')
sys.exit(1 if problems else 0)
PY
if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ─────────────────────────────────────────────────────────────
if [ "$DO_RENDER" = "1" ]; then
  head_ "▸ Mermaid 實際渲染（mermaid-cli；靜態檢查抓不到的語法錯誤靠這關）"
  TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
  n_extracted=$(python3 - "$REPO" "$TMPD" <<'PY'
import re, sys, glob, os
repo, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(repo, 'flowcharts', '**', '*.md'), recursive=True))
files += [os.path.join(repo, 'README.md'), os.path.join(repo, 'backtest_reports', 'README.md')]
n = 0
for f in files:
    if not os.path.exists(f):
        continue
    rel = os.path.relpath(f, repo).replace('/', '_').replace('.md', '')
    for bi, b in enumerate(re.findall(r'```mermaid\n(.*?)```', open(f, encoding='utf-8').read(), re.S), 1):
        open(os.path.join(out, f'{rel}_fig{bi}.mmd'), 'w', encoding='utf-8').write(b)
        n += 1
print(n)
PY
)
  printf '  %s抽出 %s 張圖，逐張渲染中（每張約 2-4 秒）…%s\n' "$c_dim" "$n_extracted" "$c_off"
  printf '%s\n' '{"args":["--no-sandbox","--disable-setuid-sandbox","--disable-dev-shm-usage"]}' > "$TMPD/pconf.json"
  r_ok=0; r_bad=0
  for m in "$TMPD"/*.mmd; do
    if timeout 120 npx -y @mermaid-js/mermaid-cli@latest -p "$TMPD/pconf.json" -i "$m" -o "$TMPD/o.svg" >/dev/null 2>"$TMPD/e.txt"; then
      r_ok=$((r_ok+1))
    else
      r_bad=$((r_bad+1))
      bad "渲染失敗：$(basename "$m" .mmd)"
      grep -iE 'Parse error|Expecting' "$TMPD/e.txt" | head -2 | sed 's/^/         /'
    fi
  done
  [ "$r_bad" -eq 0 ] && ok "$r_ok 張圖全部渲染成功"
fi

head_ "▸ 相對連結存在性"

python3 - "$REPO" <<'PY'
import re, sys, os, glob
repo = sys.argv[1]
bad = 0
checked = 0
for f in glob.glob(os.path.join(repo, '**', '*.md'), recursive=True):
    if '/.git/' in f:
        continue
    base = os.path.dirname(f)
    txt = open(f, encoding='utf-8').read()
    for link in re.findall(r'\]\(([^)#?]+?)(?:#[^)]*)?\)', txt):
        if re.match(r'^(https?:|mailto:|#)', link):
            continue
        link = link.strip()
        if not link or link.startswith('<'):
            continue
        checked += 1
        target = os.path.normpath(os.path.join(base, link))
        if not os.path.exists(target):
            print(f'  \033[31mFAIL\033[0m  {os.path.relpath(f, repo)} → {link}（不存在）')
            bad += 1
if bad == 0:
    print(f'  \033[32mPASS\033[0m  {checked} 個相對連結全部存在')
sys.exit(1 if bad else 0)
PY
if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ─────────────────────────────────────────────────────────────
head_ "▸ 過期用語掃描（曾經寫錯、不該再出現的說法）"

stale_check() { # <描述> <pattern> [排除檔案的 grep -v pattern]
  local desc="$1" pat="$2"
  local hits
  hits=$(grep -rnE "$pat" "$REPO"/README.md "$REPO"/flowcharts "$REPO"/backtest_reports/README.md 2>/dev/null \
         | grep -vE '_INTERVIEW_BRIEFING\.md' || true)
  if [ -z "$hits" ]; then
    ok "$desc"
  else
    bad "$desc"
    printf '%s%s%s\n' "$c_dim" "$(echo "$hits" | sed 's/^/         /')" "$c_off"
  fi
}

# 這些字樣只允許出現在「明確標示為已修正／地雷提醒」的檔案裡
stale_check "無殘留 'Streamlit Portal' 描述"        'Streamlit Portal|Streamlit 視覺化|plutus_ui 是 Streamlit'
stale_check "無殘留 'Page 6' 頁碼語彙"              'Page 6'
stale_check "無殘留 'PB 級' 資料量誤述"             'PB 級'
stale_check "無殘留 'DeepSeek' 作為演化 LLM"        'DeepSeek'
stale_check "無殘留 '39 個 workflow'"               '39 (個 )?workflow|workflow（39|39 個 workflow'
stale_check "無殘留 'docs/flowcharts/' 路徑"        'docs/flowcharts/'

# ─────────────────────────────────────────────────────────────
if [ "$MERMAID_ONLY" = "1" ]; then
  head_ "（--mermaid-only：略過 Plutus 事實比對）"
else
  head_ "▸ services 層事實比對"
  if [ ! -d "$PLUTUS" ]; then
    skip "找不到 Plutus（$PLUTUS）——設 PLUTUS=... 或用 --mermaid-only"
  else
    expect "n8n workflow 總數" 48 "$(find "$PLUTUS/services/n8n/workflows" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    expect "n8n hermes/"       25 "$(find "$PLUTUS/services/n8n/workflows/hermes" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    expect "n8n risk/"         18 "$(find "$PLUTUS/services/n8n/workflows/risk"   -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    expect "n8n system/"        4 "$(find "$PLUTUS/services/n8n/workflows/system" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
    expect "data-api 註冊 router 數" 9 "$(grep -c 'include_router' "$PLUTUS/services/data-api/app/main.py" 2>/dev/null | tr -d ' ')"
    expect "data-api reader 數" 5 "$(ls "$PLUTUS/services/data-api/app/readers/" 2>/dev/null | grep -E '\.py$' | grep -v '^__' | wc -l | tr -d ' ')"

    grep_has "Hermes 全域 default = MiniMax-M3"  "$PLUTUS/services/hermes/config.yaml" 'default: *"?MiniMax-M3'
    grep_has "Hermes fallback = glm-4.5"         "$PLUTUS/services/hermes/config.yaml" 'model: *glm-4\.5'
    grep_has "Hermes 維運 profile = glm-5.2"     "$PLUTUS/services/hermes/README.md"   'glm-5\.2'
    grep_has "plutus_ui 前端 = Next.js"          "$PLUTUS/plutus_ui/web/package.json"  '"next":'
    if grep -qE 'include_router\(\s*etf_bh_metrics' "$PLUTUS/services/data-api/app/main.py" 2>/dev/null; then
      bad "etf_bh_metrics 已被註冊 → services.md §四 需更新"
    else
      ok "etf_bh_metrics 仍未註冊（與文件一致）"
    fi

    head_ "▸ datawarehouse 事實比對"
    expect "SOURCE_CONFIG 限速群組數" 6 \
      "$(python3 -c "
import re,sys
p='$PLUTUS/datawarehouse/src/bulk_downloader/constants.py'
t=open(p,encoding='utf-8').read()
m=re.search(r'SOURCE_CONFIG.*?=\s*\{(.*?)\n\}', t, re.S)
print(len(re.findall(r'^\s{4}\"([a-z_]+)\":\s*\{', m.group(1), re.M)) if m else 0)
" 2>/dev/null)"
    grep_has "IP_BAN_COOLDOWN_SECONDS = 2100" "$PLUTUS/datawarehouse/src/bulk_downloader/constants.py" 'IP_BAN_COOLDOWN_SECONDS.*2100'
    grep_has "krx 限速 1800"                   "$PLUTUS/datawarehouse/src/bulk_downloader/constants.py" 'rate_limit.*1800'
    grep_has "_PHASE12_KRX_APIS 存在"          "$PLUTUS/datawarehouse/src/bulk_downloader/registry.py"  '_PHASE12_KRX_APIS'

    head_ "▸ market-risk 事實比對"
    grep_has "DEFAULT_SEVERITY_THRESHOLDS = (-0.03, -0.05, -0.08)" \
      "$PLUTUS/market-risk/src/market_risk_common/path_labels.py" '\(-0\.03, *-0\.05, *-0\.08\)'
    expect "auxiliary_signal 子模組數" 7 \
      "$(find "$PLUTUS/market-risk/analyses/auxiliary_signal" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    for fn in purged_walk_forward episode_ids n_eff episode_block_bootstrap probability_lift fisher_lift_test bh_fdr; do
      grep_has "validation.py 有 $fn()" "$PLUTUS/market-risk/src/market_risk_common/validation.py" "^def $fn"
    done
    grep_has "leakage detector 有 check_future_data_leakage()" \
      "$PLUTUS/core/package/data_leakage_detection/detector.py" '^def check_future_data_leakage'

    head_ "▸ industry_rotation gate 門檻"
    IRR="$PLUTUS/market-risk/analyses/auxiliary_signal/industry_rotation_risk"
    grep_has "gate state_icc >= 0.30"   "$IRR/scripts/autoresearch_v2.py" "state_icc_ge_0\.30.*>= *0\.30"
    grep_has "gate sign_flip <= 0.05"   "$IRR/scripts/autoresearch_v2.py" "sign_flip_le_0\.05"
    grep_has "gate lag1 in [0.55,0.85]" "$IRR/scripts/autoresearch_v2.py" "0\.55 *<= *lag1 *<= *0\.85"
    grep_has "gate switch <= 12"        "$IRR/scripts/autoresearch_v2.py" "switch_le_12"
    grep_has "KEEP = gate_pass>=3 AND icc" "$IRR/scripts/autoresearch_v2.py" "gate_pass *>= *3 *and"
    grep_has "cmoney 37 集團"            "$IRR/scripts/cmoney_data.py" "37 groups"

    head_ "▸ GA 引擎位置（追溯正確性）"
    if [ -d "$FINLAB/jupyter/strategy/pakage/GA_v3" ]; then
      ok "GA_v3 引擎存在於 Finlab_/jupyter/strategy/pakage/GA_v3"
    else
      bad "找不到 GA 引擎 package（Finlab_/jupyter/strategy/pakage/GA_v3）"
    fi
    expect "ga_yoy_v1.ipynb cell 數" 3 \
      "$(python3 -c "
import json;print(len(json.load(open('$FINLAB/jupyter/strategy/GA/deap/ga_yoy_v1.ipynb'))['cells']))
" 2>/dev/null)"

    head_ "▸ Pack B / Pack D 模組存在性"
    [ -f "$PLUTUS/market-risk/analyses/bottom_dip/fingpt_panic_rebound/README.md" ] \
      && ok "Pack B fingpt_panic_rebound 存在" || bad "Pack B 模組不存在"
    [ -f "$PLUTUS/market-risk/analyses/leverage_guard_overlay/plan.md" ] \
      && ok "Pack D leverage_guard_overlay 事前登記 plan.md 存在" || bad "Pack D plan.md 不存在"
    expect "Pack D version 階段數" 4 \
      "$(find "$PLUTUS/market-risk/analyses/leverage_guard_overlay/versions" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  fi
fi

# ─────────────────────────────────────────────────────────────
head_ "▸ repo 衛生"
if git -C "$REPO" ls-files --error-unmatch backtest_reports/_run_all.log >/dev/null 2>&1; then
  bad "log 檔仍被追蹤（backtest_reports/_run_*.log）"
else
  ok "log 檔未被追蹤"
fi
[ -f "$REPO/.gitignore" ] && ok ".gitignore 存在" || bad ".gitignore 不存在"
if grep -qE '\[你的|\[請填入' "$REPO/README.md" 2>/dev/null; then
  # 這是待辦事項，不是事實錯誤——記為 SKIP 以免蓋掉真正的 FAIL
  skip "README 仍有未填的佔位符（聯絡方式 / 履歷）——推上公開 repo 前要處理"
else
  ok "README 無未填佔位符"
fi

# ─────────────────────────────────────────────────────────────
printf '\n────────────────────────────────────────\n'
printf '  %sPASS %d%s   %sFAIL %d%s   %sSKIP %d%s\n' \
  "$c_ok" "$PASS" "$c_off" "$c_bad" "$FAIL" "$c_off" "$c_warn" "$SKIP" "$c_off"
printf '────────────────────────────────────────\n'
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
