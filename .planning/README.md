# GSD 静态索引底座

本目录当前只保留可长期复用的代码库地图与来源/任务索引，不保存实时开发进度。

## 当前保留内容

- `.planning/codebase/`：代码库地图。每份地图以文件头的 `last_mapped_commit` 为快照基线。
- `.planning/onboarding/INGEST-MANIFEST.yaml`：显式资料清单，解决 GSD 自动发现漏掉 GDScript 与中文规格的问题。
- `.planning/onboarding/TASK-INVENTORY.json`：任务卡/日志检索快照。它只说明“有哪些卡、当时能匹配哪些日志”，不代表当前任务完成状态。
- `.planning/intel/classifications/` 与 `.planning/intel/requirements.md`：接入时的来源分类与原始需求索引。

## 不在这里维护的内容

`PROJECT.md`、`REQUIREMENTS.md`、`ROADMAP.md`、`STATE.md`、阶段目录和 GSD 并发配置属于动态规划状态。项目当前采用多 Lane 并发开发，这些文件如果每个 PR 都更新会快速过期，因此本次不合入。

只有在准备使用 GSD 规划下一阶段时，才从当时最新 `main` 重新生成动态规划状态并单独提交。普通并发开发无需同步刷新本目录。

## 事实优先级

实际代码与运行结果 > 当前任务卡 > 正式系统 README > 本目录快照 > docs/Original 历史资料。
