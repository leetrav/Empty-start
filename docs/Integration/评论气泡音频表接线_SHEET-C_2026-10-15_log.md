# 评论气泡音频表接线 SHEET-C 完成日志

日期：2026-10-15。分支：`codex/sheetfix-c-presentation-20261015`。基线：`main@1cd2fbd`。

## 本次实现

- 17 表：将 `volume_db`、`pitch_min`、`pitch_max`、`loop`、`transition_group` 读入 `AudioEvent`。SFX/UI 播放器实际应用音量与随机音高；循环事件播放结束后重播；Music 事件保留既有 Music 处理方式。23 条已有资源路径事件可以注册到 AudioManager。
- 19/25 表：既有 `get_comments(side_scope, streamer_id)` 按启用状态、侧、主播、`viewer_id` 关联候选，并以评论权重×账号权重抽样；HUD 逐行消费账号昵称及 fan/passersby 身份。
- 20 表：启用行按故事 ID 转为气泡对白，映射显示时长和随机权重；`random_idle` 映射为 `timed`，复用现有 Presenter 按两侧时钟随机呈现。06 表闲聊节奏读取玩家 6–10 秒、对手 7–12 秒；对手 T0 等待连线。
- 22 表：两个布尔参数转为原生 bool，其余数值参数转为 float。HUD 消费暂停布尔值、刷新间隔、滚速、显示行数、字号、行距和粉丝牌概率。评论展示不写入业务评论计数。

## 主要文件与消费者

- `data/shared/formal_sheet_runtime_consumer.gd`：17/19/20/22/25 CSV 映射；公开入口 `create_dialogue_config(story_config_id)`、`register_audio_events(audio_manager)`、`get_comments(side_scope, streamer_id)`。
- `core/audio/audio_event.gd`、`core/autoload/audio_manager.gd`：事件音频播放字段及播放器应用。
- `data/streamer_bubble_dialogue/bubble_dialogue_entry.gd`、`ui/streamer_bubble_dialogue/streamer_bubble_timed_opponent_dialogue_presenter.gd`：随机对白权重、双侧 06 表范围调度。
- `ui/live_data/live_data_hud.gd`：原生布尔暂停控制和评论展示。
- `tests/integration/sheet_c_runtime_consumer_test.gd`：生产 CSV 映射与模拟观众权重抽样。
- 更新 Audio、LiveData、StreamerBubbleDialogue 三份 README。

Sandbox 仍由 Lane E 所有；当前公开 Presenter 入口签名为 `configure(battle_attempt_flow, bubble_dialogue_config, enqueue_dialogue_bubble_callable) -> bool`，既有调用继续有效，注入的配置可含双方 timed 行。任务未改 Sandbox。

## 表格覆盖及缺项

17 表：73 行；资源可加载 23 行；缺少可用资源路径的 50 个 ID：`live_start_transition`、`streamer_intro`、`mechanic_reveal`、`barrage_strength_high`、`barrage_special`、`trait_copy`、`trait_reflect`、`trait_blocked`、`trait_unselectable`、`aim_target`、`attack_miss`、`attack_reflect`、`pk_push`、`pk_retreat`、`pk_retreat_big`、`pk_danger`、`pk_full`、`pullback_pressure`、`player_near_fail`、`battle_fail_transition`、`tier_down`、`tier_high_ambience`、`live_viewer_milestone`、`live_fan_gain`、`live_break_burst`、`repeat_crowd`、`repeat_flood`、`contradiction_spawn`、`contradiction_false_hit`、`contradiction_emphasis`、`oracle_candidates`、`oracle_select_move`、`oracle_collapse`、`assimilation_complete`、`assimilation_trait_unlock`、`music_menu_opening`、`music_battle_t0`、`music_battle_t1`、`music_battle_t2`、`music_battle_t3`、`music_battle_t4`、`music_battle_t5`、`music_failure`、`music_restart`、`music_contradiction`、`music_oracle`、`music_oracle_confirm`、`music_assimilation`、`music_divine_descent`、`music_ending`。

20 表：119 行启用，4 个 story_config 共 119 条被配置；其中 48 条 random_idle 进入双方定时调度。禁用行维持跳过。22 表两个 boolean 字段均按 bool 转换。未发现需要编造的表值。

`transition_group` 已储存于 AudioEvent，现有 AudioManager 没有按组执行过渡/淡出的规则，故该字段当前仅作为可消费元数据。对话事件按现有 `trigger_key` / `trigger_type` 映射；目前未为禁用行制造触发。

## 验证

- Godot 4.7.2 `--headless --editor --import --path . --quit`：退出 0，生成本地导入缓存。
- `--headless --path . --script res://tests/integration/sheet_c_runtime_consumer_test.gd`：退出 0；输出 `SHEET-C PASS: audio=23/23`、22 表 bool、119 条对白/48 条闲聊，以及玩家18条、Alien对手16条观众候选模拟结果。日志：`D:/tmp/sheetc_runtime_test_final.log`。
- 正式 Sandbox headless 场景启动：Godot 4.7.2 进程正常返回；日志 `D:/tmp/sheetc_sandbox.log` 只有引擎启动行。当前未完成 GUI 四主播对白/评论/音频人工验收，视觉/听感标记 `UNVERIFIED`。
- 已尝试既有 SD-07 及 INT-01 入口，但本次调用没有得到其通过摘要，不能据此标记通过。没有 screenshot/录屏。
- `git diff --check` 待提交前复检。

## 未完成与交接

- 需要 Lane E 将 20 表配置入口注入各实际关卡并人工跑四位主播，确认触发、评论流滚动与可听音频；不修改 Sandbox 的分工仍归 Lane E。
- 50 个音频素材缺项见上方 ID 清单；由音频/美术补资源路径后重新导入并验证。
- 按项目约定执行独立提交、推送与 PR；本日志不代表 PR 已创建。

本次未更新 `known_traps.md`。
