# PA-14 主播立绘基础动效与主角射击反馈

> 状态：需求已确认，待实施
> 类型：程序美术 / PresentationAssets
> 依赖：PA-03 已接入的双主播立绘、CombatAttack 正式发射通知

## 开始前阅读
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`、`assets/README.md`、最新相关完成日志
- `scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`

## 已有素材与目标
- 主角：`res://assets/characters/player/hamster_idle.png`；对手：`res://assets/characters/opponents/{alien,kiwi,fox}/` 下已有的待机 / 阶段 PNG。
- **所有在场的主播立绘平时都具有轻微动画**。第一版统一采用整张静态 PNG 的轻量呼吸、漂浮或摇摆，按每个角色提供不同频率与强度的可调预设；待实际录屏试玩后，再确定是否需要专属的局部动作。第一版不依赖新增切图交付。
- 主角正式发射言弹时，主播立绘配合做一个短促射击动作；玩家实际言弹仍由 PA-07 从准星中心飞出。

## 本卡程序美术
### 1. 通用待机
- 对当前已显示的玩家和对手立绘，使用 `Tween` / `AnimationPlayer` 组合**轻微上下位移、1～3% 左右的呼吸伸缩、微小角度左右摇摆**，形成可循环的生命感；不同角色通过参数改变频率 / 相位，使两侧并非完全同步。
- 保留原始立绘构图，运动中心设置在角色身躯附近；对手在 T0 离线不显示，在切换立绘时保持同一动画容器。
- 幅度、周期、相位、缩放、旋转可调；与右侧接入直播 CRT、左侧受击及其他事件动画叠加时，允许在独立容器上做叠加或短暂降低待机幅度，事件完成后平顺恢复。

### 2. 主角仓鼠发射言弹时的反应
- 读取 CombatAttack 的**有效满蓄发射**通知（当前 `shot_snapshot_created`），让左侧仓鼠做一次**小幅度向前冲 / 身体压缩 → 轻微后坐抖动 → 回弹原位**的漫画式反应。
- 发射动作短促，保持仓鼠外形和可读性；连续射击时可取消前一段事件 Tween 并从正确姿态重新播放。
- 可调前冲距离、方向、压缩幅度、震颤次数、恢复时间；发射后仍持续轻微待机。

## 程序接线
- 优先复用已有左右 `TextureRect` 显示入口，在立绘本体与父层拆分待机 / 事件视觉变换；统一从已有攻击信号触发一次射击演出。
- 使用 PNG 整体动效完成首版，无需新增逐帧美术。

## 验收
- 左右主播实际显示时各有轻微呼吸、漂浮或摇摆，画面不会像静态截图；T0 无对手。
- 一发真实射击只触发一次仓鼠短促冲刺 / 回弹；未蓄满松开不会播放发射动作。
- 动画与 PA-09、PA-11 等事件同屏时可正常叠加 / 恢复；1920×1080 及 Windows / Android 运行验证通过。

## 完成记录
新增 `docs/Shared/PresentationAssets/表现资产_PA-14_YYYY-MM-DD_log.md`，记录表现入口、参数和真实画面验证。
