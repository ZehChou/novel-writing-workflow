#!/bin/bash
# validate.sh - Phase 3.5/Phase 5 硬校验一键脚本
# 用法:
#   bash scripts/validate.sh {NN}                     # P3.5 全量校验（正文+brief+正典+节奏+伏笔+谜题+爽点+战力+面板）
#   bash scripts/validate.sh {NN} --brief             # 仅 L1 brief 校验
#   bash scripts/validate.sh {NN} --canon             # 仅正典账本校验
#   bash scripts/validate.sh {NN} --chapter           # 仅正文校验
#   bash scripts/validate.sh {NN} --pacing            # 节奏/结尾 + 高潮义务检查
#   bash scripts/validate.sh {NN} --foreshadow        # 伏笔生命周期（逾期检测）
#   bash scripts/validate.sh {NN} --mystery           # 谜题提前泄露/逾期
#   bash scripts/validate.sh {NN} --dedup             # 跨章查重（最近N章 L1 brief）
#   bash scripts/validate.sh {NN} --payoff            # 爽点账本（期待感-兑现配对 + 逾期 + 只设不收）
#   bash scripts/validate.sh {NN} --opening           # 黄金三章专项（仅 Ch1-3 有效）
#   bash scripts/validate.sh {NN} --power             # 战力通胀（回退/升级过快/越级无代价）
#   bash scripts/validate.sh {NN} --panel             # 金手指/系统面板 immutable 一致性
#   bash scripts/validate.sh {NN} --cast              # 配角/反派池（出场频率/反派档案）
#   bash scripts/validate.sh {NN} --pacing --foreshadow --dedup   # 多模式组合
# 在项目根目录下执行。老项目缺对应 jsonl/节奏图谱.md 时对应检查降级 skip，不报错。

