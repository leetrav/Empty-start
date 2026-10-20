# PA-23-FIX · 主播立绘尺寸与可见底边恢复（附列巴房间背景核验）

状态：**P0 · 人工视觉验收未通过，待其他 Agent 修复**。原任务：PA-23，合并 PR [#318](https://github.com/w7775p/Empty-start/pull/318)。本卡覆盖 PA-23 视觉回归问题，验收权由用户保留。

## 开始前先阅读以下文档
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/Original/任务卡模板.md`。
- `docs/Shared/PresentationAssets/tasks/PA-23_portrait-visible-feet-ground-anchor.md`、PA-14/PA-15/PA-17 原任务及 PA-23 完成日志、PR #318 修改和已有 before/after 图片。
- `systems/presentation/opponent_tier_portrait.gd`、`systems/presentation/streamer_portrait_motion.gd`、`ui/plan_b/plan_b_streamer_panel.gd`、`scenes/sandbox/sandbox_battle_hud.gd`，以及关卡所引用的角色与背景 Resource。

## 已经实现的功能与失败现象
- PA-23 已按 PNG alpha 可见边界计算共同 `_maximum_visible_size`，`fit_current_texture()` 以 `minf(size.x / _maximum_visible_size.x, size.y / _maximum_visible_size.y)` 再次决定显示尺寸，同时将 `visible_anchor_ratio` 设为 `(0.5, 1.0)`。`_portrait` 已有缩放、容器裁切与既有 PA-14/PA-15/PA-17 演出。
- **用户实机截图已明确否决 #318**：部分对手与原先立绘视觉尺度不同；新底边过分贴近 432px 直播画面容器下沿，身体/下肢被裁没。问题不只是脚底浮空。
- **列巴（fox/Khleb）房间背景需核验**：资源 `res://assets/environment/live/fox/background.png` 已存在，但用户实机反馈列巴直播间没有正确显示房间背景。查关卡 `LevelProfile`、presentation 资源与 `configure_assets(..., background, ...)` 的实际链路确定原因。

## 本次任务
1. **先恢复原有视觉尺度**：对比 PR #318 之前真实运行截图/场景及源 PNG 的原始宽高、透明边界。沿用每个角色原本的显示尺寸与宽高比，不因某姿态透明像素多寡而给同角色所有贴图重新放大或缩小。优先复用 PA-14 原先纹理布局与尺寸参数，保留原本设计的角色画面占比。
2. **修正立绘可见基线**：根据各主播的房间画面与姿态支撑点确定稳定的可见站立线，预留与底边/前景遮挡相协调的安全距离。切 T1/T3/T5、待机、击败时维持相近的视觉重心，确保玩家应该看到的脸、身体、手脚保持可见；主角桌面前景遮挡维持原有构图。
3. **保留演出表现**：核对 `OpponentTierPortrait` 的 `attach_portrait` / `fit_current_texture` / `show_tier` / `reset_for_tier`、`_display_scale`、Tween 的 scale/pivot，并确认 T1→T2 震颤/出汗及 T2→T3 等翻面不会意外修改尺寸或导致跳动。
4. **修复列巴房间背景链路**：定位列巴关卡的实际背景引用与正式 Plan B 面板注入流程，确保 fox 的 `background.png` 在游戏实际匹配到列巴时显示，层级位于立绘后方。核对其他四个主播切换后仍加载各自正确背景。
5. **对照截图逐一调整**：在实际 Godot 4.7.2 的 1920×1080 游戏场景中重现并比较“修复前/修复后”，包括仓鼠、费米、Kiwi、青蛙、列巴的常见姿态和切档。另在 1280×720 检查缩放后的完整性。

## 修复验收标准（人工视觉验收必需）
- 角色与 **PA-23 修改前的原设计尺寸、视觉比例基本一致**：不能因为统一可见边界而突然变大、变小或变形；不同姿态之间没有突兀的尺寸跳变。
- 底边有合适留白，重要身体部分没有被直播区裁切；脚底/支撑点与房间场景符合观感，同时没有明显浮空。
- 主角桌面、背景、前景的遮挡关系正确，T1/T2/T3/T5、受击、败北等原演出还能工作。
- 列巴房间可在正式游戏中看见 **fox/background.png**，而非空白或错用其他人的背景。
- PR 中附 1920×1080 的**完整三列 UI**截屏、角色局部 before/after 对比，以及 1280×720 最小一组截图；注明实际运行 commit 和角色/Tier。无真实 Godot 截图则交付 Draft，**由用户决定是否验收通过**。

## 本任务所属分支和文件归属
- 任务编号：PA-23-FIX；唯一核心 Owner：本卡承接的程序美术 Agent。优先修改 `systems/presentation/opponent_tier_portrait.gd`、与之直接有关的主播面板/场景及资源映射。
- 直接依赖：已合并 PA-23 PR #318。PA-22 青蛙分件动画仍由独立 Agent 执行，开工前与其核对修改文件；同一演出文件以单一 Owner 顺序合流。
- 开发基线与 PR 目标：**最新 `main` HEAD**；新分支和工作树独立创建在 D 盘。其他 Agent 的 D 盘工作树保持原状。

## Godot 开发环境
- Godot 4.7.2 / GDScript；项目 Empty-start；Windows PC；设计视口 1920×1080，兼顾 1280×720；使用 Godot-MCP-Native / godot_mcp 查实际场景与 API。

## 最小执行流程
1. 核对当前有效 `main`、PR #318 差异、PA-22 文件 Owner 和 Godot 实机问题。
2. 选择最小补丁恢复视觉比例、可见底边及列巴房间背景，按独立子任务 commit。
3. 运行 Godot 并保存指定的前后截图；仅做必要的脚本/场景加载检查。
4. 写 `docs/Shared/PresentationAssets/` 下 PA-23-FIX 完成日志，附修改路径、尺度/偏移参数、截图、未解决项；创建目标为 `main` 的 PR，供用户人工确认。

## 执行要求（沿用仓库完整 14 项）
核对代码和真实节点；控制范围；复用现有组件；按真实场景边界与信号处理；区分资源、数据和表现；优先检查现有实现；不确定的 Godot API 查 godot_mcp；使用 Godot-MCP-Native 观察运行场景；最小验证；尊重 NodePath、Owner、场景 UID；检查动画中断/重进/Tier 切换；最终对照人眼截图。所有源码、工作树、导入缓存、截图、日志及临时产物均在 **D 盘**。

## 最终汇报
给出每个子任务的 commit SHA、PR 链接、运行截图、旧版/新版对比、列巴背景定位与修复方法、仍需用户验收的项目。
