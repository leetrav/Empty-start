> 2026-10-19最新费米开局：T0黑屏等待静音；开始连线后播放原曲开头的柔和引子（比战斗基准低约6dB、3500Hz低通、首次淡入2.4秒），开场对白期间保持。真实combat_connected对白完成后，下个小节进入正常战斗段。T1低、T2/T3中、T4/T5高；退回T0恢复静音。共四个片段，17表77行、27行有资源。旧79.2秒预览仅作历史参考。

## AU-03 费米三段音乐接入（2026-10-18）

### 当前可运行正式第一关（2026-10-18追加）
用户要求先在第一名Boss实际战斗中试听，已将同一TierMusicPresenter接到当前main的Sandbox费米关。F5走原菜单/开场/房间后，进入费米T0静音等待；也可直接打开 `scenes/sandbox/sandbox.tscn` 按F6进入首关。主场景路径与玩法规则均未改变，仍是上游已提交的旧战斗流程。

Sandbox从attempt_started识别alien，读取真实Tier变化、暂停、失败、满PK、矛盾结果与休息事实；重开恢复T0静音等待。CombatStage.bind_audio_manager新增默认true的enable_music_requests参数，BattleAttemptFlow只对alien关闭旧Tier切曲，升档音效仍保留；其他三关沿用原接线。

真实正式场景验证通过开局、PK66%中段、92%高段、暂停续播、重开、失败淡出、100%高段及退出清理。完整Plan B四关仍未交付，不能把这次旧流程首关接线当成新玩法完整集成。


费米使用《Teek Teek Teek》：T0静音，连线/对白柔和引子，完成后T1低、T2/T3中、T4/T5高。资源在 `assets/audio/music/fermi/`，来源和署名见该目录README；正式结尾页和试听场景已有署名。17表新增 `music_alien_intro/low/mid/high` 四个Music事件，Resource配置保留相同引用作为兼容；共77行，27行有资源、50行仍空。旧泛用 `music_battle_t0～t5` 未填费米曲，其他Boss不会误用。

Sandbox调用begin_connection()与finish_connection_dialogue()，分别对应连线开始和本次真实对白完成；对白期间Tier请求只更新后续目标，不抢占引子。引子切战斗段采用顺序淡变：0.3秒淡出并停止引子，再0.3秒淡入战斗段，不同时混入不同旋律；其余战斗组仍用原0.6秒交叉淡化。无对白演出的独立Plan B原型仍按Tier直接试听战斗段。

`TierMusicProfile` Resource 保存ID映射、100BPM/4拍、降档2秒、费米交叉淡化0.6秒；`TierMusicPresenter` 是场景拥有的消费者，不创建播放器、不计算PK。组合根创建后调用 `bind_host(host)` 接入 `tier_changed`、`battle_state_changed`、`battle_ended`，用于当前可运行费米原型。正式Plan B合入时按同样公开事实组合，并协调旧CombatStage音乐请求，不能将当前原型接线冒充四关已完成。

- 同组保持播放；跨组用实际音频位置等待下一小节；帧越界小偏移带入新段，属于帧级调度，不宣称采样级无缝同步。
- 降档稳定2秒，等待期间进一步降低目标保留稳定时间；重新上升到正在播放的组取消。等待中只保留最新目标。
- 暂停音乐与过渡一起暂停并冻结等待；恢复接着播。重开清理旧请求并在T0静音等待。
- 满PK停止响应Tier，使用高段；正式矛盾击破继续调用原 `fade_to_silence()`。当前独立原型只发进入矛盾事实，完整击破演出仍待正式流程交付。
- 失败淡出；场景释放停止；其他阶段接管/停止音乐会使旧消费者失效，不再抢播。

AudioManager的兼容扩展：`change_music(event_id, cross_fade_seconds=-1, from_position=0, fade_in_seconds=-1, overlap=true)`；省略参数保留原默认。新增 `get_music_event_id()`、`get_music_position()`、`get_music_length()`、`set_music_paused(bool)` 与 `music_changed` 事实信号。`Music`事件音量增益和淡化/duck分别计算，换播放器时不丢失表中音量；SFX/UI保持原入口。

试听：Godot打开 `scenes/demos/au03_fermi_music_preview.tscn` 按F6，先点“开始连线/开场对白”，再点“开场对白结束”查看阶段衔接；直接点击T1～T5用于跳过对白快速试听战斗段。可测试暂停、重开、满PK、击破和失败。正式项目F5入口未更改。`scenes/plan_b/fermi_battle_demo.tscn` 启动战斗后也接入真实主控事实。其他Boss与开场/休息/终局仍待选曲实施。

验证见 `tests/audio/README.md` 和 AU-03日志。程序检查通过不等于已经完成人耳循环接缝与新玩法四关验收。

# Audio 共用音频接入

## INT-18D 实际事件覆盖（2026-10-16）

