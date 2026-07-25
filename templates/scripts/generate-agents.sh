#!/bin/bash
# generate-agents.sh — 从 project-config.md 生成 AGENTS.md
# 用法: bash scripts/generate-agents.sh
# 在项目根目录下执行

CFG="project-config.md"
OUT="AGENTS.md"

[ ! -f "$CFG" ] && { echo "Error: $CFG not found"; exit 1; }

# 提取字段值（去掉 "- 键：" 前缀）
# 用 awk 处理中文，避免 macOS sed 的编码问题
field() {
  local key="$1"
  awk -F "：" '/^[[:space:]]*- '"$key"'：/{sub(/^[[:space:]]*- /,""); sub(/^[^：]+：/,""); print; exit}' "$CFG"
}

# 提取从某标题开始到下一个标题之间的内容（不含标题行）
section_body() {
  awk "/$1/{found=1; next} /^## / && found{exit} found" "$CFG"
}

# --- 开始生成 ---

cat > "$OUT" << 'HEADER'
# AGENTS.md — 写作强制约束（全项目生效）

> 本文件由 `scripts/generate-agents.sh` 从 `project-config.md` 自动生成。
> 修改配置后执行 `bash scripts/generate-agents.sh` 重新生成。
> 正文与本文件冲突时，**以本文件为准**，立即修正。

---

## 0. POV 与时间线铁律

- **主角限知**：严禁上帝视角泄露主角未知身世/血统/功法/他人身份/世界隐秘。谜底按章节逐层释放。
- **时间线不可改**：所有已确认的时间节点不得前后矛盾。

---

HEADER

# Section 1: 禁词
{
  echo "## 1. 禁词（硬过滤）"
  echo ""
  echo "> **适用范围**：以下禁词仅约束**正文**（\`正文/\` 目录下的 \`.md\` 文件）。大纲、知识库、追踪、工作流等辅助文件不受此限。"
  echo ""
  section_body "^## 2\\. 禁词清单"
  echo ""
  echo "> **适用范围**：以下禁词仅约束**正文**（\`正文/\` 目录下的 \`.md\` 文件）。大纲、知识库、追踪、工作流等辅助文件不受此限。"
  echo ""
  echo "---"
  echo ""
} >> "$OUT"

# Section 2: 境界体系
{
  echo "## 2. 境界体系（唯一合法）"
  echo ""
  section_body "^## 3\\. 境界体系"
  echo ""
  echo "---"
  echo ""
} >> "$OUT"

# Section 3: 单章工作流
cat >> "$OUT" << 'WORKFLOW'
## 3. 单章工作流

```
P1 大纲拆解 → P2 素材准备
→ P2.5 写前组装（硬：P0 细纲/角色档案/文风样本/档案事件/创作脉络 + P1 前3章L1 brief/前章结尾 + P2 出场角色状态/已知秘密 + P3 活跃钩子 + P4 关键词反查 + P5 热梗灵感检查(可选)）
→ P2.6 大纲审批（用户口头确认"可写"） → P3 写作
-> P3.5 硬校验（3500-4000字 + 8项含POV边界+正典冲突+谜题提前泄露+读者-主角同步）
-> P3.6 查重检查（跨章：最近N章+同卷同弧） -> P4 用户审阅
-> P5 归档（10步：备份->.归档.md->更新档案事件->更新创作脉络->L1 brief->正典账本->节奏图谱->快照触发）
-> 卷末章：卷末收束7步 + 新卷开启6步（卷末章归档后执行）
```

**关键约束**：P2.6 审批**必须经用户口头确认"可写"后**方可进入 P3。P5 归档**必须经用户口头确认"可归档"后**方可执行。P4 审阅阶段用户可能手动修改正文，归档前需**再读一遍最新正文**确认无误。

口令："Phase 2.5 启动" / "Phase 2.6 审批" / "Phase 3.5 核验" / "Phase 3.6 查重" / "Phase 5 归档"

---

WORKFLOW