NN=$(printf "%02d" "$((10#${1:?用法: bash scripts/validate.sh <章号> [--brief|--canon|--chapter|--pacing|--foreshadow|--mystery|--dedup]...}))")
shift
ROOT=$(pwd)
CANON="$ROOT/追踪/canon"
CUR=$((10#$NN))

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

chk_pass() { PASS=$((PASS+1)); echo -e "  ${GREEN}✓${NC} $1"; }
chk_fail() { FAIL=$((FAIL+1)); echo -e "  ${RED}✗${NC} $1"; }
chk_warn() { WARN=$((WARN+1)); echo -e "  ${YELLOW}⚠${NC} $1"; }

# 从 project-config.md 读配置，缺失用默认值
cfg_val() {
  local key="$1" default="$2" v
  v=$(awk -F "：" '/^[[:space:]]*- '"$key"'：/{sub(/^[[:space:]]*- /,""); sub(/^[^：]+：/,""); print; exit}' "$ROOT/project-config.md" 2>/dev/null)
  echo "${v:-$default}"
}
# 从配置值提取首个整数（兼容带括号注释的值，如 "5（说明）"）
num_val() {
  local key="$1" default="$2" v n
  v=$(cfg_val "$key" "$default")
  n=$(echo "$v" | grep -oE "[0-9]+" | head -1)
  echo "${n:-$default}"
}
# 读取主角名（从 project-config.md 第6节）
protagonist_name() {
  local v
  v=$(awk '/^## 6\. 关键实体名称/{found=1; next} found && /^## /{exit} found && /主角名/{sub(/^[[:space:]]*- *主角名：/,""); print; exit}' "$ROOT/project-config.md" 2>/dev/null)
  echo "${v:-主角}"
}
# 读取关键术语（从 project-config.md 各配置项汇总）
key_terms_pattern() {
  local protagonist terms
  protagonist=$(protagonist_name)
  terms=$(cfg_val 关键术语 "")
  if [ -n "$terms" ]; then
    echo "${protagonist}|${terms}"
  else
    echo "${protagonist}"
  fi
}

SMALL_CYCLE=$(num_val 小高潮周期 3)
BIG_CYCLE=$(num_val 大高潮周期 10)
OVERDUE=$(num_val 伏笔逾期阈值 5)
DEDUP_N=$(num_val 跨章查重回看章数 3)
PAYOFF_OVERDUE=$(num_val 爽点逾期阈值 8)
CAST_IDLE=$(num_val 配角闲置阈值 15)
POWER_DOUBLE=$(num_val 战力翻倍预警章数 5)
PROTAGONIST=$(protagonist_name)
KEY_TERMS=$(key_terms_pattern)
# Python 解释器探测（跨平台：python3 / python 均可）
PY="python"
command -v python3 >/dev/null 2>&1 && PY="python3"
# 强制 UTF-8 输出，避免 Windows GBK 控制台下 print ⚠/✗ 报 UnicodeEncodeError
export PYTHONIOENCODING=utf-8

find_chapter_file() {
  local f
  for f in "$ROOT/正文/${NN}_"*.md; do
    [ -f "$f" ] && [[ ! "$f" == *".归档.md" ]] && { echo "$f"; return; }
  done
  for f in "$ROOT/正文/${NN}_"*.归档.md; do
    [ -f "$f" ] && { echo "$f"; return; }
  done
  echo ""
}

find_brief_file() {
  local f
  for f in "$ROOT/正文/摘要/${NN}_"*.brief.md; do
    [ -f "$f" ] && { echo "$f"; return; }
  done
  echo ""
}

# 列出最近 N 章的 L1 brief 文件路径（排除当前章）
find_recent_briefs() {
  local n="$1" i fnum
  for ((i=1; i<=n; i++)); do
    fnum=$(printf "%02d" $((CUR - i)))
    [ "$fnum" = "00" ] && continue
    [ "$((CUR - i))" -le 0 ] && continue
    for f in "$ROOT/正文/摘要/${fnum}_"*.brief.md; do
      [ -f "$f" ] && echo "$f"
    done
  done
}

# ============================================================
# 正文校验
# ============================================================
validate_chapter() {
  local file="$1"
  local fname; fname=$(basename "$file")
  echo ""; echo "═══════════════════════════════════════════"
  echo " 正文校验: $fname"
  echo "═══════════════════════════════════════════"

  local count; count=$("$PY" -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read()))" "$file" 2>/dev/null)
  if [ -z "$count" ] || ! [ "$count" -eq "$count" ] 2>/dev/null; then count=$(wc -m < "$file" | tr -d ' '); fi
  if [ "$count" -ge 3000 ] && [ "$count" -le 3500 ]; then
    chk_pass "字数: $count (3000-3500)"
  else
    chk_fail "字数: $count (期望 3000-3500)"
  fi

  local b; b=$(grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "禁词(年龄/穿越): 未发现"; else
    chk_fail "禁词(年龄/穿越): 发现 $b 处"; grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | head -5; fi

  local mc; mc=$(grep -c "$PROTAGONIST" "$file" || true)
  [ "$mc" -gt 0 ] && chk_pass "主角出场: $mc 次" || chk_fail "主角出场: 未出现"

  b=$(grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "禁词(境界): 未发现"; else
    chk_fail "禁词(境界): 发现 $b 处"; grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | head -5; fi

  local kt; kt=$(grep -cE "$KEY_TERMS" "$file" || true)
  [ "$kt" -gt 0 ] && chk_pass "关键术语出现: $kt 次" || chk_warn "关键术语: 未找到核心设定词"

  b=$(grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "去AI味禁词: 未发现"; else
    chk_fail "去AI味禁词: 发现 $b 处"; grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | head -5; fi

  b=$(grep -nE "主角光环|剧情杀|工具人|NPC|降智|圣母|舔狗|金手指|外挂|面板|属性|经验值|新手村" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "其他禁词: 未发现"; else
    chk_fail "其他禁词: 发现 $b 处"; grep -nE "主角光环|剧情杀|工具人|NPC|降智|圣母|舔狗|金手指|外挂|面板|属性|经验值|新手村" "$file" | head -5; fi

  b=$(grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "元叙事禁词: 未发现"; else
    chk_fail "元叙事禁词: 发现 $b 处"; grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | head -5; fi

  local repeated; repeated=$(grep -c "^${PROTAGONIST}" "$file" || true)
  [ "$repeated" -le 10 ] && chk_pass "段落开头多样性: '${PROTAGONIST}'开头 $repeated 次(≤10)" || chk_warn "段落开头多样性: '${PROTAGONIST}'开头 $repeated 次(>10，建议变换)"

  echo -e "\n  ${YELLOW}--- 节奏与结尾检测 ---${NC}"
  local tail_text; tail_text=$(tail -c 900 "$file")
  local has_info; has_info=$(echo "$tail_text" | grep -cE "？|！|\.\.\.|[新来去进出]" || true)
  if [ "$has_info" -ge 1 ]; then
    chk_pass "尾部钩子: 有悬念/转折/新信息"
  else
    chk_warn "尾部钩子: 结尾偏平淡，建议加悬念"
  fi

  b=$(echo "$tail_text" | grep -cE "睡了|走了|回去了|离开了|今天真是|美好的一天|就这样" || true)
  if [ "$b" -eq 0 ]; then chk_pass "收尾模式: 未检测到平淡收尾"; else
    chk_warn "收尾模式: 疑似平淡收尾（'睡了/走了/美好了'）"; fi

  # 段落开头多样性
  local mc_open; mc_open=$(grep -c "^${PROTAGONIST}" "$file" || true)
  [ "$mc_open" -le 10 ] && chk_pass "段落开头: '${PROTAGONIST}'开头 $mc_open 次(≤10)" || chk_warn "段落开头: '${PROTAGONIST}'开头 $mc_open 次(>10，建议变换)"
}

# ============================================================
# L1 brief 校验
# ============================================================
validate_brief() {
  local file="$1"
  local fname; fname=$(basename "$file")
  echo ""; echo "═══════════════════════════════════════════"
  echo " L1 Brief 校验: $fname"
  echo "═══════════════════════════════════════════"

  local count; count=$("$PY" -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read()))" "$file" 2>/dev/null)
  if [ -z "$count" ] || ! [ "$count" -eq "$count" ] 2>/dev/null; then count=$(wc -m < "$file" | tr -d ' '); fi
  if [ "$count" -ge 300 ] && [ "$count" -le 500 ]; then
    chk_pass "字数: $count (300-500)"
  else
    chk_fail "字数: $count (期望 300-500)"
  fi

  grep -qE "时间：|出场：|摘要：|关键钩子：|信息密度：|字数：" "$file" && chk_pass "格式: 含 6 个必要字段" || chk_fail "格式: 缺少必要字段"
}

# ============================================================
# 正典账本校验
# ============================================================
validate_canon() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 正典账本校验"
  echo "═══════════════════════════════════════════"

  local f
  for f in facts promises progression relationships settings payoffs panels roles mysteries; do
    local path="$CANON/${f}.jsonl"
    if [ -f "$path" ]; then
      local lines; lines=$(grep -vc '^#' "$path" || true)
      chk_pass "${f}.jsonl: ${lines} 条记录"
    else
      chk_warn "${f}.jsonl: 不存在"
    fi
  done
}

# ============================================================
# 节奏/结尾 + 高潮义务检查
# ============================================================
validate_pacing() {
  local file="$1"
  echo ""; echo "═══════════════════════════════════════════"
  echo " 节奏图谱 & 高潮义务检查 (当前 Ch${CUR})"
  echo "═══════════════════════════════════════════"

  local pacing_file="$ROOT/追踪/节奏图谱.md"
  if [ ! -f "$pacing_file" ]; then chk_warn "节奏图谱.md 不存在（节奏追踪未启用，skip）"; return; fi

  if [ $((CUR % SMALL_CYCLE)) -eq 0 ]; then
    echo "  ⚡ 当前章命中小高潮周期 (每${SMALL_CYCLE}章)"
    local tail_text; tail_text=$(tail -c 900 "$file")
    local intensity; intensity=$(echo "$tail_text" | grep -cE "！|\?|\.\.\.|[冲撞打断裂]" || true)
    [ "$intensity" -ge 3 ] && chk_pass "小高潮情绪强度: 章末情绪标记 ${intensity}处(≥3)" || chk_warn "小高潮情绪强度: 章末情绪标记 ${intensity}处(<3，建议加强)"
  else
    chk_pass "小高潮周期: 当前非高潮章（无高潮义务）"
  fi

  if [ $((CUR % BIG_CYCLE)) -eq 0 ]; then
    echo "  🔥 当前章命中大高潮周期 (每${BIG_CYCLE}章)"
    local tail_text; tail_text=$(tail -c 900 "$file")
    local intensity; intensity=$(echo "$tail_text" | grep -cE "！|\?|\.\.\.|[冲撞打断裂]" || true)
    [ "$intensity" -ge 5 ] && chk_pass "大高潮情绪强度: 章末情绪标记 ${intensity}处(≥5)" || chk_warn "大高潮情绪强度: 章末情绪标记 ${intensity}处(<5，建议大幅加强)"
  else
    chk_pass "大高潮周期: 当前非大高潮章（无高潮义务）"
  fi
}

# ============================================================
# 伏笔生命周期检测
# ============================================================
validate_foreshadow() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 伏笔生命周期检测 (当前 Ch${CUR})"
  echo "═══════════════════════════════════════════"
  local f="$CANON/promises.jsonl"
  if [ ! -f "$f" ]; then chk_warn "promises.jsonl 不存在（伏笔追踪未启用，skip）"; return; fi
  "$PY" - "$f" "$CUR" "$OVERDUE" <<'PY'
import json,sys
f,cur,overdue=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
pending=[r for r in rows if r.get('status')=='pending']
intra=[r for r in pending if r.get('scope')=='intra-volume']
cross=[r for r in pending if r.get('scope')=='cross-volume']
print(f"    活跃钩子: {len(pending)} 个 (卷内={len(intra)} 跨卷={len(cross)})")
warn=0;fail=0
for r in pending:
    pc=r.get('planned_chapter')
    if pc is None: continue
    try: pc=int(pc)
    except: continue
    if pc<cur:
        if cur-pc>overdue:
            print(f"    ✗ 硬失败: {r.get('id')} planned_ch{pc} 已逾期 {cur-pc} 章(阈值{overdue}) - {r.get('content','')[:30]}")
            fail+=1
        else:
            print(f"    ⚠ 逾期: {r.get('id')} planned_ch{pc} 已逾期 {cur-pc} 章 - {r.get('content','')[:30]}")
            warn+=1
sys.exit(1 if fail else 0)
PY
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    chk_pass "伏笔生命周期: 无逾期未回收"
  else
    chk_fail "伏笔生命周期: 存在硬失败逾期项（见上）"
  fi
}

# ============================================================
# 谜题分层释放检测
# ============================================================
validate_mystery() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 谜题分层释放检测 (当前 Ch${CUR})"
  echo "═══════════════════════════════════════════"
  local f="$CANON/mysteries.jsonl"
  if [ ! -f "$f" ]; then chk_warn "mysteries.jsonl 不存在（谜题追踪未启用，skip）"; return; fi
  if "$PY" - "$f" "$CUR" <<'PY'
import json,sys
f,cur=sys.argv[1],int(sys.argv[2])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
warn=0;fail=0
for r in rows:
    prc=r.get('planned_reveal_chapter'); rc=r.get('revealed_chapter')
    if prc is None: continue
    try: prc=int(prc)
    except: continue
    if rc is None and prc<cur:
        print(f"    ⚠ 逾期未揭示: {r.get('id')} planned_ch{prc} - {r.get('mystery','')[:30]}")
        warn+=1
    if rc is not None:
        try:
            if int(rc)<prc:
                print(f"    ✗ 提前泄露: {r.get('id')} revealed_ch{rc} < planned_ch{prc} - {r.get('mystery','')[:30]}")
                fail+=1
        except: pass
print(f"    谜题总数={len(rows)} 逾期未揭示={warn} 提前泄露={fail}")
sys.exit(1 if fail else 0)
PY
  then
    chk_pass "谜题分层释放: 无提前泄露"
  else
    chk_fail "谜题分层释放: 存在提前泄露（见上）"
  fi
}

# ============================================================
# 跨章查重（新增）
# ============================================================
validate_dedup() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 跨章查重检测 (BM25, 对比最近 ${DEDUP_N} 章 L1 brief)"
  echo "═══════════════════════════════════════════"
  local chap="$1"
  if [ -z "$chap" ] || [ ! -f "$chap" ]; then chk_warn "未找到当前章正文，跳过查重"; return; fi
  local briefs; briefs=$(find_recent_briefs "$DEDUP_N")
  if [ -z "$briefs" ]; then chk_warn "无历史 L1 brief 可对比（前${DEDUP_N}章无 brief），跳过查重"; return; fi
  "$PY" "$ROOT/scripts/retrieve.py" dedup --chapter "$chap" --current-nn "$NN" --n "$DEDUP_N" --threshold 0.5
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    chk_pass "跨章查重: 完成（疑似重复项见上，≤2 处可接受）"
  elif [ "$rc" -eq 1 ]; then
    chk_warn "跨章查重: 存在高度相似历史章（见上），人工复核"
  else
    chk_warn "跨章查重: 脚本异常（exit $rc），降级跳过"
  fi
}

# ============================================================
# 爽点账本检测（期待感-兑现配对）
# ============================================================
validate_payoff() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 爽点账本检测 (当前 Ch${CUR}, 逾期阈值 ${PAYOFF_OVERDUE} 章)"
  echo "═══════════════════════════════════════════"
  local f="$CANON/payoffs.jsonl"
  if [ ! -f "$f" ]; then chk_warn "payoffs.jsonl 不存在（爽点追踪未启用，skip）"; return; fi
  "$PY" - "$f" "$CUR" "$PAYOFF_OVERDUE" <<'PY'
import json,sys
f,cur,overdue=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
pending=[r for r in rows if r.get('status')=='pending']
paid=[r for r in rows if r.get('status')=='paid']
print(f"    爽点账本: 共{len(rows)} 待兑现={len(pending)} 已兑现={len(paid)}")
fail=0;warn=0
for r in pending:
    sc=r.get('chapter')
    if sc is None: continue
    try: sc=int(sc)
    except: continue
    if cur-sc>overdue:
        print(f"    ✗ 爽点逾期: {r.get('id')} 设置于ch{sc} 已逾期{cur-sc}章 - {r.get('setup_desc','')[:30]}")
        fail+=1
recent=0
for r in rows:
    sc=r.get('chapter')
    if sc is None: continue
    try: sc=int(sc)
    except: continue
    if sc>=cur-2:
        recent += 1 if r.get('status')=='pending' else (-1 if r.get('status')=='paid' else 0)
if recent>=3:
    print(f"    ⚠ 连续只设不收: 近3章净新增待兑现 {recent} 个，本章应优先回收旧爽点")
    warn+=1
if fail==0 and warn==0: print("    期待感-兑现配对正常")
sys.exit(1 if fail else 0)
PY
  local rc=$?
  [ "$rc" -eq 0 ] && chk_pass "爽点账本: 无逾期未兑现" || chk_fail "爽点账本: 存在逾期未兑现（见上）"
}

