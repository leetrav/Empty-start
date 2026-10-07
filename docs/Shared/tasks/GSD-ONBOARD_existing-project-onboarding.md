# GSD-ONBOARD：现有项目接入 GSD

## 来源与目标

2026-10-08 Jackie 要求对 Empty-start 使用 GSD，完成代码库映射后授权自主 onboarding。目标是基于现有工程、正式系统文档、任务卡和历史日志建立可继续开发的规划状态。

## 本次范围

- 复用 `.planning/codebase/` 的七份地图。
- 用显式文档清单纳入原始资料、正式系统规格、公共规格和仓库规则。
- 核对现有实现与未完成任务，生成 PROJECT、REQUIREMENTS、ROADMAP、STATE、配置和接手摘要。
- 建立需求到阶段、阶段到现有任务卡的引用；保留代码/配置、正式文档、Original 的事实优先级。
- 记录 GSD 自动发现 Godot 和中文项目资料的已确认限制。

## 验收

1. 四个核心规划文件、配置、七份地图及 onboarding 摘要能够被 GSD 读取。
2. 剩余需求均有唯一阶段归属，已实现基础与历史运行证据有出处。
3. 当前游戏未完成、尚未验证的运行路径与未来设计假设被明确标注。
4. 引用文件存在，JSON 可解析，生成资料经过密钥模式检查。
5. 提交仅包含本任务资料及直接相关的陷阱记录，工作区已有修改由原任务继续持有。

## 执行约束

本任务属于规划接入；后续玩法开发仍从对应系统任务卡开始，独立 branch、实现、验证和任务日志沿用 `AGENTS.md`。集成以现有测试、最小 runtime smoke 和人工验收为主。自动前进关闭；本轮自主 onboarding 授权不等同于自动执行后续游戏阶段。

## 输出与接手

入口：`.planning/onboarding/SUMMARY.md`、`.planning/STATE.md`。
首阶段：神谕攻击选择与真实奖励，优先阅读 FO-13 及 FinalOracle/CB/SC 最新日志。
本次日志：`docs/Shared/GSD接入_GSD-ONBOARD_2026-10-08_log.md`。