# Section 4: 文风与 Anti-AI
{
  echo "## 4. 文风与 Anti-AI"
  echo ""
  echo "句式：短句优先、动词强、形容词少；对话推剧情、心理藏动作/微表情"
  echo "去AI味：禁 仿佛、宛如、犹如、似乎、隐约、那一刻、就在这时、空气中弥漫、不由自主、下意识、恍惚、彷佛；禁 这什么展开、绝了、离谱"
  echo "五感：视/听/嗅/触/味 ≥2种/场景"
  echo "节奏：起笔快、中段铺垫、尾部钩子；章内\"动-静-动\""
  echo "信息密度：$(field 信息密度)"
  echo ""
  echo "---"
  echo ""
} >> "$OUT"

# 节奏与追踪参数（带默认值，老项目缺字段时回退）
SMALL_C=$(field 小高潮周期); SMALL_C=${SMALL_C:-3}
BIG_C=$(field 大高潮周期); BIG_C=${BIG_C:-10}
OVERDUE_C=$(field 伏笔逾期阈值); OVERDUE_C=${OVERDUE_C:-5}
DEDUP_C=$(field 跨章查重回看章数); DEDUP_C=${DEDUP_C:-3}
L1R=$(field "L1 摘要字数范围"); L1R=${L1R:-300-500}

# Section 5: 日式轻小说写作风格
{
  echo "## 5. 日式轻小说写作风格"
  echo ""
  section_body "^## 5\\. 日式轻小说写作风格"
  echo ""
  echo "---"
  echo ""
} >> "$OUT"

# Section 6: 关键设定锚点
{
  echo "## 6. 关键设定锚点"
  echo ""
  echo "- 书名：$(field 书名)"
  echo "- 作者：$(field 作者)"
  echo "- 题材：$(field 题材)"
  echo "- 主线：$(field 主线)"
  echo "- 金手指：签到系统（每日签到送灵石/功法/灵器等修仙资源，签到地点和连续签到影响奖励品质）"
  echo "- 感情线：$(field 感情线设定)"
  echo "- 节奏：慢热日常种田向，无敌流+种田流，主角不参与异世界争斗。$(field 节奏规则)"
  echo "- 节奏周期：小高潮÷${SMALL_C} / 大高潮÷${BIG_C}"
  echo "- 追踪参数：伏笔逾期阈值 +${OVERDUE_C}章 / 跨章查重回看 ${DEDUP_C}章 / L1摘要 ${L1R}"
  echo ""
  echo "---"
  echo ""
} >> "$OUT"

# Section 7-10: 固定模板
cat >> "$OUT" << 'FIXED'
## 7. 校验清单（Phase 3.5 必跑）

```bash
bash scripts/validate.sh {NN}
```

**全绿=通过**，否则改至全绿。

**正典冲突检测（Phase 3.5 第8项，按出场角色过滤后逐条人工比对）**：
- 从 `追踪/canon/facts.jsonl` 过滤出场角色相关条目，逐条检查本章是否有违反
- 从 `追踪/canon/progression.jsonl` 检查本章境界变化是否低于历史最高值
- 从 `追踪/canon/promises.jsonl` 检查出场角色是否有临近到期未兑现的承诺

---

## 8. Phase 5 L1 brief 必检查

```bash
bash scripts/validate.sh {NN} --brief-only
```

---

## 9. Phase 5 正典账本校验

```bash
bash scripts/validate.sh {NN} --canon-only
```

---

## 10. 写作规范（硬约束）

- **可出版表达**：正文零违禁词、零低俗梗、零元叙事自指，符合出版审读标准
- **字数限制**：单章 3500-4000字（Phase 3.5 以 `wc -m` 硬校验，低于3500或高于4000均为不合格）
- **文风基准**：短句优先、动词强、形容词少；对话推剧情、心理藏动作/微表情
- **幽默克制**：吐槽带现代梗但**极克制**；**不主动解释梗、不元叙事自指、不破第四面墙**
- **去AI味扩展**：严禁网文口语化标签直接入文；幽默靠**反差动作/冷面吐槽/旁人视角**落地，不靠标签堆砌
- **招牌词节制**：标识性高频词不得密集堆砌。同一章内同类词应拉开间隔、控制频次（建议单章同词 ≤3次，且不在相邻场景连续出现）；可用指代、身体动作、物象替代直呼
FIXED

echo "Done: $OUT"
