# R26-A 05/06/08/09 战斗数据全字段消费日志（2026-10-16）

## 本次实现

- `05_关卡生成.csv` 的四个正式关卡已由 `make_formal_levels()` 逐行生成到 `level_001`～`level_004`。四行均为批次 3、间隔 1.6 秒、速度 45 px/s、词重倍率 1；`BarrageArea.start_normal_generation()` 消费批次/间隔，普通实例消费速度与词重。I 列 `special_instance_screen_cap` 四行留空，正式关卡导表回退至 06 `special_foreground_instance_cap=3`。四行的 valid area/layout 键为 `center_valid_area` / `battle_layout_01`。05 已填写字段均有生产 Resource 和生成消费者。
- 06 战斗数值由 `CombatNumericsConfig` 提供正式运行值；强度 1/2/3 的 `word_strength_*_pk` 百分点按 1/100 转成运行时 PK 比例 `0.004/0.007/0.012`，由 `HitResolution` 汇总单发结果。`0.4/0.7/1.2` 在现有正式配置验证脚本中逐项核对。
- 06 Tier 的普通前景运动权重由 `CombatStage` 在 Tier 变化时通过 `barrage_foreground_motion_weights_changed` 推送到 `BarrageArea.set_foreground_motion_weights()`。正式 `tier_catalog.tres` 已包含 0～5 六档权重；验证脚本检查 Tier 2 的 `50/25/15/10`。
- 06 局部动画强度 `foreground_local_anim_intensity=0.2` 现在传入 `BarrageView.apply_random_local_text_animation(probability, intensity)`，缩放 shake、pulse、wave、tornado 的表现幅度。描边宽度/颜色 `2 px / #30272F` 及复读文字色 `#888888` 由正式配置应用于后续生成的 BarrageView。
- 09 的矛盾击破 `+80 viewer / +40 like / 2s` 与神谕确认 `+40 / +20 / 2s` 从 `CombatNumericsConfig` 进入 `LiveSessionData.start_short_boost()`。`export_game_data.py --approved-csv` 新增 09 两规则到生产 `combat_numerics.tres` 的生成映射；字段必须是数字，人数必须为整数。Resource 当前显式保存 CSV 值。
- 已有 09 正常命中、陷阱命中、升档、高 Tier 点赞、PK 胜利粉丝和开播随机观看规则继续由 `LiveSessionData` / `BattleAttemptFlow` 消费。普通弹幕和复读的评论数仍按成功生成实例数增加。

## 字段审计与缺口

| 表 / 字段 | 状态 | 消费位置或缺口原因 |
| --- | --- | --- |
| 05 `base_batch_count`、`spawn_interval_s`、`move_speed_px_s`、`word_weight_multiplier` | PASS | 正式 `LevelProfile`；`BarrageArea` 生成循环与选词 |
| 05 `valid_area_key`、`layout_key` | PASS（配置标识） | 写入正式 `LevelProfile`；具体区域布局由场景配置负责 |
| 05 `special_instance_screen_cap` | PASS | 空值回退到 06 全局值 3；特性实例容量账本消费 |
| 06 战斗 PK、命中、时序、准心、惩罚、单发限幅、特殊容量及运动/显示参数 | PASS，见上文和 Resource | `CombatNumericsConfig` 及对应系统；0.4/0.7/1.2 已逐项验证 |
| 06 生命周期 `base_lifetime_s` / `affected_by_tier_lifetime_mult` | PASS | `CombatNumericsConfig.get_lifetime_seconds()` 按类型及当前 Tier 倍率计算实例固定寿命 |
| 06 `foreground_curve_strength=0.2` | 待接入 | 该字段以比例描述弯曲幅度，现有 BG-21 使用像素弧高 `foreground_curve_amplitude_px=72`；两者缺少经策划确认的换算规则，不能自行折算。像素弧高字段已消费。 |
| 06 `opening_comic_auto_advance_interval_s` | 待填写 | CSV 为空，ID-12 注明等待策划/美术定时；没有可消费的正式值。 |
| 06 `combat_feedback_penalty_text` | 空值可选 | CSV 明确允许留空只作图形表现；当前 PA-09 表现层没有从该字段读取文本的接口。 |
| 06 `aim_visual_size` | 未接入 | 96×96 仅表现尺寸；准心判定半径另由 06 战斗数值消费，当前准心 Scene 使用自身视觉布局。 |
| 06 `streamer_bubble_simultaneous_cap_per_side` | 已有专用系统参数 | 需要对照 SD-03 的气泡消费者；本次数值运行验证未触发对白流。 |
| 06 `pk_tier0_matching_text` 与 `combat_feedback_*_text`（除可选 penalty 外） | 待确认消费者 | 本次没在 05/06/08/09 数值核心消费路径找到直接读取点；状态提示/PA-09 是相邻系统职责，需 INT-16/表现系统核对接线。 |
| 09 `barrage_spawn.comment_delta`、`repeat_spawn.comment_delta` | PASS | 仅成功生成数量进入 `record_generated_comments()`；直播聊天展示流不加业务评论数。 |

