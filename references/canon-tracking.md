# 正典追踪系统（Canon Tracking）

> SKILL.md 第四节的详细参考。保证长篇连载一致性：六维核心 + 两个扩展账本（爽点/面板）+ 配角池，均为追加式 JSONL。

## 目录
1. 记忆压缩层级 L1/L2/L3/L4
2. facts.jsonl - 原子事实
3. promises.jsonl - 钩子/承诺（含伏笔生命周期）
4. payoffs.jsonl - 爽点/期待感账本（★ 扩展）
5. panels.jsonl - 金手指/系统面板注册表（★ 扩展）
6. roles.jsonl - 配角/反派池（★ 扩展）
7. progression.jsonl - 能力进阶（含战力通胀检测）
8. relationships.jsonl - 情感状态（含角色弧线）
9. settings.jsonl - 场景注册表
10. mysteries.jsonl - 谜题分层释放
11. 正典归档压缩（L4 归档层）
12. canon_patch - 正典双向更新

## 1. 记忆压缩层级（L1/L2/L3/L4）

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

**L4 归档层（★ 新增，百万字规模管理）**：
- 位置：`追踪/canon/archive/卷{NN}/`，每卷完结后执行 `bash scripts/archive.sh {卷号} {卷末章号}`
- 归档对象：已闭合伏笔、已兑现爽点、已揭示谜题、卷内已完结事实/关系/场景，以及章号 ≤ 卷末章的旧条目
- 保留活跃：`status:pending` 的 promises/payoffs、`revealed_chapter:null` 的 mysteries、全部 roles、各角色最新 progression
- 归档区含原条目副本 + `summary.md` 卷摘要；跨卷反查时先读 L2 卷摘要，必要时读归档区
- **触发时机**：卷末收束第 6 步快照之前；全书 100+ 章后建议每卷必归档

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

## 4. payoffs.jsonl - 爽点/期待感账本（★ 新增）

网文的引擎是「期待感-兑现配对」。每设置一个读者期待（打脸预告、装逼、金手指展示、情感推进、目标达成）记一条，兑现时回填——**让 AI 不只会"防崩"，还会"造爽"**。

```jsonl
{"id":"PAYOFF-XXXX","chapter":N,"by":"作者|角色名","payoff_type":"打脸|装逼|金手指|情感|进度","setup_desc":"期待感设置描述","paid_chapter":N|null,"status":"pending|paid|failed","intensity":1..3,"opponent":"被打脸/被压方","cost":"兑现代价","reader_hit":"高|中|低|null"}
```
- `payoff_type`：打脸=期待对方被打脸，装逼=期待主角展现实力，金手指=期待新能力，情感=期待关系推进，进度=期待目标达成
- `status`：pending=已设置未兑现；paid=已兑现（回填 `paid_chapter`）；failed=兑现了但不响（记录教训）
- `intensity`：1=小爽点 2=中爽点 3=大爽点
- `reader_hit`：P4.5 读者复盘回填（哪些爽点读者买账，用于复用）
- **生命周期检测**（P2.5 钩子健康度 + `validate.sh --payoff`）：
  - 逾期：设置章 + 爽点逾期阈值（默认 8 章）仍未兑现 -> ⚠️ 逾期
  - 连续 3 章只设不收 -> 本章应优先回收旧期待感
- 打脸结构要求"先给后夺"：被打脸方先赢过面子/占过便宜，兑现才有余韵；`opponent` 字段记录被打脸方，后续可旧账回响

## 5. panels.jsonl - 金手指/系统面板注册表（★ 新增）

网文读者对数字极敏感，面板数值前后不一致是重大翻车。

```jsonl
{"id":"PANEL-XXXX","chapter":N,"entity":"角色名","system":"金手指/系统名","field":"面板字段","value":"数值或规则","immutable":true|false,"note":""}
```
- `immutable=true`：一经登记不得矛盾（属性上限、规则、消耗倍率）；更新须记 canon_change_log
- `immutable=false`：可变值（当前血量、临时任务），可被后续覆盖
- **P2.5 加载**：出场角色面板当前值；**P3.5 比对**（`validate.sh --panel`）：本章出现的面板数值/规则与 immutable 项逐条核对
- 示例：灵力 12（初始）、每日任务限 1 次——这两条一旦登记，后续写错即触发硬失败