# ============================================================
# 黄金三章专项
# ============================================================
validate_opening() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 黄金三章专项 (当前 Ch${CUR})"
  echo "═══════════════════════════════════════════"
  if [ "$CUR" -gt 3 ]; then chk_pass "非开篇章（Ch${CUR}），跳过开篇专项"; return; fi
  local file="$1"
  if [ -z "$file" ] || [ ! -f "$file" ]; then chk_warn "未找到章节 ${NN} 的正文"; return; fi
  local head_text; head_text=$(head -c 600 "$file")
  local open_hook; open_hook=$(echo "$head_text" | grep -cE "？|！|\.\.\.|[突异奇杀怒喝]|不是|竟然|却" || true)
  [ "$open_hook" -ge 1 ] && chk_pass "开篇 600 字内: 有冲突/异常钩子 (${open_hook}处)" || chk_warn "开篇 600 字内: 未检测到冲突/异常，网文开篇需直入冲突"
  local hook_total; hook_total=$(grep -cE "？|！|\.\.\." "$file" || true)
  [ "$hook_total" -ge 3 ] && chk_pass "全章悬念标记: ${hook_total} 处" || chk_warn "全章悬念标记: ${hook_total} 处(<3，钩子密度偏低)"
  local early; early=$(head -c 800 "$file")
  local names; names=$(echo "$early" | grep -oE "[A-Z][A-Za-z]{1,8}" | wc -l | tr -d ' ')
  [ "$names" -le 4 ] && chk_pass "前 800 字专有名词: ${names} 个（无设定倾倒）" || chk_warn "前 800 字专有名词: ${names} 个（偏多，注意勿倾倒设定）"
  echo -e "\n  ${YELLOW}--- 开篇文学项（P3.5 文学审稿必须逐项确认）---${NC}"
  echo "    □ 金手指是否已展示或给出明确悬念（正文不出现'金手指'字面词）"
  echo "    □ 主角人设三要素是否立住（性格/处境/一个可记忆特征）"
  echo "    □ 是否有一个完整的小爽点/冲突闭环（开篇即给读者正反馈）"
  echo "    □ 结尾钩子是否足够强（读者有理由点下一章）"
}

