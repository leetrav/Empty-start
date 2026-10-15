# Audio 共用音频接入

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

玩法系统完成自己的核心逻辑以后，在对应表现联调卡里调用这里已经存在的公开接口。

## INT-14 正式事件音频表运行时接入（2026-10-15）

`FormalSheetRuntimeConsumer` 在 Sandbox 建场时读取 `data/source_tables/17_音频事件.csv`。对有可加载资源路径的行，按原 `event_id` / `audio_type` / `AudioStream` 调用 `AudioManager.register_event(event) -> bool` 覆盖现有同 ID 事件或追加新事件；空路径继续沿用现有兼容配置。玩法继续通过 `AudioManager.play_event(event_id)` 播放。当前正式表有 73 行，其中 23 行提供已匹配资源，50 行没有资源路径；后者不会生成静音占位。

## SHEET-C 正式音频字段消费（2026-10-15）

`AudioEvent` 同时保存 `volume_db`、`pitch_min`、`pitch_max`、`loop` 和 `transition_group`。正式事件注册时由 CSV 映射这些字段；SFX/UI 播放器应用配置音量与随机音高，`loop=true` 的事件在当前播放完成后重播。`transition_group` 保留在事件数据上供同组事件识别；当前没有按组切换/淡出的运行规则。Music 事件沿用现有音乐状态入口。`tests/integration/sheet_c_runtime_consumer_test.gd` 实际加载了 23 个有资源的事件；50 个缺资源事件见 SHEET-C 日志。
