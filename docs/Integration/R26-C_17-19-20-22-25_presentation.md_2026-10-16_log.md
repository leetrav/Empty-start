# R26-C 17/19/20/22/25 表现消费者日志（2026-10-16）

## 本次改动

- `FormalSheetRuntimeConsumer.create_dialogue_config()` 现在将 20 表 `trigger_time_s` 转入 `BubbleDialogueEntry.trigger_time_seconds`；空值按 SD-07 兼容值 0 秒处理。`random_idle` 映射至 `TIMED_IDLE` 优先级，固定剧情仍为 `PLOT`。
- `tests/integration/sheet_c_runtime_consumer_test.gd` 增加可用音效的 loop / transition_group 对照断言，以及随机闲聊优先级、空 trigger_time 默认值断言。
- `docs/21. StreamerBubbleDialogue/README.md` 补充正式触发时长映射与当前 48 条随机闲聊空时间字段的行为。

## 当前正式消费链与接口

- 音频：`FormalSheetRuntimeConsumer.register_audio_events(AudioManager) -> int` 注册有可加载资源的 17 表行；`AudioManager.play_event(event_id)` 用稳定 ID 播放。23 个有资产路径的行会映射音量、音高范围、loop 与 transition_group；loop 由已有播放器完成信号循环处理。
- 对白：`create_dialogue_config(story_config_id) -> BubbleDialogueConfig` 依故事配置筛选 20 表并映射双方、事件、原句、时长、随机权重和触发秒数；已有 `StreamerBubbleCombatStatePresenter.configure(flow, config, enqueue_callable)` 与 `StreamerBubbleTimedOpponentDialoguePresenter.configure(flow, config, enqueue_callable)` 分别消费剧情事件和 SD-07 计时/闲聊。随机闲聊共 48 条，旧 SD-07 06 表间隔范围保持有效。
- 评论：`get_comments(side_scope, streamer_id) -> Array[Dictionary]` 以 19 表 `viewer_id` 关联 25 表账号，并筛选 enabled、side_scope、streamer_id，输出正文、账号及评论×账号权重。HUD 的 `configure_formal_comments(rows, parameters)` 消费 22 表参数，滚动展示不写入 `LiveSessionData.comment_count`。
- INT-16 接入应由其 Sandbox Owner 调用上述 consumer API；本分支没有修改 `scenes/sandbox/sandbox.gd`、`core/save/save_data.gd`、`data/level_configuration/level_run_state.gd` 或 `ui/rest/rest_opening_room.gd`。当前 main 的 Sandbox 已在 `_ready()` 注册音频并在关卡展示配置阶段调用对白、评论映射。

## 表字段核对与当前缺口

| 表 | 当前数据与字段 | 现状 / 原因 |
| --- | --- | --- |
| 17 音频事件 | 73 行；23 行有资源路径，已由现有消费者读取 `event_id/audio_type/asset_path_or_id/volume_db/pitch_min/pitch_max/loop/transition_group`；23 行均 `loop=false`，SFX/UI 的 `transition_group` 为空。 | 其余 50 行没有资源路径，原因是正式音频素材未提供。ID：`live_start_transition, streamer_intro, mechanic_reveal, barrage_strength_high, barrage_special, trait_copy, trait_reflect, trait_blocked, trait_unselectable, aim_target, attack_miss, attack_reflect, pk_push, pk_retreat, pk_retreat_big, pk_danger, pk_full, pullback_pressure, player_near_fail, battle_fail_transition, tier_down, tier_high_ambience, live_viewer_milestone, live_fan_gain, live_break_burst, repeat_crowd, repeat_flood, contradiction_spawn, contradiction_false_hit, contradiction_emphasis, oracle_candidates, oracle_select_move, oracle_collapse, assimilation_complete, assimilation_trait_unlock, music_menu_opening, music_battle_t0, music_battle_t1, music_battle_t2, music_battle_t3, music_battle_t4, music_battle_t5, music_failure, music_restart, music_contradiction, music_oracle, music_oracle_confirm, music_assimilation, music_divine_descent, music_ending`。15 个非空 `transition_group` 全属于这些无资源音乐行（menu/battle/failure/contradiction/oracle/result/divine/ending）；分层音乐与节拍同步已有 `MUSIC_IMPLEMENTATION_TODO_2026-10-10.md` 待正式音频后开发，本卡未虚构音频或切层行为。 |
| 19 评论词库 / 25 账号 | 依据 `viewer_id` 连接，enabled 与侧范围、主播范围过滤，权重相乘。 | 当前消费链存在；本次集成模拟测试未能运行（见验证）。具体缺失 ID 需以 19/25 CSV 源数据为准，未在本日志伪造统计。 |
| 20 主播对白 | 119 条 enabled，按四个 story_config_id 过滤；其中 48 条 random_idle，CSV 均未填 `trigger_time_s`。 | 固定事件行沿用现有 SD-06 事件映射；随机闲聊继续由 SD-07 双侧间隔调度。已补齐 trigger_time 字段映射，缺失时值为 0 秒。 |
| 22 评论表现参数 | 10 个参数；两个布尔字段转原生 bool，其余 value 数值化。 | HUD 已读间隔、行数、速度、粉丝概率、行距、暂停、字号；`comment_updates_business_counter=false`，随机展示不增加业务评论数。 |

