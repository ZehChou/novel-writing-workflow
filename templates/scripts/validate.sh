#!/bin/bash
# validate.sh — Phase 3.5/Phase 5 硬校验一键脚本
# 用法:
#   bash scripts/validate.sh {NN}            # P3.5 全量校验
#   bash scripts/validate.sh {NN} --brief    # 仅 L1 brief 校验
#   bash scripts/validate.sh {NN} --canon    # 仅正典账本校验
#   bash scripts/validate.sh {NN} --chapter  # 仅正文校验
#   bash scripts/validate.sh {NN} --pacing   # 仅节奏/结尾检查
# 在项目根目录下执行

NN=$(printf "%02d" "${1:?用法: bash scripts/validate.sh <章号> [--brief|--canon|--chapter|--pacing]}")
MODE="${2:-all}"
ROOT=$(pwd)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

chk_pass() { PASS=$((PASS+1)); echo -e "  ${GREEN}✓${NC} $1"; }
chk_fail() { FAIL=$((FAIL+1)); echo -e "  ${RED}✗${NC} $1"; }
chk_warn() { WARN=$((WARN+1)); echo -e "  ${YELLOW}⚠${NC} $1"; }

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

# ============================================================
# 正文校验
# ============================================================
validate_chapter() {
  local file="$1"
  local fname; fname=$(basename "$file")
  echo ""; echo "═══════════════════════════════════════════"
  echo " 正文校验: $fname"
  echo "═══════════════════════════════════════════"

  # 1. 字数
  local count; count=$(wc -m < "$file" | tr -d ' ')
  if [ "$count" -ge 4000 ] && [ "$count" -le 5000 ]; then
    chk_pass "字数: $count (4000-5000)"
  else
    chk_fail "字数: $count (期望 4000-5000)"
  fi

  # 2. 禁词 — 年龄/穿越
  local b; b=$(grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then
    chk_pass "禁词(年龄/穿越): 未发现"
  else
    chk_fail "禁词(年龄/穿越): 发现 $b 处"; grep -nE "18岁|胎穿|穿越者|穿越|重生|前世|现代记忆" "$file" | head -5
  fi

  # 3. 主角
  local mc; mc=$(grep -c "林一" "$file" || true)
  [ "$mc" -gt 0 ] && chk_pass "主角出场: $mc 次" || chk_fail "主角出场: 未出现"

  # 4. 境界禁词
  b=$(grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then
    chk_pass "禁词(境界): 未发现"
  else
    chk_fail "禁词(境界): 发现 $b 处"; grep -nE "阶位|层次|重天|小成|大成|圆满|巅峰|半步|准[、， ]*伪[、， ]*真[、， ]*假" "$file" | head -5
  fi

  # 5. 关键术语
  local kt; kt=$(grep -cE "林一|签到系统|元婴|灵石|灵气" "$file" || true)
  [ "$kt" -gt 0 ] && chk_pass "关键术语出现: $kt 次" || chk_warn "关键术语: 未找到核心设定词"

  # 6. 去AI味
  b=$(grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then
    chk_pass "去AI味禁词: 未发现"
  else
    chk_fail "去AI味禁词: 发现 $b 处"; grep -nE "仿佛|宛如|犹如|似乎|隐约|那一刻|就在这时|空气中弥漫|不由自主|下意识|恍惚|彷佛|这什么展开|绝了|离谱" "$file" | head -5
  fi

  # 7. 元叙事
  b=$(grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | wc -l | tr -d ' ')
  if [ "$b" -eq 0 ]; then
    chk_pass "元叙事禁词: 未发现"
  else
    chk_fail "元叙事禁词: 发现 $b 处"; grep -nE "大纲|设定|剧情|伏笔|爽点|反转|节奏|张力|钩子|人物小传" "$file" | head -5
  fi

  # 8. 元叙事自指
  b=$(grep -cE "known_by|POV|知识边界" "$file" || true)
  [ "$b" -eq 0 ] && chk_pass "元叙事自指: 未发现" || chk_fail "元叙事自指: 发现 $b 处(正文中不应出现这些词)"

  # 9. 结尾钩子检查（新增）— 最后300字
  local total_chars; total_chars=$(wc -m < "$file" | tr -d ' ')
  local tail_text; tail_text=$(tail -c 300 "$file" 2>/dev/null || tail -c 300 "$file")
  local has_hook=0
  echo "$tail_text" | grep -qE "[？?！!…——]" && has_hook=1
  echo "$tail_text" | grep -qE "忽然|突然|就在这时|第二天|次日|第二天早晨|一个身影|一道光|一声响|不对劲|怎么回事|不会吧|难道|该不会" && has_hook=1
  [ "$has_hook" -eq 1 ] && chk_pass "结尾钩子: 最后300字有悬念/情感转折" || chk_warn "结尾钩子: 最后300字未检测到明显悬念，建议确认结尾是否有力"

  # 10. 段落开头多样性（新增）
  local repeated=0
  repeated=$(grep -c "^林一" "$file" || true)
  [ "$repeated" -le 10 ] && chk_pass "段落开头多样性: '林一'开头 $repeated 次(≤10)" || chk_warn "段落开头多样性: '林一'开头 $repeated 次(>10，建议变换)"

  # 11. 对话标签多样性（新增）
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

  # 结尾钩子
  local tail_text; tail_text=$(tail -c 300 "$file" 2>/dev/null)
  local has_hook=0
  echo "$tail_text" | grep -qE "[？?！!…——]" && has_hook=1
  echo "$tail_text" | grep -qE "忽然|突然|就在这时|第二天|次日|第二天早晨|一个身影|一道光|不对劲|不会吧|难道|该不会" && has_hook=1
  [ "$has_hook" -eq 1 ] && chk_pass "结尾钩子: 最后300字有悬念/情感转折" || chk_warn "结尾钩子: 最后300字未检测到明显悬念，建议确认"

  # 段落开头
  local mc_open; mc_open=$(grep -c "^林一" "$file" || true)
  [ "$mc_open" -le 10 ] && chk_pass "段落开头: '林一'开头 $mc_open 次(≤10)" || chk_warn "段落开头: '林一'开头 $mc_open 次(>10，建议变换)"

  # 对话标签
  local said; said=$(grep -cE "[。：，]他说|[。：，]她说|[。：，]它说" "$file" || true)
  [ "$said" -le 5 ] && chk_pass "对话标签: '说'出现 $said 次(≤5)" || chk_warn "对话标签: '说'出现 $said 次(>5，建议用动作/表情替代)"

  # 总字数
  local count; count=$(wc -m < "$file" | tr -d ' ')
  chk_pass "总字数: $count"
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
  local d="$ROOT/追踪/canon"
  [ -f "$d/facts.jsonl" ] && chk_pass "facts.jsonl: $(grep -c '' "$d/facts.jsonl" || true) 条" || chk_fail "facts.jsonl: 不存在"
  [ -f "$d/promises.jsonl" ] && chk_pass "promises.jsonl: $(grep -c '' "$d/promises.jsonl" || true) 条" || chk_warn "promises.jsonl: 不存在(可能无承诺)"
  [ -f "$d/progression.jsonl" ] && chk_pass "progression.jsonl: $(grep -c '' "$d/progression.jsonl" || true) 条" || chk_fail "progression.jsonl: 不存在"
  [ -f "$d/relationships.jsonl" ] && chk_pass "relationships.jsonl: $(grep -c '' "$d/relationships.jsonl" || true) 条" || chk_warn "relationships.jsonl: 不存在(可能无情感记录)"
}

# ============================================================
# 主流程
# ============================================================
CHAPTER_FILE=$(find_chapter_file)
BRIEF_FILE=$(find_brief_file)

case "$MODE" in
  --brief|--brief-only)
    [ -n "$BRIEF_FILE" ] && validate_brief "$BRIEF_FILE" || { echo "未找到章节 ${NN} 的 L1 brief 文件"; exit 1; } ;;
  --canon|--canon-only) validate_canon ;;
  --pacing|--pacing-only)
    [ -n "$CHAPTER_FILE" ] && validate_pacing "$CHAPTER_FILE" || { echo "未找到章节 ${NN} 的正文文件"; exit 1; } ;;
  --chapter|--chapter-only)
    [ -n "$CHAPTER_FILE" ] && validate_chapter "$CHAPTER_FILE" || { echo "未找到章节 ${NN} 的正文文件"; exit 1; } ;;
  all|*)
    [ -n "$CHAPTER_FILE" ] && validate_chapter "$CHAPTER_FILE" || echo -e "  ${YELLOW}⚠${NC} 未找到章节 ${NN} 的正文文件，跳过正文校验"
    [ -n "$BRIEF_FILE" ] && validate_brief "$BRIEF_FILE"
    validate_canon ;;
esac

echo ""; echo "═══════════════════════════════════════════"
echo -e " 结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC} / ${YELLOW}$WARN 警告${NC}"
echo "═══════════════════════════════════════════"
[ "$FAIL" -gt 0 ] && exit 1