# ============================================================
# 战力通胀检测
# ============================================================
validate_power() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 战力通胀检测 (当前 Ch${CUR}, 翻倍预警 ${POWER_DOUBLE} 章)"
  echo "═══════════════════════════════════════════"
  local f="$CANON/progression.jsonl"
  if [ ! -f "$f" ]; then chk_warn "progression.jsonl 不存在（战力追踪未启用，skip）"; return; fi
  "$PY" - "$f" "$CUR" "$POWER_DOUBLE" <<'PY'
import json,sys
f,cur,double=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
by_entity={}
for r in rows:
    by_entity.setdefault(r.get('entity','?'),[]).append(r)
fail=0;warn=0
for ent,rs in by_entity.items():
    rs=sorted(rs,key=lambda x:x.get('chapter',0))
    cur_max=None; cur_max_ch=0
    for r in rs:
        ch=r.get('chapter',0); v=r.get('value')
        try: ch=int(ch); v=float(v)
        except: continue
        if cur_max is None:
            cur_max=v; cur_max_ch=ch; continue
        if v<cur_max:
            print(f"    ✗ 战力回退: {ent} ch{ch} value={v} < 历史最高 {cur_max}")
            fail+=1
        elif v>=cur_max*2 and ch-cur_max_ch<=double:
            print(f"    ⚠ 升级过快: {ent} ch{ch} value={v} 相较最高翻倍({ch-cur_max_ch}章内)——警惕战力通胀/旧敌贬值")
            warn+=1
        if v>cur_max:
            cur_max=v; cur_max_ch=ch
