# examples/ — 可运行示例项目

> 一个 3 章端到端跑通的示例：**青云录**。演示完整创作管线，含爽点账本/面板/配角池等全部扩展账本。
> 用途：①新用户学习管线怎么跑；②评估者跑 `validate.sh` 实测 skill 效果（darwin dim8 的测试集）。

## 目录

```
示范项目/
├── project-config.md        # 已填写（男频爽文 profile + 快速模式配置）
├── 大纲/05_第一卷细纲.md     # 3 章细纲（含爽点规划列）
├── 正文/                    # 3 章正文（避开全部禁词，3000-3500 字/章）
│   └── 摘要/                # L1 brief ×3 + L2 卷摘要
├── 知识库/                  # 角色档案/文风样本/档案事件（已填写）+ 其余模板
├── 追踪/
│   ├── canon/               # 九账本全填写（facts/promises/payoffs/panels/roles/...）
│   ├── 节奏图谱.md           # 含爽点兑现/追读列
│   └── 复盘.md              # P4.5 读者反馈复盘（示例数据）
└── scripts/                 # validate/archive/snapshot/retrieve/gen_docx
```

## 怎么跑

```bash
cd examples/示范项目

# 全量机械校验（演示新校验项：爽点/黄金三章/战力/面板/配角池）
bash scripts/validate.sh 03

# 单跑黄金三章专项（Ch1-3）
bash scripts/validate.sh 01 --opening

# 单跑爽点账本（期待感-兑现配对）
bash scripts/validate.sh 03 --payoff

# 单跑战力通胀 / 面板一致性 / 配角池
bash scripts/validate.sh 03 --power
bash scripts/validate.sh 03 --panel
bash scripts/validate.sh 03 --cast

# 正典归档压缩（模拟卷末）
bash scripts/archive.sh --dry-run 1 3
```

> 依赖：Bash 4+ 与 Python 3（`python` 或 `python3` 均可，脚本自动探测）。

## 故事一句话

外门杂役秦朗遭执事之子赵无极当众羞辱，淘井时觉醒《青云图录》淬体诀，藏拙三日，演武场一拳打脸，又于执事堂被刘伯点破秦家旧事，得父留玉牌"青冥台上，等你回家"，立志寻父——爽点、伏笔、谜题、关系弧线、面板数值齐备，示范"防崩 + 产爽"双引擎。