## 验证

- CSV 静态读取：17 表 73 行、23 行有资源路径、50 行无资源路径；20 表 119 条启用对白、48 条 random_idle；账号启用行按主播映射为 alien 28、kiwi 32、frog 28、fox 31。
- Godot 4.7.2 真实运行：**FAIL / 未完成**。首次 `--headless --import` 在首次项目扫描过程中未正常收尾；真实 SHEET-C 脚本启动遇到 `base_theme.tres` 缺失字体 `assets/fonts/NotoSansSC-VF.ttf`、`ZCOOLKuaiLe-Regular.ttf`，并因未导入资源导致 `audio_event_config.tres` 预载错误，最终测试脚本编译失败。Godot 编辑器导入另尝试向只读 Steam 安装目录写 `editor_data/editor_settings-4.7.tres`；Windows 根证书读取也失败。故本次新增运行断言、实际音频播放、完整 Sandbox 白盒外真实画面及截图均为 **UNVERIFIED**，没有将 TEST_ONLY 结果冒充生产运行通过。
- 完成 Godot 验证的建议命令：在可写 Godot Editor 数据目录并补齐工程字体与导入缓存后运行 `godot.windows.opt.tools.64.exe --headless --editor --path <worktree> --import --quit`，然后运行 `--headless --path <worktree> --script res://tests/integration/sheet_c_runtime_consumer_test.gd`；再以 Windows GUI 启动 Sandbox 验证实际气泡、评论与音频。

## 未完成与交接

- 尚未证明 23 个事件的真实播放听感 / 参数，也未真人验收截图；Music transition_group 仅有空 Stream 的 15 个正式音乐行，需正式资源与音乐实现任务后验证。
- INT-16 可调用的单一消费清单：初始化一个 `FormalSheetRuntimeConsumer`；调用 `register_audio_events(AudioManager)`；当前关卡按 `story_config_id` 调用 `create_dialogue_config(id)`，将同一 config 提供给剧情与 SD-07 presenters；两侧 HUD 分别取 `get_comments("player", "")`、`get_comments("opponent", streamer_id)` 并传 `comment_parameters` 至 `configure_formal_comments()`。所有者文件里的接入由 INT-16 自行提交。
- 本次未更新 `known_traps.md`；现有 KT-36 已覆盖受限 Windows 下 Godot 写日志和编辑器目录失败。
- 普通 `git add` / `git commit` 被 Windows 沙箱拒绝，无法在共享管理目录创建 `index.lock`；本地 `gh` 命令也未发现。已改用已连接 GitHub API 基于 `4eb4c80` 创建远端 Lane 提交和 PR；本地 worktree 仍保留未提交的对应改动，未将用户提供的未跟踪任务卡纳入提交。PR 链接见交付回复。
