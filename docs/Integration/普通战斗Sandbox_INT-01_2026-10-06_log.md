# 普通战斗 Sandbox INT-01 任务日志

日期：2026-10-06

状态：普通战斗可玩集成完成

分支：`codex/int-01-playable-battle-sandbox`

起点：`c9fdbf2`，开工 fetch 后 HEAD、main、origin/main 一致；工作树无未提交改动。

## 本次完成

Sandbox 已组合关卡、生成、特性、攻击、结算、对手回拉、Tier、复读、直播数据与三项倾向。玩家可以移动准心、按住左键蓄力、未满释放取消、满蓄释放命中，看到 PK、Tier 和复读变化；暂停冻结本场推进，归零后可以重开同一关，满值后停在矛盾击破接入点。

旧中央 SANDBOX / 原型说明 / Reload / MainMenu 大面板已移除。重开当前关和返回主菜单放入 PauseMenu；失败页另外提供真实可点击的重开按钮。

## 主要修改文件

- `scenes/sandbox/sandbox.tscn`、`sandbox.gd`、`sandbox_battle_hud.gd`：三列直播主界面、本场生命周期和只读反馈。
- `data/sandbox/sandbox_battle_config.gd`、`playable_battle_config.tres`、`attack_timing.tres`：独立运行配置，未引用测试 fixture。
- `systems/combat_attack/attack_charge_input.gd`、`aim_reticle.gd`：战斗停止入口、逐目标内容事实、复读零收益与鼠标事件坐标转换。
- `systems/barrage_generation/barrage_area.gd`、`barrage_runtime_record.gd`：生成通知、指定实例结束、清场、复读身份、原句文本、空位排布与生成 Timer 周期保持。
- `core/combat/opponent_pk_bar.gd`：重开时解除失败锁，保留本关连败。
- `ui/live_data/live_data_hud.gd`：显式重绑定当前直播数据。
- `ui/pause_menu/pause_menu.gd/.tscn`：重开请求与按钮。
- `tests/integration/int_01_playable_battle_sandbox_test.gd/.tscn`、`tests/combat_attack/test_int01_attack_boundaries.gd`：真实场景 / 输入 / Timer 的集成与边界验证。
- 系统 2、3、4、5、6、7、8、9、10、17 的 README 与 `known_traps.md`。

新增脚本的 `.uid` 与修改一起保存；编辑器顺手生成的无关资源导入文件、旧脚本 UID 和 project.godot 重排不属于本卡提交。

## 最终 Scene Tree

```text
Sandbox
├── Background
├── BattleHud
│   ├── PlayerStreamerArea
│   │   ├── PlayerName / StreamerRole
│   │   ├── PlayerPortraitPlaceholder
│   │   └── LiveDataHud
│   ├── BattleArea
│   │   ├── PKBar
│   │   ├── BarrageArea
│   │   ├── ChargeFeedback
│   │   └── BattleStateFeedback
│   └── OpponentStreamerArea
│       ├── OpponentName / StreamerRole
│       ├── OpponentPortraitPlaceholder
│       └── TierFeedback
├── AimReticle
├── AttackChargeInput
│   └── Timer（运行时）
├── FailureOverlay
│   └── RestartButton
├── PauseMenu
└── OpponentPKBar（运行时）
```

布局读取已有 `StageLayoutProfile`：1920×1080，左右各448×1080，中央1024×1080，PK条1024×72，直播数据448×296。中央实际弹幕子区域为1024×896，底部蓄力区112高；反馈透传鼠标，弹幕区域裁剪越界内容。BattleHud 按实际窗口整体缩放；GUI 已在1152×648检查。占位立绘等待美术替换。

## 最小公开接口与数据归属

