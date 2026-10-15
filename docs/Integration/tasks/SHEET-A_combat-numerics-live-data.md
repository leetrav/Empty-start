# SHEET-A · 战斗基础数值与直播数据正式接线

## 开始前先阅读
- AGENTS.md、known_traps.md、project.godot、docs/Original/任务卡模板.md
- tools/README.md、data/source_tables/05_关卡生成.csv、06_战斗数值.csv、06_生命周期.csv、06_基础参数.csv、08_Tier档位.csv、09_直播数据.csv
- core/combat/、systems/barrage_generation/、systems/combat_attack/、core/live_data/ 的现有源码和系统案

## 已经实现的功能
最新 main 包含正式四关和 Tier Resource、基础战斗/直播业务。部分表值尚未接到实际游戏。

## 本次任务
1. 核对 05/06/08/09 每一个已填字段，形成 CSV 字段与实际消费者、单位、测试结果的映射。
2. 使 PK 收益、命中处罚、回拉、蓄力、生命周期、各 Tier 运动概率、同屏限制、直播观众和粉丝数等依据正式数值生效。
3. 负责 core/combat、systems/barrage_generation、systems/combat_attack、core/live_data 相关运行时文件和独立配置。中央 scenes/sandbox/sandbox.gd 由 Lane E 统一集成；data/sandbox/playable_battle_config.tres 由 Lane B 处理。对外给出明确的调用接口。
4. 使用 Godot 4.7.2 真实生产关卡验收配置值；对每条改变记录真实值、预期值和证据。
5. 独立子任务 commit，日志 docs/Integration/战斗表接线_SHEET-A_2026-10-15_log.md，独立 PR，总控 Review 合并。

## Godot 开发环境
Godot 4.7.2，GDScript，1920×1080，Windows/Android；Godot-MCP-Native、godot_mcp。

## 执行要求
先读 AGENTS.md 和任务卡模板14项，最小必要改动，每子任务commit，真实 Godot 验证，截图保存 D:/tmp，完成日志和 PR。

## 验收标准
主要已填参数真实生效，逐字段指出消费位置和测试证据，缺字段给准确来源表行号。
