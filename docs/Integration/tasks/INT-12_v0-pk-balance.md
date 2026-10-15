# INT-12 普通战斗 V0 数值落地（2026-10-14）

## 开始前先阅读以下文档
- `AGENTS.md`
- `project.godot`
- `docs/Original/任务卡模板.md`
- `docs/6. HitResolution/README.md`
- `docs/7. OpponentPKBar/README.md`
- `docs/8. CombatStage/README.md`
- `data/source_tables/06_战斗数值.csv`
- `data/source_tables/08_Tier档位.csv`

## 已经实现的功能
- 普通话语按强度1/2/3提供独立PK收益，整发结算支持正向与负向分别封顶。
- OpponentPKBar接收Sandbox基础回拉与CombatStage当前Tier倍率。
- T0～T5拥有独立前景容量，普通前景与复读容量分开。
- Google策划表已批准V0试玩候选数值，正式游戏继续通过已有SandboxBattleConfig和Tier Catalog运行。

## 本次任务
- 把普通话语PK收益调整为强度1/2/3分别+0.4/+0.7/+1.2个百分点，倾向增量保持1/5/10。
- 把基础回拉设为0.08 PK/秒，T0～T5倍率依次设为0/0.7/1/1.2/1.45/1.6。
- 在SandboxBattleConfig配置单发正负上限分别2 PK，并传入每次创建的HitResolution；保持独立对象默认INF兼容。
- 同步正式Tier的T0前景容量8，其他Tier保留10/13/16/19/22；维持未配置0的旧回退语义。
- 保持MISS -1 PK、陷阱惩罚、阶段阈值及攻击周期原有实现。
- 更新现有相关测试断言、仓库CSV对应字段和系统说明，便于后续LC-10从Google表重新全量导出。

## Godot开发环境
- Godot 4.7.2 / GDScript
- 项目根目录：仓库根目录
- 平台：PC / Android
- 工程操作 MCP：Godot-MCP-Native
- 官方文档 MCP：godot_mcp

## 执行要求
- 按`AGENTS.md`和任务卡模板检查已有脚本、资源、场景及跨系统依赖，保持最小改动。
- 使用现有`HitResolution`构造参数和`BattleAttemptFlow`启动入口传递限幅，不创建第二份PK状态。
- 验证正式Sandbox的收益、各Tier回拉、T0容量、单发正负上限，以及失败重开后的配置重新注入。
- 运行并记录`tests/combat_stage/test_cs_24_foreground_slots.gd`、`tests/barrage_generation/test_bg16_foreground_capacity.gd`及现有HR-16/17用例的真实Godot结果。
- 如暂时无法运行Godot，在PR及日志中明确记录未验收项目，由程序负责人补测后再决定合并。