- 生产菜单按钮已绑定 ui_click；身份姓名确认、选卡、身份确认、无选择错误分别消费正式稳定 ID。没有修改路由/Boot 或存档规则。
- 漫画使用 `create_event_player()` + `play_event_player(player)`，声音随原场景释放；volume/pitch 从 17 表读取，删除了 UI 内覆盖表值的 -10/-6dB。`event_played` 同时报告场景独占声音，供核对实际播放器参数。
- `hud.bind_trait_audio(runtime)` 消费 C 的 `split_children_spawned`：有真实子体时整次仅播放一次 trait_split，零生成安静。大幅推进定义为本发净正收益达到正式 06 单发正收益上限，沿用该配置值，不新增阈值。
- `bind_audio_flows()` 在 DD entered 后延迟绑定真实 `sentence_locked`，自动锁句播放 divine_descent_lock；原输入强调声音保留。空历史没有 Spread，因此不会播放锁句音。

1920×1080、1280×720 两档正式组件组合中，23 个已映射音效均由真实 UI/攻击/生成/阶段/确认/锁句来源触发，逐项核对播放器音量/音高。素材试听与实际事件记录分开；六档音乐及其余空路径仍属资源缺口，详见 [INT-18D 日志](../../Integration/INT-18D_2026-10-16_log.md)。

## INT-17D 正式消费端（2026-10-16）

`AudioManager._ready()` 已注册 17 表可加载的 23 个事件，先于 Boot、菜单和身份场景；Sandbox 再次注册同 ID 为覆盖行为。`bind_ui_button(button, event_id=&"ui_click") -> bool` 供 UI 拥有者绑定点击/确认/切换。`event_played(event_id, player)` 仅在池播放器实际执行 `play()` 后发出，可核对音量、音高和资源。

HUD 原有 `bind_portrait_attack()` 同时绑定 `BattleAudioPresenter`：读取真实按住/满蓄上升沿、正式发射、最终整发结算与 `BarrageArea.barrage_generated`，播放 charge/ready/fire、normal/trap、spawn/repeat 音效；生成音有可调的 0.15 秒短限流。复读零收益不会冒充普通命中。

INT-16 创建 Flow 后调用 `hud.bind_audio_flows(oracle_flow, divine_flow)`，接收实际矛盾进入、成功结果、神谕提交成功与终局会话建立事实。Tier 升档音由现有 CombatStage 负责，锁句由现有 Spread 负责。A 已提供的 `music_event_requested -> AudioManager.change_music` 与音乐素材状态分开验收：17 表六个 Tier 音乐行目前均无资源，当前无法播放；音乐分层、节拍同步仍按原音乐待办处理。

短剧情 `create_event_player()` 现在同样应用表内 volume/pitch。23 行均 `loop=false`，SFX/UI 非循环与播放器参数已做真实 GUI 验证；未以此宣称未来循环音乐/组过渡验收通过。50 个缺文件 ID、尚缺生产请求的事件与本机录音见 [INT-17D 日志](../../Integration/生产集成_INT-17D_2026-10-16_log.md)。

## 当前底座

项目已经有：

- `AudioManager` Autoload，维护当前主音乐和交叉切换时的旧曲播放器；
- `Music`、`SFX`、`UI` 三条 Audio Bus；
- Master / Music / SFX / UI 独立音量设置；
- `AudioManager.play_music(stream)`；
- `AudioManager.stop_music()`；
- `AudioManager.play_sfx(stream)`；
- `AudioManager.play_ui(stream)`。

## AU-01 事件播放

- `AudioEvent` Resource 保存稳定事件 ID、`Music / SFX / UI` 类型和 `AudioStream`。
- `AudioEventConfig` 集中保存事件列表，配置文件为 `data/shared/audio_event_config.tres`。
- 玩法系统通过 `AudioManager.play_event(&"attack_fire")` 播放；管理器按事件类型调用音乐状态切换或 SFX / UI 播放池。
- 当前稳定事件 ID 包含 `attack_charge`、`attack_ready`、`attack_fire`、`hit_normal`、`hit_trap`、`tier_up`、`contradiction_start`、`contradiction_break`、`oracle_confirm`、`divine_descent_start` 和 `divine_descent_lock`。
- 当前音效素材是占位引用；`oracle_confirm` 使用 `assets/audio/sfx/interface/confirmation_001.ogg`，随目录保留 Kenney CC0 授权文本。正式素材到位后只替换各事件的 `stream` 引用，事件 ID 保持稳定。
- 仓库尚无正式音乐文件，因此配置暂时没有 Music 类型事件；新增音乐事件时，将其类型设为 Music 并引用正式 `AudioStream`，循环由素材的导入 / Stream 配置提供。AU-02 已提供音乐状态切换能力。

资产目录：

```text
assets/audio/
├── music/
└── sfx/
```

## 当前事件与状态入口

玩法系统需要用稳定事件调用音频，例如：