print(f"    追踪角色: {len(by_entity)} 名")
sys.exit(1 if fail else 0)
PY
  local rc=$?
  [ "$rc" -eq 0 ] && chk_pass "战力: 无回退（升级过快预警见上）" || chk_fail "战力: 存在回退（见上）"
}

# ============================================================
# 金手指/系统面板 immutable 一致性
# ============================================================
validate_panel() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 面板注册表一致性 (当前 Ch${CUR})"
  echo "═══════════════════════════════════════════"
  local f="$CANON/panels.jsonl"
  if [ ! -f "$f" ]; then chk_warn "panels.jsonl 不存在（面板追踪未启用，skip）"; return; fi
  "$PY" - "$f" "$CUR" <<'PY'
import json,sys
f,cur=sys.argv[1],int(sys.argv[2])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
immutable={}
fail=0
for r in rows:
    if r.get('immutable') is not True: continue
    key=(r.get('entity','?'),r.get('system','?'),r.get('field','?'))
    if key in immutable and immutable[key]!=r.get('value'):
        print(f"    ✗ immutable 冲突: {key} 已登记 '{immutable[key]}' 又被登记为 '{r.get('value')}'")
        fail+=1
    immutable[key]=r.get('value')
print(f"    面板注册: {len(rows)} 条, immutable 项 {len(immutable)} 条")
print("    当前面板快照（供 P3.5 人工比对本章数值）：")
for (ent,sysname,fld),val in sorted(immutable.items()):
    print(f"      {ent}·{sysname}·{fld} = {val}")
