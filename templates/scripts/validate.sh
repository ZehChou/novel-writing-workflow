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
SMALL_CYCLE=$(num_val 小高潮周期 3)
BIG_CYCLE=$(num_val 大高潮周期 10)
OVERDUE=$(num_val 伏笔逾期阈值 5)
DEDUP_N=$(num_val 跨章查重回看章数 3)

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
    chk_pass "字数: $count (3500-4000)"
  else
    chk_fail "字数: $count (期望 3500-4000)"
  fi

  local b; b=$(grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "禁词(年龄/穿越): 未发现"; else
    chk_fail "禁词(年龄/穿越): 发现 $b 处"; grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | head -5; fi

  local mc; mc=$(grep -c "林一" "$file" || true)
  [ "$mc" -gt 0 ] && chk_pass "主角出场: $mc 次" || chk_fail "主角出场: 未出现"

  b=$(grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "禁词(境界): 未发现"; else
    chk_fail "禁词(境界): 发现 $b 处"; grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | head -5; fi

  local kt; kt=$(grep -cE "林一|签到系统|元婴|灵石|灵气" "$file" || true)
  [ "$kt" -gt 0 ] && chk_pass "关键术语出现: $kt 次" || chk_warn "关键术语: 未找到核心设定词"

  b=$(grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "去AI味禁词: 未发现"; else
    chk_fail "去AI味禁词: 发现 $b 处"; grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | head -5; fi

  b=$(grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then chk_pass "元叙事禁词: 未发现"; else
    chk_fail "元叙事禁词: 发现 $b 处"; grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | head -5; fi

  b=$(grep -cE "known_by|POV|知识边界" "$file" || true)
  [ "$b" -eq 0 ] && chk_pass "元叙事自指: 未发现" || chk_fail "元叙事自指: 发现 $b 处(正文中不应出现这些词)"

  local tail_text; tail_text=$(tail -c 300 "$file" 2>/dev/null || tail -c 300 "$file")
  local has_hook=0
  echo "$tail_text" | grep -qE "[？?！!…--]" && has_hook=1
  echo "$tail_text" | grep -qE "忽然|突然|就在这时|第二天|次日|第二天早晨|一个身影|一道光|一声响|不对劲|怎么回事|不会吧|难道|该不会" && has_hook=1
  [ "$has_hook" -eq 1 ] && chk_pass "结尾钩子: 最后300字有悬念/情感转折" || chk_warn "结尾钩子: 最后300字未检测到明显悬念，建议确认结尾是否有力"

  local repeated; repeated=$(grep -c "^林一" "$file" || true)
  [ "$repeated" -le 10 ] && chk_pass "段落开头多样性: '林一'开头 $repeated 次(≤10)" || chk_warn "段落开头多样性: '林一'开头 $repeated 次(>10，建议变换)"

  local said_count; said_count=$(grep -cE "[。：，]他说|[。：，]她说|[。：，]它说" "$file" || true)
  [ "$said_count" -le 5 ] && chk_pass "对话标签: '说'出现 $said_count 次(≤5)" || chk_warn "对话标签: '说'出现 $said_count 次(>5，建议用动作/表情替代)"
}

# ============================================================
# 节奏/结尾专项检查
# ============================================================
validate_pacing() {
  local file="$1"
  local fname; fname=$(basename "$file")
  echo ""; echo "═══════════════════════════════════════════"
  echo " 节奏/结尾专项检查: $fname"
  echo "═══════════════════════════════════════════"

  local tail_text; tail_text=$(tail -c 300 "$file" 2>/dev/null)
  local has_hook=0
  echo "$tail_text" | grep -qE "[？?！!…--]" && has_hook=1
  echo "$tail_text" | grep -qE "忽然|突然|就在这时|第二天|次日|第二天早晨|一个身影|一道光|不对劲|不会吧|难道|该不会" && has_hook=1
  [ "$has_hook" -eq 1 ] && chk_pass "结尾钩子: 最后300字有悬念/情感转折" || chk_warn "结尾钩子: 最后300字未检测到明显悬念，建议确认"

  local mc_open; mc_open=$(grep -c "^林一" "$file" || true)
  [ "$mc_open" -le 10 ] && chk_pass "段落开头: '林一'开头 $mc_open 次(≤10)" || chk_warn "段落开头: '林一'开头 $mc_open 次(>10，建议变换)"

  local said; said=$(grep -cE "[。：，]他说|[。：，]她说|[。：，]它说" "$file" || true)
  [ "$said" -le 5 ] && chk_pass "对话标签: '说'出现 $said 次(≤5)" || chk_warn "对话标签: '说'出现 $said 次(>5，建议用动作/表情替代)"

  local count; count=$(wc -m < "$file" | tr -d ' ')
  chk_pass "总字数: $count"

  # 高潮义务检查（按章号周期，独立于节奏图谱是否存在）
  local is_climax=0 climax_type=""
  if [ "$((CUR % BIG_CYCLE))" -eq 0 ]; then is_climax=1; climax_type="大高潮(÷$BIG_CYCLE)"; fi
  if [ "$((CUR % SMALL_CYCLE))" -eq 0 ]; then is_climax=1; climax_type="${climax_type:-小高潮(÷$SMALL_CYCLE)}"; fi
  if [ "$is_climax" -eq 1 ]; then
    chk_warn "高潮义务: Ch${CUR} 命中 ${climax_type}，确认本章情绪强度到位（中高以上）"
  else
    chk_pass "高潮义务: Ch${CUR} 非高潮章（小高潮÷${SMALL_CYCLE}/大高潮÷${BIG_CYCLE}）"
  fi

  # 节奏图谱存在性提示（图谱在 P5 归档时填充，此处仅提示）
  if [ -f "$ROOT/追踪/节奏图谱.md" ]; then
    chk_pass "节奏图谱: 存在（卷收尾时校验全卷曲线）"
  else
    chk_warn "节奏图谱: 追踪/节奏图谱.md 不存在，跨章节奏追踪未启用（skip）"
  fi
}

# ============================================================
# L1 Brief 校验
# ============================================================
validate_brief() {
  local file="$1"
  local fname; fname=$(basename "$file")
  echo ""; echo "═══════════════════════════════════════════"
  echo " L1 Brief 校验: $fname"
  echo "═══════════════════════════════════════════"
  [ ! -f "$file" ] && { chk_fail "文件不存在"; return; }

  local count; count=$(wc -m < "$file" | tr -d ' ')
  [ "$count" -ge 300 ] && [ "$count" -le 500 ] && chk_pass "字数: $count (300-500)" || chk_fail "字数: $count (期望 300-500)"

  grep -qE "^# Chapter" "$file" && chk_pass "标题格式: 正确" || chk_fail "标题格式: 缺少 '# Chapter' 标题"
  grep -q "关键钩子" "$file" && chk_pass "关键钩子段: 存在" || chk_fail "关键钩子段: 缺失"
  grep -q "信息密度" "$file" && chk_pass "信息密度段: 存在" || chk_fail "信息密度段: 缺失"
}

# ============================================================
# 正典账本校验
# ============================================================
validate_canon() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 正典账本校验"
  echo "═══════════════════════════════════════════"
  local d="$CANON"
  [ -f "$d/facts.jsonl" ] && chk_pass "facts.jsonl: $(grep -c '' "$d/facts.jsonl" || true) 行" || chk_fail "facts.jsonl: 不存在"
  [ -f "$d/promises.jsonl" ] && chk_pass "promises.jsonl: $(grep -c '' "$d/promises.jsonl" || true) 行" || chk_warn "promises.jsonl: 不存在(可能无承诺)"
  [ -f "$d/progression.jsonl" ] && chk_pass "progression.jsonl: $(grep -c '' "$d/progression.jsonl" || true) 行" || chk_fail "progression.jsonl: 不存在"
  [ -f "$d/relationships.jsonl" ] && chk_pass "relationships.jsonl: $(grep -c '' "$d/relationships.jsonl" || true) 行" || chk_warn "relationships.jsonl: 不存在(可能无情感记录)"
  [ -f "$d/settings.jsonl" ] && chk_pass "settings.jsonl: $(grep -c '' "$d/settings.jsonl" || true) 行" || chk_warn "settings.jsonl: 不存在(可能无场景注册)"
  if [ -f "$d/mysteries.jsonl" ]; then
    chk_pass "mysteries.jsonl: $(grep -c '' "$d/mysteries.jsonl" || true) 行"
  else
    chk_warn "mysteries.jsonl: 不存在（谜题分层释放未启用，skip）"
  fi
}

# ============================================================
# 伏笔生命周期检测（新增）
# ============================================================
validate_foreshadow() {
  echo ""; echo "═══════════════════════════════════════════"
  echo " 伏笔生命周期检测 (当前 Ch${CUR}, 逾期阈值 +${OVERDUE})"
  echo "═══════════════════════════════════════════"
  local f="$CANON/promises.jsonl"
  if [ ! -f "$f" ]; then chk_warn "promises.jsonl 不存在，跳过伏笔检测"; return; fi
  if python3 - "$f" "$CUR" "$OVERDUE" <<'PY'
import json,sys
f,cur,overdue=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
rows=[]
for l in open(f,encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#'): continue
    try: rows.append(json.loads(l))
    except: pass
pending=[r for r in rows if r.get('status')=='pending']
warn=0;fail=0
for r in pending:
    pc=r.get('planned_chapter')
    if pc is None: continue
    try: pc=int(pc)
    except: continue
    if pc<cur:
        if pc+overdue<=cur:
            print(f"    ✗ 逾期硬失败: {r.get('id')} planned_ch{pc} (超阈值{overdue}) - {r.get('content','')[:30]}")
            fail+=1
        else:
            print(f"    ⚠ 逾期警告: {r.get('id')} planned_ch{pc} - {r.get('content','')[:30]}")
            warn+=1
print(f"    待回收 pending={len(pending)} 逾期警告={warn} 逾期硬失败={fail}")
sys.exit(1 if fail else 0)
PY
  then
    chk_pass "伏笔生命周期: 无逾期硬失败"
  else
    chk_fail "伏笔生命周期: 存在逾期硬失败（见上）"
  fi
}

# ============================================================
# 谜题分层释放检测（新增）
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
  echo " 跨章查重检测 (对比最近 ${DEDUP_N} 章 L1 brief)"
  echo "═══════════════════════════════════════════"
  local chap="$1"
  if [ -z "$chap" ] || [ ! -f "$chap" ]; then chk_warn "未找到当前章正文，跳过查重"; return; fi
  local briefs; briefs=$(find_recent_briefs "$DEDUP_N")
  if [ -z "$briefs" ]; then chk_warn "无历史 L1 brief 可对比（前${DEDUP_N}章无 brief），跳过查重"; return; fi
  local tmp; tmp=$(mktemp)
  printf '%s\n' "$briefs" > "$tmp"
  if python3 - "$chap" "$tmp" <<'PY'
import sys,re
chap,lf=sys.argv[1],sys.argv[2]
def grams(s):
    s=re.sub(r'\s+','',s)
    return set(s[i:i+3] for i in range(len(s)-2)) if len(s)>2 else set()
cg=grams(open(chap,encoding='utf-8').read())
flag=0
for line in open(lf,encoding='utf-8'):
    p=line.strip()
    if not p: continue
    try: bg=grams(open(p,encoding='utf-8').read())
    except: continue
    inter=len(cg & bg)
    if not bg: continue
    coef=inter/len(bg)  # overlap coefficient = inter / min(|chap|,|brief|)≈brief
    import os
    if coef>0.30:
        print(f"    ⚠ 疑似重复: {os.path.basename(p)} 重叠系数 {coef:.2f} (>0.30)")
        flag+=1
print(f"    对比 brief 数={sum(1 for l in open(lf) if l.strip())} 疑似重复={flag}")
sys.exit(0)
PY
  then
    chk_pass "跨章查重: 完成（疑似重复项见上，≤2 处可接受）"
  else
    chk_fail "跨章查重: 脚本异常"
  fi
  rm -f "$tmp"
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
