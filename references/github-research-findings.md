## GitHub 调研：长篇网文写作Agent最佳实践

> 调研时间：2026-07-25
> 来源：xiaoxiaoxiaotao/novel-bot, xindaaW/NovelWritingAgent, ddmmbb-2/Novel-AI-Agent, eluckydog/DreamQuill, shan8065/novel-writing-agent-platform

---

## 1. 结构化记忆预算控制（来自 NovelWritingAgent）

### 核心机制

NovelWritingAgent 的 `MemoryOrchestrator` 为每个上下文段设置硬性预算：

```python
SECTION_BUDGETS = {
    "task_context":     ContextBudget(max_items=8,  max_chars_per_item=700,  max_total_chars=2400),
    "canon_context":    ContextBudget(max_items=10, max_chars_per_item=1400, max_total_chars=5200),
    "relation_context": ContextBudget(max_items=6,  max_chars_per_item=500,  max_total_chars=1800),
    "scene_cast_context": ContextBudget(max_items=3, max_chars_per_item=700,  max_total_chars=1200),
    "narrative_context":  ContextBudget(max_items=6, max_chars_per_item=800,  max_total_chars=2400),
}
```

### 可借鉴要点

- **分级预算**：不同角色/任务获得不同大小的上下文窗口
- **max_items + max_total_chars 双重限制**：防止任一项超标
- **Writer 角色获得最大上下文**：写手需要完整 canon + 前文 + 角色关系
- **Reviewer 角色获得精简上下文**：评审员只需最近3章叙述 + 当前章节

### 对本项目的启示

当前项目 P2.5 写前组装加载 P0-P5 全部内容，但无逐段预算控制。建议在 SKILL.md 中增加：
- 每个优先级段的 max_chars 上限
- 超出上限时的截断策略（保留最新 + 保留最相关）
- 超预算风险提示（触发用户手动裁剪）

---

## 2. 语义检索与相关性排序（来自 NovelWritingAgent）

### 核心机制

NovelWritingAgent 使用轻量级哈希嵌入（hashed embedding）做本地语义检索：

```python
def _semantic_score(query, candidate):
    query_tokens = set(_semantic_tokens(query))
    candidate_tokens = set(_semantic_tokens(candidate))
    overlap = len(query_tokens & candidate_tokens) / len(query_tokens)
    query_vector = _hashed_embedding(query_tokens)
    candidate_vector = _hashed_embedding(candidate_tokens)
    return cosine_similarity(query_vector, candidate_vector) + 0.35 * overlap
```

### 三个检索桶

```
RETRIEVAL_BUCKET_LIMITS = {
    "immediate":  4,   # 当前章节直接相关
    "contextual": 6,   # 近期相关
    "deep":       8,   # 长期记忆
}
```

### 可借鉴要点

- **不依赖外部向量数据库**：纯本地哈希嵌入，零依赖
- **中文友好**：CJK 字符拆为 unigram + bigram token
- **三层检索深度**：immediate > contextual > deep，按优先级填充上下文

### 对本项目的启示

当前项目 P2.5 按 `entity` 过滤 facts.jsonl，但无相关性排序。建议：
- 在 `validate.sh` 中增加基于关键词的 relevance ranking
- 对 `facts.jsonl` 条目按与当前章节的相关性排序，仅加载 top-N

---

## 3. 双重记忆系统与压缩层级（来自 novel-bot）

### 核心机制

novel-bot 采用"Filesystem as Memory"设计：

```
memory/
├── MEMORY.md           # 全局长期记忆（世界观变迁、重要剧情节点）
└── chapters/           # 章节短期记忆
    ├── chapter_01.md   # 第1章摘要
    ├── chapter_02.md   # 第2章摘要
    └── ...
```

### 上下文构建策略

```python
def build_system_prompt():
    # 静态上下文（始终加载）
    SETTINGS.md + CHARACTERS.md + WORLD.md
    
    # 动态上下文（按需加载）
    global_memory       # 长期记忆
    recent_chapters(3)  # 最近3章摘要
    STORY_SUMMARY.md    # 全书梗概
    OUTLINE.md          # 大纲
    
    # 技能系统（渐进加载）
    always_skills       # 始终加载的技能
    skills_summary      # 可用技能摘要
```

### 关键约束

- `MAX_CONTEXT_MESSAGES = 10`：只保留最近10条对话
- `write_file` 产生的正文内容不进入上下文
- 每章写完后自动更新记忆，不需要用户干预

### 可借鉴要点

- **正文不入上下文**：章节正文通过 write_file 落盘，不占用对话 token
- **自动记忆更新**：写完即更新，不依赖用户手动触发
- **渐进式技能加载**：技能摘要先入上下文，需要时再读完整 SKILL.md

### 对本项目的启示

当前项目已有 L1 brief（章级）和 L2 brief（卷级），但缺少：
- **L3 压缩叙事**：全书最精简的叙事线，用于超长上下文时的兜底
- **自动更新触发**：归档后应自动触发 L1/L2/L3 更新，而非完全依赖 Phase 5 手动执行

---

## 4. 三维记忆系统（来自 Novel-AI-Agent）

### 核心机制

Novel-AI-Agent 维护三种独立记忆轨道：

