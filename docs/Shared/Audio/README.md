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
