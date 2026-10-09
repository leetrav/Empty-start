# PA-19 直播结束：CRT 关机、向上翻页、回主角房间弹出结算

> 状态：需求已确认，待实施
> 类型：程序美术 / PresentationAssets
> 依赖：CB-10 未击破休息入口、FO 正式确认后的休息入口、现有 RS RestResultView 与 RestRoomEnvironment；PA-11 CRT 表现

## 开始前阅读
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`、`assets/README.md` 与最新相关完成日志
- `scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`

- `docs/12. ContradictionBreak/README.md`、`docs/13. FinalOracle/README.md`、`docs/18. Rest/README.md`
- `ui/rest/rest_room_environment.tscn`、`ui/rest/rest_result_view.tscn`
- `docs/Shared/PresentationAssets/tasks/PA-11_stage-transition-visuals.md`、`PA-17_opponent-breakthrough-defeat-performances.md`

## 两条合法入口
- **Paradox 未击破**：由现有 CB-10 结果进入战后休息；先播对应的 PA-12 未击破提示和 PA-17 对手离线，再执行本卡画面退出 / 回房间。
- **Paradox 真击破**：先播 PA-17 专属击败演出，然后继续原本的**终结神谕（FinalOracle）候选选择 / 确认和正式奖励提交**，在 FO 通过现有入口进入战后 Rest 时才执行本卡画面退出 / 回房间。
- 两条路径都进入**同一个已有的战后休息结算界面**，用真实 `RestSession` 结果、成果和既有继续逻辑显示。本卡向现有展示方提供视觉播放完成信号。

## 本卡程序美术
### 1. 直播画面 CRT 关机
- 在任一路径确认准备进入 Rest 画面时，左右主播直播画面依次或基本同步播放 **轻微扫描失真 → 画面骤暗 → 收缩为横向亮线 → 亮线灭掉黑屏**，让玩家清楚感觉一场直播正式结束。
- 优先复用 PA-11 的 CRT 开机 Shader / Tween，反向动画；右侧画面若此前已在未击破分支离线，保持其离线黑屏，只关闭仍开启的视频区域。
- 全程短促；扫描强度、闪亮时间、关机时长可集中配置。

### 2. 整屏向上翻页，揭开仓鼠房间
- CRT 结束后，采用**战斗画面作为一整页向上翻开的漫画分页**：战斗 UI 作为上层在向上翻 / 上滑中缩短或带轻微透视，底部露出已有 **主角房间背景** `res://assets/environment/rooms/player_room_01.png`。
- 可以使用 Shader / 遮罩 / Tween / 截取当帧画面，重点表现“从直播这一页翻回现实的房间”；沿用 1920×1080 的 UI 比例。翻页遮罩应覆盖战斗 HUD 以自然收场，房间露出后战斗 UI 不再覆盖它。
- 主角房间由现有 `RestRoomEnvironment` 负责，继续显示原有倾向色调和环境状态。

### 3. 房间到结算
- 翻页结束时，玩家先清楚看到房间画面，然后**从房间上方弹出 / 放大并回弹**现有战后结算 UI，使用原 `RestResultView.show_result()`、`finish_result_performance()` 等已有展示契约。
- 提供 `CRT 完成 → 翻页完成 → 允许打开结算 / 结算演出完成` 的明确顺序，避免重复启动、提前出现结果 UI 和与 Rest 的显示锁冲突。
- 不同结果由真实 `RestSession` 区分，视觉转场共用一套，结算文本、奖励、历史圣典 / 败者卡仍来自既有入口。

## 验收
- 真击破：正确经历 PA-17 击败演出、现有 FinalOracle 确认提交，再播放 CRT 关机 → 向上翻页 → 主角房间 → 结算 UI。
- 未击破：保留 T5 立绘离线后，同样 CRT 关机 → 向上翻页 → 主角房间 → 结算 UI；无成功击破图和奖励。
- 战败 PK0 由 PA-18 自己的失败界面负责，不混入本卡的战后房间结算。
- 两种 Rest 入口复用相同页面，首次播放、返回 / 重进 / 本关继续均不会重复演出或重复提交结果。
- 1920×1080 的 Windows / Android 场景动画流畅，结算按钮可正常使用，Output / Debugger 无新增错误。

## 完成记录
新增 `docs/Shared/PresentationAssets/表现资产_PA-19_YYYY-MM-DD_log.md`，记录 CRT / 翻页动画、Rest 界面控制顺序、两种结算入口和实际画面验证。