```
设定纪录 (Setting Record)    → 角色修为、装备、地图变动
事件纪录 (Event Record)      → 重大战役、任务目标、困境
伏笔纪录 (Foreshadow Record) → 未解谜团、未来冲突点
```

### 三阶写作工作流

```
剧情纲要生成 → 正文初稿撰写 → 编辑深度润饰
```

### 可借鉴要点

- **伏笔独立追踪**：伏笔不是"事件"的子类，而是独立维度
- **回溯支持**：支持回滚到任意章节，自动恢复对应时间点的记忆快照

### 对本项目的启示

当前项目 `facts.jsonl` 混合了设定、事件、伏笔。建议在归档时显式标注 `fact_type`：
- `setting`：不变的设定事实
- `event`：已发生的事件
- `foreshadow`：埋下的伏笔
- 伏笔条目增加 `resolved_chapter` 字段，用于追踪回收状态

---

## 5. DreamQuill 五步法（纯提示词方案）

### 五步流程

```
第一步：锚 → 核心人物底线卡
第二步：框 → 本章因-果框架
第三步：表 → 出场人物此刻状态表
第四步：写 → 逐段三维检查（时间/信息/变化）
第五步：验 → 抽检+对白辨识
```

### 上下文衰减实测数据

| 字数区间 | 表现 |
|----------|------|
| 0-3000字 | 全部机制正常：人物一致，时间线清晰，逻辑无断层 |
| 3000-6000字 | 连续性检查松动，对话模式化（"XX说"重复率+120%） |
| 6000-8000字 | 五步流程执行变形，人物状态表不完整，动机记录丢失 |
| 8000-10000字 | 设定卡"底线"约束被违反，因果链断裂 |

### 关键发现

> **在5000-6000字区间，LLM会自行触发"收尾模式"**——哪怕指令要求继续写，模型也会倾向于自动收尾。这不是提示词可以克服的，是上下文窗口压力的自然表现。

### 可借鉴要点

- **3500-4000字是安全区间**：本项目字数限制恰好在安全区内
- **"收尾模式"风险**：长章节（>5000字）风险显著上升
- **对白辨识测试**：遮住人名看对话能否认出角色，简单有效的角色声纹校验

### 对本项目的启示

- 在 P3.5 校验中增加"收尾模式检测"：检查章末是否出现无意收尾
- 在 P2.55 记忆预演中融入五步法的"表"（出场人物此刻状态）
- 在 P3.2 自编辑中增加"对白辨识测试"

---

## 6. Canon_Patch 双向更新机制（来自 NovelWritingAgent）

### 核心机制

NovelWritingAgent 的 canon 不是只读的——章节修订可以反向更新 canon：

```python
class DeviationAction(str, Enum):
    UPDATE_WRITER = "update_writer"   # 写手偏离 canon，要求重写
    UPDATE_CANON  = "update_canon"    # 写手的创意更好，更新 canon
```

### 工作流

```
Writer 写初稿 → Reviewer 评审 → 发现偏离 canon
  ├─ 偏离是错误 → UPDATE_WRITER（重写）
  └─ 偏离是有意改进 → UPDATE_CANON（更新 canon，记录变更理由）
```

### 可借鉴要点

- **canon 不可变是伪命题**：好的创作会在写作中发现更好的设定
- **变更需记录理由**：`canon_change_log` 记录每次 canon 更新的原因
- **评审即审计**：Reviewer board 并行评审 + meta_reviewer 汇总

### 对本项目的启示

当前项目 canon 更新完全依赖 Phase 5 归档手动执行。建议：
- 在 P4 用户审阅阶段，如果用户修改了正文导致 canon 变化，显式触发 `canon_patch` 流程
- 在 `facts.jsonl` 中增加 `updated_from_chapter` 字段，记录事实的最近更新来源

---

## 7. 13 Agent 专业化分工（来自 shan8065/novel-writing-agent-platform）

### Agent 分类

```
资料处理类：html-processor, scp-extractor, scp-archiver, storyline-organizer
角色与设定类：character-integrator, lore-organizer, setting-reader
创作类：story-writer, novel-continuer
质量控制类：coherence-checker
```

### 可借鉴要点

- **coherence-checker 独立于 writer**：质量检查与创作分离
- **setting-reader 写前必读**：确保创作前已加载全部设定

### 对本项目的启示

当前项目 Phase 3.5 校验是同一个 agent 执行（自检）。建议在 SKILL.md 中强调：
- P3.5 校验时切换到"审核者模式"，与 P3 写作时的"创作者模式"分离
- 增加"角色切换宣言"：核验前显式声明"现在切换到审核者角色"

---

## 总结：对本项目 SKILL.md 的改进建议

| 改进项 | 来源 | 优先级 | 复杂度 |
|--------|------|--------|--------|
| 上下文预算控制（每段 max_chars） | NovelWritingAgent | **高** | 低 |
| L3 压缩叙事层 | novel-bot + NovelWritingAgent | **高** | 低 |
| 伏笔独立追踪（foreshadow type） | Novel-AI-Agent | 中 | 中 |
| 五步法预写检查融合 | DreamQuill | 中 | 低 |
| canon_patch 双向更新 | NovelWritingAgent | 中 | 中 |
| 语义相关性排序 | NovelWritingAgent | 低 | 高 |
| 角色切换机制 | shan8065 | 低 | 低 |
| 上下文衰减意识 | DreamQuill | **高** | 低 |
