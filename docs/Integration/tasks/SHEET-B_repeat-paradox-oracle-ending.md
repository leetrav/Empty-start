# SHEET-B · 10／11／12／15 复读、矛盾、神谕与神降临

## 开始前先阅读以下文档
- `AGENTS.md`、`project.godot`、`known_traps.md`、`docs/Original/任务卡模板.md`
- `tools/README.md`、`docs/2. LevelConfiguration/关卡配置系统_LC-10_2026-10-15_log.md`、`docs/Integration/正式数据接线_INT-14_2026-10-15_log.md`
- `data/source_tables/` 对应原表及相关系统 docs/README、现有代码/Resource、真实场景

## 已经实现的功能
- 最新 main `1cd2fbd` 包含 27 张正式 CSV、四关 LevelProfile/163 条词库、Tier Resource、现有 Sandbox 框架；`--approved-csv` 已能产出部分 Godot Resource。
- 内测包已证实大量字段仍读旧 Resource/常量或只有存储没有消费者。真实验收必须核对来源表字段是否在运行时体现。
- Windows Godot 4.7.2 路径：`D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`。仓库需遵循 AGENTS 的 Git/Godot 双 MCP 工作流。

## Godot 开发环境
- Godot 4.7.2，GDScript，1920×1080，Windows x64、Android ARM64；工程操作 MCP Godot-MCP-Native、官方文档 MCP godot_mcp。

## 执行要求
按 `AGENTS.md` 与标准任务卡14条逐项执行。只提交本 Lane 责任内的源代码、自动化验收、任务日志。每个子任务独立 commit；完成写 `系统_卡号_2026-10-15_log.md`；在自己的独立分支推送并创建 PR，等待总控审查合并。用 Godot 4.7.2 实测生产配置，记录命令、退出码、有效行为；截图/视频在 D:\tmp 供真人视觉验收。同步最新 main 时优先保留已批准表值。遇到字段来源确实缺失，按表号、稳定 ID、字段与运行表现出具待补清单。跨 Lane 接口只定义最小稳定调用并在 PR 描述精确注明接口。

## 本次任务
1. 对照 `10_复读配置`、`11_矛盾参数`、`12_神谕参数`、`15_神降临` 逐字段打通实际游戏消费者。已查明确凿偏差：10 表 contradiction_repeat_lifetime_s=10，生产 `data/sandbox/playable_battle_config.tres` 仍为6；15表 new_word_decay_s=12，`data/divine_descent/divine_descent_decay_config.tres` 为60。
2. 11 表 `paradox_window_seconds`、`paradox_shot_limit`、`paradox_motion_mode`、`paradox_motion_duration_seconds`、`paradox_motion_speed_curve_id` 等已在 LevelProfile，当前运行中没有消费者；要由真实矛盾生成/窗口/运动逻辑消费，设置值追踪及回归。
3. 明确拥有 `core/contradiction_oracle/`、`core/repeat/`、`systems/contradiction_break/`、`core/final_oracle/`、`core/divine_descent/`、`data/repeat/`、`data/divine_descent/`、`data/sandbox/playable_battle_config.tres`。按需要新增小型正式 Resource 读取函数；Sandbox 统一接线由 Lane E 完成。
4. 在 Godot 4.7.2 的正式关卡验证 10 秒窗口、1 发限制、1真5假、2 秒运动、复读 10 秒、衰减12秒及暂停、重开、结算。逐字段对照本表所有已填值。

## 验收条件
真实生产战斗 Paradox/Oracle/DD 消费表值，10秒与12秒等差异已修复，逐字段回归与实际 Godot 记录可查。

## 完成日志
`docs/Integration/矛盾复读神降临表接线_SHEET-B_2026-10-15_log.md`

## 最终汇报
列出每张表的已实现字段和具体消费者位置、真实 Godot 实测和退出码、PR 链接；提供仍需策划/美术填写的表号行号。
