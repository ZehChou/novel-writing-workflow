# 正典追踪系统（Canon Tracking）

> SKILL.md 第四节的详细参考。保证长篇连载一致性：事实/承诺/进阶/情感/场景/谜题六维，均为追加式 JSONL。

## 目录
1. 记忆压缩层级 L1/L2/L3
2. facts.jsonl - 原子事实
3. promises.jsonl - 钩子/承诺（含伏笔生命周期）
4. progression.jsonl - 能力进阶
5. relationships.jsonl - 情感状态（含角色弧线）
6. settings.jsonl - 场景注册表
7. mysteries.jsonl - 谜题分层释放
8. canon_patch - 正典双向更新

## 1. 记忆压缩层级（L1/L2/L3）

| 层级 | 文件 | 粒度 | 字数 | 更新频率 | 用途 |
|------|------|------|------|----------|------|
| **L1** | `正文/摘要/{NN}_章名.brief.md` | 章级 | 300-500 | 每章归档后 | 写前加载前3章 |
| **L2** | `正文/摘要/卷{NN}.brief.md` | 卷级 | 1500-2000 | 每卷收尾后 | 写前加载当前卷；跨卷加载前一卷 |
| **L3** | `正文/摘要/全篇.brief.md` | 全篇 | 800-1000 | 每卷收尾后更新 | 上下文溢出时替代 L1+L2 兜底 |

**L1 格式**：
- 时间：Day N
- 出场：主角（{名}）、...
- 摘要：300-500 字概述核心事件
- 关键钩子：本章落下的 1-3 个钩子/伏笔
- 信息密度：≥ 配置值条
- 字数：实际字符数
- 写入即冻结，永不修改

**L2 卷级摘要**含：本卷核心事件线 / 角色关系变化总览 / **角色弧线进展** / 未回收跨章钩子 / 下一卷承接点。

**L3 超精简叙事线**格式：
- 主角：{当前状态，一句话}
- 核心事件链：{按时间序，每事件 ≤15 字}
- 活跃角色：{名：身份/关系/状态，每角色 ≤20 字}
- 未闭合主线：{一句话}
- 最近钩子：{最近3个未回收}

**L3 触发**：P2.5 总字符超 12000 时，降级为 L3 + P0 + P2，舍弃 L1/L2。

## 2. facts.jsonl - 原子事实

```jsonl
{"id":"FACT-XXXX","chapter":N,"entity":["角色名"],"fact":"事实描述","known_by":["角色A","角色B"]}
```
- 只登记可被后续章节违反的约束性事实（能力上限、物品归属、人物死亡、关键承诺）
- `known_by` 留空 = 公开信息；新角色得知时追加 `type:"disclosure"` 条目
- 写前 P2 按 `known_by` 过滤，防止角色使用尚未获得的信息

## 3. promises.jsonl - 钩子/承诺（伏笔生命周期）

```jsonl
{"id":"PROMISE-XXXX","chapter":N,"by":"作者|角色名","content":"承诺内容","status":"pending|fulfilled|broken","type":"cliffhanger|emotional|lore|setup","scope":"intra-volume|cross-volume","planned_chapter":N,"resolved_chapter":N|null}
```
- `type`：cliffhanger=悬念钩, emotional=情感钩, lore=设定钩, setup=铺垫钩
- `scope`：intra-volume=本卷回收, cross-volume=跨卷伏笔
- `planned_chapter`：计划回收章号（写前预估，可随剧情调整）
- `resolved_chapter`：实际回收章号；回收时回填并将 `status` 改为 `fulfilled`
- 只追加不修改；`status` / `resolved_chapter` 可更新
- 写前按 `type` 和 `scope` 分类，优先处理 intra-volume 钩子

**伏笔生命周期检测**（P2.5 钩子健康度 + `validate.sh --foreshadow`）：
- 逾期：`planned_chapter` < 当前章 且 `status:pending` -> 标记 ⚠️ 逾期
- 硬失败：`planned_chapter` + 逾期阈值（默认 5 章）仍未回收 -> ✗ 升级为硬失败
- 连续 3 章只落不收 -> 本章应优先回收旧钩子

## 4. progression.jsonl - 能力进阶

```jsonl
{"id":"PROG-XXXX","chapter":N,"entity":"角色名","system":"体系名","level":"当前等级","value":N}
```
- `value` 为数值排序，检测进阶回退（新值必须 ≥ 历史最高值）
- P3.5 校验本章境界变化是否低于历史最高值

## 5. relationships.jsonl - 情感状态（角色弧线）

```jsonl
{"id":"REL-XXXX","chapter":N,"from":"角色A","to":"角色B","status":"关系状态","delta":"变化描述","sentiment":-3..3,"arc":"弧线标签"}
```
- `sentiment`：-3=敌对,-2=厌恶,-1=冷淡,0=中立,1=友善,2=亲近,3=亲密
- `arc`：角色弧线标签（如"露露-信任建立"），同一弧线跨章追踪情感渐进
- 每章归档追加；写前加载防止"上章冷战这章突然亲密"的情感跳跃
- L2 卷级摘要汇总各 `arc` 的本卷进展

## 6. settings.jsonl - 场景注册表

```jsonl
{"id":"SET-XXXX","chapter":N,"location":"地点名","fact":"固定描述","immutable":true|false}
```
- `immutable=true`：不可变描述（木屋朝向、灵田面积），一旦登记不得矛盾
- `immutable=false`：可变描述（天气、季节、临时物品），可被后续覆盖
- 写前按 `location` 过滤出场场景，只加载 immutable 项
- P3.5 逐条比对本章描述与已登记 immutable 项
- P5 新场景或场景变化时追加新条目

## 7. mysteries.jsonl - 谜题分层释放

世界观秘密的分层释放注册表，限知 POV 核心：

```jsonl
{"id":"MYS-XXXX","mystery":"谜题描述","layer":N,"planned_reveal_chapter":N,"known_by":["角色"],"revealed_chapter":N|null,"disclosed_to":[]}
```
- `layer`：释放层级（1=表层,2=中层,3=核心），低层先释放
- `planned_reveal_chapter`：计划向读者揭示的章号
- `known_by`：当前已知该谜题的角色
- `revealed_chapter`：实际向读者揭示的章号
- `disclosed_to`：已被告知的非主角角色列表
- 写前按 `known_by` 过滤，防止 POV 泄露
- **P3.5 提前泄露检测**（`validate.sh --mystery`）：本章是否向读者/非知情角色披露了尚未到 `planned_reveal_chapter` 的谜题 -> 硬失败

## 8. canon_patch - 正典双向更新

正典非只读。写作中发现更好设定时更新正典而非强守旧设定。

| 偏离类型 | 判定 | 处理 |
|----------|------|------|
| `UPDATE_WRITER` | 无意错误偏离（如忘记角色已会某技能） | 修正正文，正典不变 |
| `UPDATE_CANON` | 有意创意改进 | 更新正典，记 canon_change_log |

**流程**：
1. 仅限 P4 用户审阅后触发；P3 写作阶段严禁自行改正典
2. 用户回复「canon_patch」
3. AI 列出待更新条目，逐条给更新理由
4. 用户确认后更新 `facts`/`settings`/`progression` 等相关文件
5. 追加 `追踪/canon/canon_change_log.md` 变更记录

**canon_change_log 格式**：

| 日期 | 章节 | 变更条目 | 旧值 | 新值 | 理由 |

P3 写作中发现正典需调整：在 P3.5 核验报告标注「建议 canon_patch: {描述}」，由用户 P4 决定。
