# R26-A · 战斗／生成／直播基础数据全字段消费

## 开始前先阅读以下文档
- `AGENTS.md`、`project.godot`、`known_traps.md`、`docs/Original/任务卡模板.md`
- `tools/README.md`、`docs/Integration/README.md`、相关系统正式设计与最新完成日志
- 本卡对应的 `data/source_tables/` 正式 CSV、生产代码、Scene 与 Resource

## 已经实现的功能
- `main@4eb4c80` 已含 27 张正式 CSV、四位主播关卡资源、SHEET-A/B/C 的部分数值与展示消费者。
- 旧导表路径有 CSV、部分 Resource、运行时消费三层；正式验证需逐字段确认三层一致。
- INT-16 独立工作树正在开发正式游戏流程，拥有 `scenes/sandbox/sandbox.gd`、`core/save/save_data.gd`、`data/level_configuration/level_run_state.gd`、`ui/rest/rest_opening_room.gd` 的当期修改权。

## Godot 开发环境
- Godot 4.7.2、GDScript、1920×1080、Windows x64／Android ARM64。Godot 工程 MCP：Godot-MCP-Native；官方文档 MCP：godot_mcp。

## 执行要求
按照 `docs/Original/任务卡模板.md` 的十四项标准执行：现状检查、范围控制、最小复杂度、组合优先、场景边界、逻辑数据归属、已有能力复用、官方 API 查证、真实 Godot MCP/CLI 验证、必要自动化、稳定引用、Resource/Scene 核对、真实行为回归、最终复检。
每个可独立完成的子任务分别 commit；在本 Lane 独立分支提交任务完成日志、测试证据和 PR。按表号、行 ID、字段名记录覆盖情况；实际运行结果和完整人工验收范围分别陈述。截图或视频保存在 `D:/tmp/` 供真人验收。

## 最终汇报
交付：改动文件、公开接口及对接责任方、原表字段到消费者的对照、Godot 运行退出码／截图、仍待策划或素材的具体 ID、提交与 PR 链接。

## 本次任务
负责正式 05 关卡生成、06 三张基础／战斗／生命周期、08 Tier、09 直播数值。逐个检查 enabled 行的值、单位、具体运行消费者和实测结果；落实射击、PK、回拉、命中、准星、运动、容量、复读生成、随机直播数据等既有系统所需字段。以现有 `core/combat/`、`systems/barrage_generation/`、`systems/combat_attack/`、`core/live_data/` 和本系统配置为主要改动范围。已合并 #236 后尚未消费的字段是主要对象；检验 Tier 前景话语数量、复读同屏限制和 06 表已填的 Motion 相关权重。为需要中央场景接线的配置提供稳定公开方法，并将接口/信号需求写进日志，交 INT-16 负责消费。补真实 Godot 配置加载与战斗数值测试，提供逐字段 PASS／待接入／待填报告。

## 本次验收条件
至少 05／06／08／09 表所有已填可实现字段都有真实消费位置与针对性 Godot 验证；保留有凭据的缺口清单，验证 0.4/0.7/1.2 及用户配置的回拉/容量。

## 完成日志
`docs/Integration/R26-A_05-06-08-09_combat_data.md_2026-10-16_log.md`