sys.exit(1 if fail else 0)
PY
  local rc=$?
  [ "$rc" -eq 0 ] && chk_pass "面板: 无 immutable 冲突" || chk_fail "面板: 存在 immutable 冲突（见上）"
}

# ============================================================
# 配角/反派池检测
# ============================================================
validate_cast() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 配角/反派池检测 (当前 Ch${CUR}, 闲置阈值 ${CAST_IDLE} 章)"
  echo "═══════════════════════════════════════════"
  local f="$CANON/roles.jsonl"
  if [ ! -f "$f" ]; then chk_warn "roles.jsonl 不存在（配角池未启用，skip）"; return; fi
  "$PY" - "$f" "$CUR" "$CAST_IDLE" <<'PY'
import json,sys
f,cur,idle=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
recur=[r for r in rows if r.get('role')=='循环配角']
villains=[r for r in rows if r.get('role')=='反派']
print(f"    配角池: 共{len(rows)} (循环配角={len(recur)} 反派={len(villains)})")
warn=0
for r in recur:
    la=r.get('last_appearance')
    try: la=int(la)
    except: continue
    if cur-la>idle:
        print(f"    ⚠ 循环配角闲置: {r.get('name')} 已{cur-la}章未出场（阈值{idle}）——要么回收给戏，要么标记退场")
        warn+=1