- attack_charge
- attack_ready
- attack_fire
- hit_normal
- hit_trap
- tier_up
- contradiction_start
- contradiction_break
- oracle_confirm
- divine_descent_start
- divine_descent_lock

## AU-02 音乐状态切换

| 公开入口 | 行为 |
| --- | --- |
| `change_music(event_id) -> bool` | 读取已有 Music 类型事件，首次淡入；换曲时两播放器交叉切换；缺失、空 Stream 或其他事件类型返回 `false` 并告警 |
| `fade_out_music()` | 按配置淡出，然后停止并清空音乐 |
| `duck_music()` | 平滑压低当前及过渡旧曲，重复请求取同一倍率 |
| `restore_music()` | 平滑恢复压低倍率，保留播放位置；已经停止的音乐由新播放请求启动 |
| `fade_to_silence()` | 按击破静音配置淡出并停止，保持静音，完成时发送 `music_silenced` |
| `play_music(stream)` / `stop_music()` | 保留原有立即播放 / 停止入口；停止会取消所有音乐 Tween 并清理两播放器 |

- `play_event()` 的 Music 类型复用 `change_music()`；SFX / UI 继续使用原播放池。
- 当前音乐由主播放器的 Stream 表达，换曲完成后只保留该曲。新请求取消旧过渡及完成回调；交叉尚未结束时第三首到来，会回收最旧淡出尾音，始终只使用两播放器。
- 淡变使用 Godot 原生 [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) 和 [AudioStreamPlayer.volume_linear](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html#class-audiostreamplayer-property-volume-linear)。每首淡变和共同 duck 分别控制增益，允许换曲期间压低及恢复。
- Music Bus 的玩家音量 / 静音继续由 SettingsManager 管理；状态变化只改变播放器增益，因此用户调节音量后 restore 保留新设置，用户静音也保持有效。
- `music_silenced` 只通知已完成的静音；过渡被新换曲 / 立即停止请求替代时不发送旧完成信号。后续联调方可先连接一次回调，再请求 `fade_to_silence()`，在回调中请求下一阶段音乐；时长为 0 时信号立即发送。

### 统一音频配置

时长和 duck 倍率均在 `data/shared/audio_event_config.tres`，由现有 `AudioEventConfig` 提供字段：

| 字段 | 当前值 |
| --- | --- |
| `music_fade_in_seconds` | 0.5 秒 |
| `music_fade_out_seconds` | 0.5 秒 |
| `music_cross_fade_seconds` | 0.75 秒 |
| `music_duck_seconds` | 0.2 秒 |
| `music_restore_seconds` | 0.3 秒 |
| `music_silence_seconds` | 0.25 秒 |
| `music_duck_volume` | 0.25 线性倍率 |

这些是当前可调起点，最终节奏由实际听感确认；零时长直接完成，压低倍率限制在 0～1。生产配置运行时只读，管理器持有同一 Resource 引用查询字段。

本卡未向 8 / 12 / 13 / 19 或 Sandbox 接线；对应系统在自己的联调卡调用以上接口。实际音乐素材仍待交付，正式事件 ID 与 Stream 由音频配置提供。

## 任务

| 任务卡 | 功能 | 单元测试 |
| --- | --- | --- |
| AU-01 | 游戏音频事件配置与播放入口 | 无 |
| AU-02 | 音乐状态切换 | 无 |
| [AU-03](tasks/AU-03_bgm-assets-and-planb-integration.md) | 正式BGM与Plan B接入；费米局部已实现，其他场景待定 | 人工试听与运行验收 |

玩法系统完成自己的核心逻辑以后，在对应表现联调卡里调用这里已经存在的公开接口。

## INT-14 正式事件音频表运行时接入（2026-10-15）

`FormalSheetRuntimeConsumer` 在 Sandbox 建场时读取 `data/source_tables/17_音频事件.csv`。对有可加载资源路径的行，按原 `event_id` / `audio_type` / `AudioStream` 调用 `AudioManager.register_event(event) -> bool` 覆盖现有同 ID 事件或追加新事件；空路径继续沿用现有兼容配置。玩法继续通过 `AudioManager.play_event(event_id)` 播放。当前正式表有 73 行，其中 23 行提供已匹配资源，50 行没有资源路径；后者不会生成静音占位。

## SHEET-C 正式音频字段消费（2026-10-15）

`AudioEvent` 同时保存 `volume_db`、`pitch_min`、`pitch_max`、`loop` 和 `transition_group`。正式事件注册时由 CSV 映射这些字段；SFX/UI 播放器应用配置音量与随机音高，`loop=true` 的事件在当前播放完成后重播。`transition_group` 保留在事件数据上供同组事件识别；当前没有按组切换/淡出的运行规则。Music 事件沿用现有音乐状态入口。`tests/integration/sheet_c_runtime_consumer_test.gd` 实际加载了 23 个有资源的事件；50 个缺资源事件见 SHEET-C 日志。
