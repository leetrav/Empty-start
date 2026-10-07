# GSD 接入 GSD-ONBOARD 任务日志

日期：2026-10-08。分支：`codex/gsd-onboarding`。

## 1. 本次结果

将原 onboarding PR 收缩为“静态索引底座”。当前项目采用多 Lane 并发开发，实时 `PROJECT / REQUIREMENTS / ROADMAP / STATE` 在每次 PR 合并后都会过期，因此不把这些文件作为长期常驻事实源。

## 2. 合入内容

- `.planning/codebase/`：七份代码库地图，按文件头 `last_mapped_commit` 标记快照。
- `.planning/onboarding/INGEST-MANIFEST.yaml`：正式资料显式清单。
- `.planning/onboarding/TASK-INVENTORY.json`：222 张任务卡与历史日志匹配索引快照。
- `.planning/intel/classifications/`、`.planning/intel/requirements.md`：来源分类与原始需求索引。
- `.planning/README.md`：说明静态快照和动态规划状态的边界。
- `known_traps.md`：KT-33，记录 GSD 自动发现 Godot/中文资料的限制。

## 3. 未合入内容

移除实时 `PROJECT.md`、`REQUIREMENTS.md`、`ROADMAP.md`、`STATE.md`、GSD config、阶段目录、实时审计摘要与综合状态文件。它们以后只在准备使用 GSD 做阶段规划时，从当时最新 `main` 重新生成并单独提交。

## 4. 使用方式

平时并发开发只把本目录当“地图和索引”。Agent 判断当前完成度时必须回到最新代码、任务卡与最新日志。需要 GSD 阶段规划时再刷新动态状态，不要求每个开发 PR 同步维护。

## 5. 验证

本次只修改文档/索引范围；不涉及 Godot 代码或运行时。提交前检查 JSON 可解析、索引文件存在、`git diff --check` 通过。