for v in villains:
    if not v.get('motive'):
        print(f"    ⚠ 反派缺动机: {v.get('name')} 未登记当前动机（降智风险源）")
        warn+=1
if warn==0: print("    配角池状态正常")
sys.exit(0)
PY
  chk_pass "配角池: 检查完成（闲置/缺动机预警见上）"
}

# ============================================================
# 主流程：解析多模式 flag
# ============================================================
CHAPTER_FILE=$(find_chapter_file)
BRIEF_FILE=$(find_brief_file)

# 收集模式 flag（无 flag 默认 all）
MODES=""
if [ "$#" -eq 0 ]; then MODES="all"; fi
for arg in "$@"; do
  case "$arg" in
    --brief|--brief-only) MODES="$MODES brief" ;;
    --canon|--canon-only) MODES="$MODES canon" ;;
    --chapter|--chapter-only) MODES="$MODES chapter" ;;
    --pacing|--pacing-only) MODES="$MODES pacing" ;;
    --foreshadow) MODES="$MODES foreshadow" ;;
    --mystery) MODES="$MODES mystery" ;;
    --dedup) MODES="$MODES dedup" ;;
    --payoff) MODES="$MODES payoff" ;;
    --opening) MODES="$MODES opening" ;;
    --power) MODES="$MODES power" ;;
    --panel) MODES="$MODES panel" ;;
    --cast) MODES="$MODES cast" ;;
    all) MODES="$MODES all" ;;
    *) echo "未知参数: $arg"; exit 2 ;;
  esac
done

run_mode() {
  case "$1" in
    brief) [ -n "$BRIEF_FILE" ] && validate_brief "$BRIEF_FILE" || { echo "未找到章节 ${NN} 的 L1 brief"; FAIL=$((FAIL+1)); } ;;
    canon) validate_canon ;;
    chapter) [ -n "$CHAPTER_FILE" ] && validate_chapter "$CHAPTER_FILE" || { echo "未找到章节 ${NN} 的正文"; FAIL=$((FAIL+1)); } ;;
    pacing) [ -n "$CHAPTER_FILE" ] && validate_pacing "$CHAPTER_FILE" || { echo "未找到章节 ${NN} 的正文"; FAIL=$((FAIL+1)); } ;;
    foreshadow) validate_foreshadow ;;
    mystery) validate_mystery ;;
    dedup) validate_dedup "$CHAPTER_FILE" ;;
    payoff) validate_payoff ;;
    opening) validate_opening "$CHAPTER_FILE" ;;
    power) validate_power ;;
    panel) validate_panel ;;
    cast) validate_cast ;;
    all)
      [ -n "$CHAPTER_FILE" ] && validate_chapter "$CHAPTER_FILE" || echo -e "  ${YELLOW}⚠${NC} 未找到章节 ${NN} 的正文，跳过正文校验"
      [ -n "$BRIEF_FILE" ] && validate_brief "$BRIEF_FILE"
      validate_canon
      [ -n "$CHAPTER_FILE" ] && validate_pacing "$CHAPTER_FILE"
      validate_foreshadow
      validate_mystery
      validate_payoff
      [ -n "$CHAPTER_FILE" ] && validate_opening "$CHAPTER_FILE"
      validate_power
      validate_panel
      validate_cast
      ;;
  esac
}

for m in $MODES; do run_mode "$m"; done

echo ""; echo "═══════════════════════════════════════════"
echo -e " 结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC} / ${YELLOW}$WARN 警告${NC}"
echo "═══════════════════════════════════════════"
[ "$FAIL" -gt 0 ] && exit 1
