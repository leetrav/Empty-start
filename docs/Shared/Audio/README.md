# Audio 共用音频接入

## 当前底座

项目已经有：

- `AudioManager` Autoload；
- `Music`、`SFX`、`UI` 三条 Audio Bus；
- Master / Music / SFX / UI 独立音量设置；
- `AudioManager.play_music(stream)`；
- `AudioManager.stop_music()`；
- `AudioManager.play_sfx(stream)`；
- `AudioManager.play_ui(stream)`。

## AU-01 事件播放

- `AudioEvent` Resource 保存稳定事件 ID、`Music / SFX / UI` 类型和 `AudioStream`。
- `AudioEventConfig` 集中保存事件列表，配置文件为 `data/shared/audio_event_config.tres`。
- 玩法系统通过 `AudioManager.play_event(&"attack_fire")` 播放；管理器按事件类型复用现有 Music 播放器或 SFX / UI 播放池。
- 当前稳定事件 ID 包含 `attack_charge`、`attack_ready`、`attack_fire`、`hit_normal`、`hit_trap`、`tier_up`、`contradiction_start`、`contradiction_break`、`oracle_confirm`、`divine_descent_start` 和 `divine_descent_lock`。
- 当前音效素材是占位引用；`oracle_confirm` 使用 `assets/audio/sfx/interface/confirmation_001.ogg`，随目录保留 Kenney CC0 授权文本。正式素材到位后只替换各事件的 `stream` 引用，事件 ID 保持稳定。
- 仓库尚无正式音乐文件，因此配置暂时没有 Music 类型事件；新增音乐事件时，将其类型设为 Music 并引用正式 `AudioStream`。音乐状态切换和淡变仍由 AU-02 处理。

资产目录：

```text
assets/audio/
├── music/
└── sfx/
```

## 本阶段需要补的能力

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

音乐还需要支持阶段切换时的淡入淡出、交叉切换、临时压低和静音过渡。

## 任务

| 任务卡 | 功能 | 单元测试 |
| --- | --- | --- |
| AU-01 | 游戏音频事件配置与播放入口 | 无 |
| AU-02 | 音乐状态切换 | 无 |

玩法系统完成自己的核心逻辑以后，在对应表现联调卡里调用这里已经存在的公开接口。
