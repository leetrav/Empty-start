# Empty-start：GSD 接入摘要

日期：2026-10-08。对应任务：[GSD-ONBOARD](<../../docs/Shared/tasks/GSD-ONBOARD_existing-project-onboarding.md>)。用户授权：对当前项目自主完成 onboarding。

## Project State

- PROJECT.md：present — [项目与已有实现](../PROJECT.md)
- REQUIREMENTS.md：present — [40 条剩余验收需求](../REQUIREMENTS.md)
- ROADMAP.md：present — [7 个未执行阶段](../ROADMAP.md)
- STATE.md：present — [Phase 1 / Ready to plan](../STATE.md)
- config.json：present — 中文响应、standard、后续 interactive；auto_advance=false。
- 完整一局、当前 checkout 运行、Windows/Android 构建：UNVERIFIED。此接入任务未启动 Godot 或产品测试。

## Codebase Context

- 本仓库是已有且尚未完成的 Godot/GDScript 项目。七份 [codebase 地图](../codebase/) 已存在，复用其内容与证据。
- 基于当前代码与三份审计核对进度：[早期系统](AUDIT-EARLY.md)、[后段系统](AUDIT-LATE.md)、[共享与交付](AUDIT-SHARED.md)。
- 普通战斗、真实 CB、身份、数据与部分表现具备已有实现和历史验证。玩家神谕交互、奖励、休息、多关、终局和结局存在剩余工作。
- [任务索引](TASK-INVENTORY.json) 是接入前 222 张卡的快照；155 张卡能匹配日志，日志中包含延期和旧阻塞。该数量仅作检索依据。
- FO-10/SC-02、TT-09/FO-09 为已有重叠交付；AS-07 完整保留矩阵仍待验收。旧状态被后续集成覆盖时，以当前工程核销。

## Docs Context

- [显式 ingest 清单](INGEST-MANIFEST.yaml) 纳入 28 份来源：24 SPEC、3 PRD、1 DOC；24 SPEC 包含 AGENTS、19 个编号系统规格及 4 个 Shared 规格。
- 本次使用 manifest 的明确类型与优先级，分类元数据由源文档标题、段落和引用提取。三组代码/日志审查补充实现进度，GSD synthesizer 和 roadmapper 生成规划。
- [综合入口](../intel/SYNTHESIS.md) 指向需求、契约、上下文与来源；详细规则继续查看对应正式系统文档。
- [冲突记录](../INGEST-CONFLICTS.md)：0 BLOCKER、0 WARNING、8 INFO。历史布局、准心、静音过渡和 neutral 规则按当前正式规格处理。
- 源资料仍保存在 `docs/Original/`；任务卡定义当前工作，系统正式文档定义规则，`.planning/` 聚合调度与状态。

## GSD 工具适配

GSD 1.15.0 的代码扩展名集合缺少 `.gd`，包入口集合缺少 `project.godot`；文档发现只识别有限的 ADR/PRD/SPEC/RFC/REQUIREMENTS 命名及目录。其 `is_brownfield=false` / 文档候选 0 与实际工程不符，本次以显式 manifest 和代码审计补足，记录为 `known_traps.md` KT-33。

已有 `.planning/codebase/`，核心规划文件此前缺失；本次为缺失文件建立初始化骨架。七个阶段目录使用稳定英文 slug，中文阶段名称保留在 ROADMAP/STATE，均尚无 PLAN 或执行结果。

配置关闭 Nyquist 自动补测，保留 plan_check、verifier 与现有测试；后续遵循任务卡的最小 runtime smoke、人工验收和明确高风险用例预算。当前 GSD 自主授权用于 onboarding，后续阶段保持交互模式。

## 已执行验证

- GSD `roadmap analyze` 识别 7 个阶段；`smart-entry --json` 返回 planning，下一步计划 Phase 1。
- GSD `state validate --strict` 返回 valid=true，warnings=[]。
- GSD `init plan-phase 1` 找到 `01-oracle-interaction`，读取 ORAC-01～04 / FANS-01，计划数 0。
- 40 条需求均唯一映射到阶段；30 份 JSON 可解析；规划与证据链接能够定位来源；密钥模式扫描无命中。
- 独立文档复核修正 Phase 4/5 交接依赖和 PA-03 接入素材计数。Phase 4 验收终局冻结结果与交接请求；DD-17 的真实结局接收/转场在 Phase 5 完成。

## Recommended Next Step

`$gsd-manager` 可查看接入后的全局状态。直接进入首阶段：`$gsd-plan-phase 1`。

首阶段是“神谕攻击选择与真实奖励”，优先阅读 [FO-13](<../../docs/13. FinalOracle/tasks/FO-13_battle-area-attack-selection.md>)、FinalOracle/CB/SC 正式规格与最新日志、`known_traps.md`。沿用准心/蓄力/发射接口和真实 BattleArea，FO-13 非空候选保证继续 TO VERIFY。

每张独立任务使用自己的 branch，更新直接相关系统文档，并按 `AGENTS.md` 写入任务日志。接入分支为 `codex/gsd-onboarding`；现有工作区的其他未提交内容由原任务继续持有。

本次任务日志：[GSD接入_GSD-ONBOARD_2026-10-08_log.md](<../../docs/Shared/GSD接入_GSD-ONBOARD_2026-10-08_log.md>)。
