# SHEET-C · 17／19／20／22／25 音频、评论、主播对白

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
1. 正式完成 `17_音频事件`、`19_直播评论词库`、`20_主播气泡对白`、`22_直播评论表现参数`、`25_直播观众账号` 业务接线，遵从 disabled 记录。20表119条启用，其中48条 random_idle 目前未排程，请按06基础参数已有 6–10s/7–12s 两侧闲聊范围复用现有调度器，避免自行创造节奏。event/win/lose/tier_down/hit_word 使用现有事实事件。
2. 音频17表73行中23行有可加载资源：实现 volume_db/pitch_min/pitch_max/loop/transition_group 等已有音频接口能支持的字段，并验证在真实事件上生效；50条无文件资源的行按 ID 列出素材缺口。
3. 评论/观众的昵称权重、播放节奏、滚速、行数、计数参数应与实际 HUD 表现一致；确认 22 表布尔值的正确转换，交付模拟观众的测试。
4. 拥有 `data/shared/formal_sheet_runtime_consumer.gd`、`core/audio/`、`core/autoload/audio_manager.gd`、`ui/live_data/`、`ui/streamer_bubble_dialogue/` 和相关 config；Sandbox 入口配置请用公开函数让 Lane E 负责主场景接线。
5. Godot 真实 GUI 录制/截图核对四主播评论/对白触发及音频；确认随机闲聊按表及基础参数而非仅输出日志。

## 验收条件
119条启用对白对应各类可用触发；48条 random_idle 定时播放；22表评论参数与17表可用音频参数在真实游戏可观察。

## 完成日志
`docs/Integration/评论气泡音频表接线_SHEET-C_2026-10-15_log.md`

## 最终汇报
列出每张表的已实现字段和具体消费者位置、真实 Godot 实测和退出码、PR 链接；提供仍需策划/美术填写的表号行号。