- `BarrageArea.barrage_generated(view)`：实例成功入树并定位后通知一次，Sandbox 据此给 LiveSessionData 计1条评论。
- `BarrageArea.end_barrage(instance_id)` / `clear_barrages()`：弹幕系统结束实例并归还容量；清场停止普通生成，包括同帧已排队释放的视图。
- `BarrageRuntimeRecord.is_repeat` / `original_sentence_text`：保存生成时的内容类别与原句事实。
- `AttackChargeInput.set_combat_active(active)`：停止输入并取消蓄力、快照、飞行、硬直和 Timer。同步结算回调停止后不会重新进入硬直。
- `shot_hit_resolution_submitted` 的 `hit_resolution_result.target_results` 补充 `original_sentence_id`、`original_sentence_text`、`source_id`、`is_repeat`、`tendency_id`、`tendency_delta`、`is_valid_hit`；协调方无需回读已经结束的视图。
- `OpponentPKBar.reset_current_attempt()`：解除本次失败锁与旧结算绑定，连败继续由同一个对象保存。
- `LiveDataHud.bind_live_session(session)`：只读订阅当前 Resource，断开旧订阅并立即刷新。
- `PauseMenu.restart_requested`、`Sandbox.restart_current_attempt()`：当前关原地重开请求与生命周期协调；顶层返回主菜单仍走 SceneRouter。
- `SandboxBattleHud` 的 `refresh_pk()` / `refresh_attack()` / `show_battle_state()` / `show_failure()` 等方法仅更新显示。

PK归HitResolution；Tier归CombatStage；回拉与连败归OpponentPKBar；场上实例归BarrageGeneration；攻击归CombatAttack；队列和统计归Repeat；倾向、直播数据继续归SaveData所持有的对应Resource。

## 运行时原型配置

| 字段 | 当前值 | 来源 / 用途 |
| --- | --- | --- |
| charge_time_s | 0.20 s | 本任务卡临时攻击时长 |
| projectile_flight_s | 0.10 s | 本任务卡临时攻击时长 |
| recovery_time_s | 0.15 s | 本任务卡临时攻击时长 |
| 初始 / 最小 / 最大 PK | 0.5 / 0 / 1 | 独立Sandbox配置 |
| base_pullback_speed | 0.001 PK/s | 临时试玩值，乘当前Tier倍率；等待策划调参 |
| normal_lifetime_seconds | 10 s | 新普通弹幕再乘生成时Tier寿命倍率 |
| repeat_lifetime_seconds | 6 s | 创建计划时固定，等待策划调参 |
| maximum_pending_repeat_count | 96 | 临时普通复读等待容量 |
| repeat_screen_cap | 24 | 临时复读同屏容量 |
| repeat_display_template | `复读 · {原句}` | 临时可辨识模板 |

关卡词库、基础批次/间隔/速度/容量和Tier表继续读取现有资源，普通强度1收益保持HitResolution的0.0012 PK与1点倾向。Viewer / Like事件增量、初始粉丝和开播倍率缺少正式数值规则，沿用数据入口与UI，当前直接启动粉丝数为0。

## 完整数据流与边界

1. 本场就绪后初始化或复用内存SaveData，显式绑定直播HUD；读取当前LevelRunState配置并新建HitResolution、CombatStage和RepeatDelayQueue。
2. 绑定CombatStage到结算、生成、回拉和AudioManager，调用begin_combat同步Tier0，注入攻击配置并启动普通生成和回拉。
3. 鼠标释放记录目标；飞行到达复核和Trait结果进入HitResolution，整发PK同步通知CombatStage更新最终Tier。
4. 攻击提交后，正常/反弹结果结束对应实例，遮挡结果保留。有效普通结果记录本场倾向，并读取最终Tier与复读数量建立计划。
5. RepeatDelayQueue推进0.5～3秒等待并请求真实复读；容量或显示位置不足时保留到期请求重试。成功生成才记复读统计和评论。
6. 复读可以真实命中，PK与倾向为0，不进入普通命中历史，也不产生递归复读。
7. 暂停冻结生成、移动、寿命、复读等待、蓄力、飞行、硬直和回拉；恢复后继续。
8. 归零后停止输入/回拉/生成，清场和等待队列，回滚本场倾向并显示失败页。重开新建本场结算和统计，恢复PK、Tier0、READY和生成；保留同一SaveData、LevelRunState、入关粉丝及此前成果。
9. 满值同步停止回拉/生成；本发倾向和命中历史处理完后停止输入、清场并清空普通复读等待，保留满值和本场记录。