## 6. roles.jsonl - 配角/反派池（★ 新增）

防止"配角用完即弃""反派降智""路人甲无记忆点"。

```jsonl
{"id":"ROLE-XXXX","chapter":N,"name":"角色名","role":"循环配角|反派|路人|宠物","first_appearance":N,"last_appearance":N,"appearances":N,"intelligence":"高|中|低","motive":"当前动机","note":"记忆点"}
```
- `intelligence`：反派智商档位。**降智检测**：正文中反派行为与档位矛盾（高智商反派犯低级错误且无合理动机）-> 触发 literary-failure-modes.md 失败模式 #3
- `last_appearance`/`appearances`：P5 每章归档更新；**闲置检测**（`validate.sh --cast`）：循环配角连续超过闲置阈值（默认 15 章）未出场 -> ⚠️ 要么给戏要么标记退场
- `note`：记忆点（如"爱喝某茶馆的茶"），防止路人甲同质化

## 7. progression.jsonl - 能力进阶（含战力通胀检测）

```jsonl
{"id":"PROG-XXXX","chapter":N,"entity":"角色名","system":"体系名","level":"当前等级","value":N}
```
- `value` 为数值排序，检测进阶回退（新值必须 ≥ 历史最高值）
- P3.5 校验本章境界变化是否低于历史最高值
- **战力通胀检测**（`validate.sh --power`）：
  - 单角色回退：value < 历史最高值 -> 硬失败
  - 升级过快：短章数内 value 翻倍（默认 5 章）-> ⚠️ 警惕战力通胀/旧敌贬值
  - **越级规则**：`project-config.md` 配置 `越级需代价=是` 时，越级事件必须伴随代价（在 facts/panels 登记），无代价越级 -> ⚠️
- **旧敌贬值提醒**：主角秒杀旧敌前，检查该敌人在 `payoffs.jsonl` 或 `roles.jsonl` 中是否有未兑现的价值——旧敌是"成长刻度"，用一次少一次，慎当一次性沙包

## 8. relationships.jsonl - 情感状态（角色弧线）

```jsonl
{"id":"REL-XXXX","chapter":N,"from":"角色A","to":"角色B","status":"关系状态","delta":"变化描述","sentiment":-3..3,"arc":"弧线标签"}
```
- `sentiment`：-3=敌对,-2=厌恶,-1=冷淡,0=中立,1=友善,2=亲近,3=亲密
- `arc`：角色弧线标签（如"{配角A}-信任建立"），同一弧线跨章追踪情感渐进
- 每章归档追加；写前加载防止"上章冷战这章突然亲密"的情感跳跃
- L2 卷级摘要汇总各 `arc` 的本卷进展

## 9. settings.jsonl - 场景注册表

```jsonl
{"id":"SET-XXXX","chapter":N,"location":"地点名","fact":"固定描述","immutable":true|false}
```
- `immutable=true`：不可变描述（木屋朝向、灵田面积），一旦登记不得矛盾
- `immutable=false`：可变描述（天气、季节、临时物品），可被后续覆盖
- 写前按 `location` 过滤出场场景，只加载 immutable 项
- P3.5 逐条比对本章描述与已登记 immutable 项
- P5 新场景或场景变化时追加新条目

## 10. mysteries.jsonl - 谜题分层释放

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

## 11. 正典归档压缩（L4 归档层）

> 百万字长篇规模管理：canon jsonl 无限增长会撑爆 P2.5 预算。每卷完结后压缩。

- **命令**：`bash scripts/archive.sh {卷号} {卷末章号}`（先 `--dry-run` 预览）
- **归档对象**：已闭合伏笔、已兑现爽点、已揭示谜题、卷内完结事实/关系/场景、章号 ≤ 卷末章的旧条目
- **保留活跃**：`status:pending` 的 promises/payoffs、`revealed_chapter:null` 的 mysteries、全部 roles、各角色最新 progression
- **产出**：`追踪/canon/archive/卷{NN}/`（原条目 + `summary.md` 卷摘要）
- **联动**：归档后执行快照 `snapshot.sh {卷末章}`；跨卷反查先读 L2 卷摘要，必要时读归档区

## 12. canon_patch - 正典双向更新

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