## INT-16 对接契约

中央场景继续通过现有 `BattleAttemptFlow.configure(...)` 提供 `BarrageArea`；流程启动时调用 `BarrageArea.configure_combat_numerics(config)`，随后 `CombatStage.bind_barrage_area()` 发布当前 Tier 权重/倍率。不得直接依赖 BarrageArea 子节点路径。

INT-16 可在组合阶段读取当前流程信号：`attempt_started(level, hit_resolution, combat_stage, repeat_queue)` 与 `attempt_restarted(...)`；Tier 变化使用 `tier_changed(current_tier, player_pk)`。本卡没有修改 Sandbox 或存档文件，也没有新增信号。正式直播上涨由 `ContradictionOracleFlow` 直接以源 Resource 提交，运行时仍经 `LiveSessionData` 拥有计数与 `changed` 通知。

## 验证

- `godot.windows.opt.tools.64.exe --headless --path . --script res://tests/integration/sheet_a_formal_combat_numerics_test.gd`：进程 Exit 0，输出 `SHEET-A PASS production 06/08/09 Resource values and configured live boost`。实际加载生产 06/08 Resource，检查 0.4/0.7/1.2、Tier 2 四种权重及击破上涨结果 80/40。
- 同次启动报告项目环境问题：`audio_event_config.tres` 引用缺失 `assets/audio/sfx/comic/typewriter.wav`，音频 Autoload 解析失败；字体资源也缺失，并报告根证书读取错误。测试脚本仍实际执行并输出 PASS。
- 生产项目 `--headless --quit-after 3`：启动未完成，受同一缺失音频资源的 Autoload 解析错误阻断；故完整生产 SceneTree 行为为 UNVERIFIED。
- `python -m py_compile` 与 `export_game_data.py --approved-csv --csv-only`：Windows Python trampoline 拒绝创建子进程（permission denied），导表器新增映射未能执行；`git diff --check` 通过。未把该项记为 PASS。
- Godot 导入曾生成四个 `.import` 变更；确认均为本次验证副作用后已恢复，最终 `git status` 中无残留。

## 未完成 / 接手建议

1. 让策划确认 `foreground_curve_strength` 与像素弧高的映射；在规则确定后再接入，避免重复控制同一曲线。
2. 由 ID-12 提供自动翻页间隔；由 PA-09 决定 penalty 文案和其余反馈文字的正式消费者。
3. 与 INT-16 核对气泡上限、T0 状态文案及已有正式流程中的配置入口；INT-16 文件由其 Owner 改动。
4. 在具备全部字体/音频资源的正式工作树运行导表器和生产 GUI smoke；现有失败不能作为本次代码回归结论。
5. 提交 `23f8e408835f5e794e5f66db2ce0e2215344bce2`（`Wire R26 combat data into runtime consumers`）；首次 Git 元数据写入被 sandbox 拒绝，获准后提交成功。推送首次遇到 Schannel TLS 握手失败，改用 OpenSSL 后端成功推送。PR [#241](https://github.com/w7775p/Empty-start/pull/241) 已创建，目标 `main`，当前 open、未合并。

系统文档：没有修改 README；本日志记录新增的配置映射、接口契约和字段缺口。`known_traps.md` 无新增可复现陷阱。