同一行的候选实例必须与已有实例保持空间间距；没有可用位置时不算生成成功。释放容量仅恢复已停止的生成Timer，避免频繁命中推迟正在运行的批次周期。

## 实际验证

- Godot版本：`4.7.2.stable.steam.ed1daf0bf`。
- 完成真实项目导入，全局脚本类缓存包含新增SandboxBattleConfig。
- 修改的纯业务脚本及HUD脚本单文件解析通过；直接 `--script` 检查包含Autoload的Sandbox/PauseMenu/场景runner会遇到已知KT-25，改用真实场景启动确认其编译与运行，未临时删Autoload或改项目入口。
- 正式Sandbox真实场景runner：**84/84通过，进程退出0，stderr为空**。覆盖输入蓄力取消/满蓄、普通/复读有效命中及实例结束、PK/Tier四倍率与旧快照、结算后复读数量、实际延迟生成/统计/Comment、暂存倾向、暂停各阶段与寿命补偿、真实回拉降档、失败/重开/历史保留、满值最后一发与冻结。
- 攻击边界runner通过：复读零收益/历史隔离、同步停止重入、同帧清场容量、重复结束、实际生成通知；已有BarrageGeneration五份runner共六个核心case通过。
- 最后补充空间与Timer实际probe通过：重叠位置拒绝普通/复读并释放容量；移开阻挡实例后可生成；运行中移除非满容量实例保留Timer剩余时间。临时probe源码已删除。
- Godot-MCP-Native通过本地9081连接**本任务工作树**，实际打开并检查编辑器与运行时Scene Tree，运行完整GUI并查看截图，中央已移除旧Panel，左右主播区/PK/直播/蓄力反馈可见。
- GUI经真实鼠标输入完成普通命中：提示`PK +0.12%`，正常命中历史1条，倾向暂存1，3条复读实际生成，Comment为15（含期间成功生成的普通弹幕）。
- GUI实际点击失败页重开按钮：失败遮罩关闭，PK恢复约0.5并继续回拉，Tier0，攻击可用。
- 最后GUI运行Debugger捕获仅有引擎启动与嵌入窗口提示，无新增战斗错误。第二编辑器插件初始化产生过`Cannot change port while server is running`，doctor仍确认9081正确连接；该日志来自插件端口UI初始化，未修改addons。
- 最后GUI截图保存在本工作树 `.godot/int01-playable-sandbox.png`，属于临时验证资产。
- Windows GUI版Godot验证使用Start-Process -Wait并检查真实PASS输出，未将命令提前返回的0码视为通过；`git diff --check`通过。

## ContradictionBreak与剩余工作

main当前没有ContradictionBreak运行代码/公开入口，`Sandbox._complete_normal_combat()`显示“普通战斗完成 / 等待进入矛盾击破”。该处为下一张卡的真实接入点。本场倾向、普通命中与复读统计尚未跨关提交，后续胜利流程应从现有所有者读取并完成提交。

策划继续调独立Sandbox配置与现有关卡/Tier表；美术替换主播占位块、示例词库和临时模板。Viewer / Like事件规则等待明确数值。本卡未增加FinalOracle、Assimilation、Scripture、LoserCard、Rest、DivineDescent或Ending流程。

Android适配、本场完成后的跨关历史提交、真实Sandbox中的特殊Trait组合与所有飞行目标失效组合仍待对应后续任务；当前普通空TraitSet战斗链已验收。

## 接手入口与文档

从本任务卡、`scenes/sandbox/sandbox.gd`、`data/sandbox/playable_battle_config.tres`及集成runner开始。GUI直接运行正式Sandbox即可试玩；下一阶段从`_complete_normal_combat()`接入矛盾击破。

已同步系统2/3/4/5/6/7/8/9/10/17的正式文档。`known_traps.md`新增KT-29（直接启动初始化）、KT-30（headless输入坐标）与KT-31（释放容量重置Timer）。原始资料和其他任务日志保留。
