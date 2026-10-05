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
