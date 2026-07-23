# novel-writing-workflow

Codex 小说写作工作流 Skill — 长篇网文创作的全流程管线。

## 概述

基于 Phase 1-5 的单章创作流程，覆盖从大纲拆解到归档入库的完整闭环。适用于剑与魔法异世界、轻松日常向的修仙种田文，但核心工作流可适配任意题材。

## 核心特性

- **Phase 1-5 管线**：大纲拆解 → 素材准备 → 写前组装 → 大纲审批 → 场景拆解 → 正文写作 → 自编辑 → 硬校验 → 查重 → 审阅 → 归档
- **POV 知识边界**：`known_by` 字段追踪每个角色知道什么、不知道什么，防止上帝视角泄露
- **正典追踪**：facts（事实）、promises（钩子/承诺）、progression（境界变化）、relationships（情感状态），四维保证一致性
- **Anti-AI 文风约束**：硬禁词过滤 + 去AI味词库 + 招牌词频次控制
- **自动化校验**：`scripts/validate.sh` 一键跑完全部校验（字数、禁词、节奏、结尾钩子、段落开头多样性等）
- **配置驱动**：`project-config.md` 管理全部约束参数，`scripts/generate-agents.sh` 自动生成 AGENTS.md

## 快速开始

```bash
# 在新项目目录中调用本 Skill，执行初始化
# 将 templates/ 复制到项目根目录
cp -r templates/* /path/to/your/project/

# 编辑 project-config.md 填写基本信息
# 生成 AGENTS.md
bash scripts/generate-agents.sh

# 进入 Phase 1 开始创作
```

## 工作流

```
P1  大纲拆解
P2  素材准备
P2.5 写前组装（含钩子健康度检查）
P2.6 大纲审批（用户确认"可写"）
P2.7 场景拆解（3-5 个场景卡）
P3  正文写作
P3.2 自编辑（通读 + 段落开头 + 对话标签）
P3.5 硬校验（bash scripts/validate.sh {NN}）
P3.6 查重检查（结构/信息/句式三类）
P4  用户审阅
P5  归档入库（9步：备份→更新档案→L1 brief→正典账本→快照）
```

## 关键文件

| 文件 | 说明 |
|------|------|
| `SKILL.md` | 工作流完整定义，Codex 调用入口 |
| `project-config.md` | 项目配置（禁词、境界体系、字数等） |
| `AGENTS.md` | 从 project-config 自动生成的写作约束 |
| `scripts/validate.sh` | 一键硬校验脚本 |
| `scripts/generate-agents.sh` | 配置 → AGENTS.md 生成器 |
| `追踪/canon/facts.jsonl` | 原子事实，带 known_by POV 过滤 |
| `追踪/canon/promises.jsonl` | 钩子/承诺，含 type/scope 分类 |
| `追踪/canon/progression.jsonl` | 境界进阶轨迹 |
| `追踪/canon/relationships.jsonl` | 角色间情感状态变化 |

## 口令

| 口令 | 触发阶段 |
|------|---------|
| Phase 2.5 启动 | 写前组装 |
| Phase 2.6 审批 | 大纲审批 |
| Phase 2.7 拆场景 | 场景拆解 |
| Phase 3.2 自编辑 | 自编辑检查 |
| Phase 3.5 核验 | 硬校验 |
| Phase 3.6 查重 | 查重检查 |
| Phase 5 归档 | 归档入库 |

## 许可

私人项目，仅供作者本人使用。
