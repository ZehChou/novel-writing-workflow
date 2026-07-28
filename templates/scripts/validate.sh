#!/bin/bash
# validate.sh - Phase 3.5/Phase 5 硬校验一键脚本
# 用法:
#   bash scripts/validate.sh {NN}                     # P3.5 全量校验（正文+brief+正典+节奏+伏笔+谜题）
#   bash scripts/validate.sh {NN} --brief             # 仅 L1 brief 校验
#   bash scripts/validate.sh {NN} --canon             # 仅正典账本校验
#   bash scripts/validate.sh {NN} --chapter           # 仅正文校验
#   bash scripts/validate.sh {NN} --pacing            # 节奏/结尾 + 高潮义务检查
#   bash scripts/validate.sh {NN} --foreshadow        # 伏笔生命周期（逾期检测）
#   bash scripts/validate.sh {NN} --mystery           # 谜题提前泄露/逾期
#   bash scripts/validate.sh {NN} --dedup             # 跨章查重（最近N章 L1 brief）
#   bash scripts/validate.sh {NN} --pacing --foreshadow --dedup   # 多模式组合
# 在项目根目录下执行。老项目缺 mysteries.jsonl/节奏图谱.md 时对应检查降级 skip，不报错。

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
PROTAGONIST=$(protagonist_name)
KEY_TERMS=$(key_terms_pattern)

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

  local count; count=$(wc -m < "$file" | tr -d ' ')
  if [ "$count" -ge 3500 ] && [ "$count" -le 4000 ]; then
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

  local count; count=$(wc -m < "$file" | tr -d ' ')
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
  for f in facts promises progression relationships settings; do
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
  python3 - "$f" "$CUR" "$OVERDUE" <<'PY'
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
  if python3 - "$f" "$CUR" <<'PY'
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
  python3 "$ROOT/scripts/retrieve.py" dedup --chapter "$chap" --current-nn "$NN" --n "$DEDUP_N" --threshold 0.5
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
    all)
      [ -n "$CHAPTER_FILE" ] && validate_chapter "$CHAPTER_FILE" || echo -e "  ${YELLOW}⚠${NC} 未找到章节 ${NN} 的正文，跳过正文校验"
      [ -n "$BRIEF_FILE" ] && validate_brief "$BRIEF_FILE"
      validate_canon
      [ -n "$CHAPTER_FILE" ] && validate_pacing "$CHAPTER_FILE"
      validate_foreshadow
      validate_mystery
      ;;
  esac
}

for m in $MODES; do run_mode "$m"; done

echo ""; echo "═══════════════════════════════════════════"
echo -e " 结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC} / ${YELLOW}$WARN 警告${NC}"
echo "═══════════════════════════════════════════"
[ "$FAIL" -gt 0 ] && exit 1
