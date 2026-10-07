# GSD-ONBOARD：现有项目静态索引接入

## 目标

为 Empty-start 建立可长期复用的 GSD 静态底座，让 Agent 能快速找到代码结构、正式资料与任务卡，同时避免并发开发期间维护一份持续过期的实时 ROADMAP / STATE。

## 本次范围

- 保留 `.planning/codebase/` 七份代码库地图，并记录映射 commit。
- 通过 `.planning/onboarding/INGEST-MANIFEST.yaml` 显式纳入 Godot / 中文规格。
- 建立 `TASK-INVENTORY.json` 任务卡与日志检索快照。
- 保留来源分类与原始需求索引。
- 在 `known_traps.md` 记录 GSD 自动发现漏掉 `.gd`、`project.godot` 和中文规格的 KT-33。

## 明确边界

本任务不提交 `PROJECT.md`、`REQUIREMENTS.md`、`ROADMAP.md`、`STATE.md`、阶段目录或 GSD 并发配置。这些属于实时规划状态，只在用户准备进行阶段规划时从当时最新 `main` 重新生成。

任务索引中的日志匹配只用于检索历史证据，不代表当前任务完成状态。地图与索引都是快照，不要求随每个并发 PR 更新。

## 验收

1. codebase map、manifest、任务索引和来源分类可从仓库直接读取。
2. 每个快照明确说明基线/用途，不会被误认为当前完成度。
3. 不引入会随着 A～E Lane 每次合并都必须同步维护的动态 planning state。
4. 提交只包含规划索引资料及 KT-33，不修改游戏代码。
