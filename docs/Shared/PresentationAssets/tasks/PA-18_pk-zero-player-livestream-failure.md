# PA-18 PK 归零：仓鼠球跌落、我方直播断流、失败界面

> 状态：需求已确认，待实施
> 类型：程序美术 / PresentationAssets
> 依赖：OP-05 归零失败通知、现有 `Sandbox._on_attempt_failed()`、PA-13 仓鼠球、PA-11 CRT 材质

## 开始前阅读
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`、`assets/README.md` 与最新相关完成日志
- `scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`

- `docs/7. OpponentPKBar/README.md`、`docs/Shared/PresentationAssets/tasks/PA-13_pk-hamster-ball-indicator-animation.md`
- `docs/Shared/PresentationAssets/tasks/PA-11_stage-transition-visuals.md`

## 触发与表演
- 当真实玩家 PK 归零，现有 OP-05 / Sandbox 正式发出本场失败事实后，在失败界面出现前播放**一次**战败动画。
- 动画顺序：
  1. 玩家 PK 进度归零，PA-13 仓鼠球停在 PK 条左端，出现短促的失衡 / 惊跳。
  2. 仓鼠球从 PK 条**翻滚跌出轨道**，沿向下的弧线旋转坠落，快速缩小或移出画面。
  3. **左侧我方主播直播画面**播放信号抖动 → CRT 水平线收缩 → 黑屏 / 断流，终止主播显示。
  4. 右侧对手直播画面仍保持可见和正常直播形象，形成双方状态反差。
  5. 玩家当前已存在的**失败 UI / 重开按钮**在视觉动画结束后显示，并正常响应重开。

## 美术实现
- PA-13 的同一只仓鼠球为跌落对象，实际跟随 PK 的滚动状态转换成一次抛物线与角速度动画；可用 Tween、Node2D 控制位置、缩放、旋转。
- 我方断流复用 PA-11 的 CRT 扫描 / 收线参数与 Shader，方向与接入开机相反；断流范围为左侧 448×432 主播视频区域，其他区域继续受原战斗 HUD 控制。
- 可调掉落方向、初速度感、旋转次数、掉落耗时、CRT 关机耗时及失败 UI 出场延迟。
- 与当前 `show_failure()` 和既有失败 / 重开逻辑对接，只延后**失败 UI 的可见展示**到演出结束；任何一场 PK 归零只播放一次，取消 / 重开可复位球体和直播画面。

## 验收
- PK 真正达到 0 并进入失败结果时，能够完整看到仓鼠球跌落、左侧断流、右侧保持直播、最后出现原失败界面。
- 普通降档（仍 >0）依旧使用 PA-11/PA-13 箭头与惊跳，不会播放 PK0 整段战败动画。
- 重开后仓鼠球回归当前 PK 轨道、笑脸正常；左右视频重新按现有阶段状态展示。
- 1920×1080 / Windows / Android 真机场景和 Output / Debugger 验收通过。

## 完成记录
新增 `docs/Shared/PresentationAssets/表现资产_PA-18_YYYY-MM-DD_log.md`，记录场景过渡、角色 / PK 可见状态、重开复位和实测。
