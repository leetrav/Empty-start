# PA-10 全局 UI 视觉统一与 Style 集中调整

> 状态：需求已定，待各 UI 集成后实施
> 类型：后期整合 / PresentationAssets
> 依赖：PA-03 主战斗界面美术接入；PA-04～PA-09 及届时已完成的其他正式 UI 表现

## 开始前阅读
- `AGENTS.md`、`project.godot`、仓库已知问题记录
- `docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`
- `docs/Shared/PresentationAssets/tasks/PA-03_battle-ui-art-integration.md`
- `docs/Shared/PresentationAssets/tasks/PA-04_barrage-glossy-translucent-ui.md` 至 `PA-09` 的任务卡及最新完成日志
- `ui/theme/base_theme.tres`、`ui/theme/theme_preview.tscn`
- `data/shared/presentation_asset_config.tres`
- `scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`

## 需求背景

战斗 UI 由不同成员、不同任务分别制作。即使每一块单独完成，合并到 1920×1080 主界面后仍可能出现**色调冲突、材质和描边不一致、字号层级混乱、视觉重心失衡、动效节奏不协调**等问题。

本卡要求在正式 UI 基本完成并集成后，进行一次**全画面视觉统一与调整**。由美术 / 策划确认最终视觉方向、色号和需要修改的位置，程序美术负责让可集中调整的样式统一生效，并对剩余局部表现做针对性修改。

## 已有基础
- 项目已有全局 `ui/theme/base_theme.tres`，由 `project.godot` 的 `[gui] theme/custom` 使用。
- 项目已有共享表现配置 `data/shared/presentation_asset_config.tres`。
- 弹幕、漫画字、准星、PK 条、直播数据和其他特殊材质分别使用 Theme、StyleBox、程序绘制或贴图等表现途径。
- 已确认新版准星采用**小空心圆 + 外围环形蓄力进度**；视觉统一以届时已确认的最新方案和实际集成结果为准。

## 本次任务

### 1. 完整战斗画面检查
- 在正式集成的主战斗界面中，同时查看我方 / 对手主播区、PK / Tier、中央弹幕、复读与特殊弹幕、准星、战斗提示、直播数据及已完成的阶段表现。
- 对照实际画面，整理色相 / 明度 / 饱和度、字体与字号层级、描边粗细、圆角形状、半透明与高光、阴影、元素留白、视觉权重和动画节奏的协调问题。
- 对不同状态检查：低 / 高密度弹幕、普通命中、惩罚漫画提示、Tier 变化等已实现画面。
- 与美术 / 策划共同确认需统一调整的项目、色号及个别保留差异的特殊效果。

### 2. Style 集中调整
- 优先利用项目已有的 `Theme`、`StyleBox`、Theme Type Variation 和共享资源，集中管理**确实需要跨多个 UI 同步调整**的颜色、文字 / 描边、常用透明度与基础样式。
- 现有 `_draw()`、Shader、RichTextLabel 或程序化动态效果按实际消费者接入合适的共享视觉参数；可独立变化的特殊材质仍保留自身可调参数。
- 让美术 / 策划提供确定的色号与样式值后，能够在明确的位置修改并影响对应 UI。
- 对已交付 PNG / SVG 等资源按实际需要调整色调、替换资源或更新引用，与整屏风格一致。

### 3. 整屏视觉统一
- 根据完成的整屏审查，统一各区域色彩关系、文字层级、边框 / 材质质感、元素密度、装饰存在感和动画强弱。
- 保留已确认的视觉语言：普通弹幕玻璃感、特殊弹幕材质区别、简洁环形准星，以及角色受击时的手绘漫画提示。
- 优化主播区、战斗主区域和顶部状态信息之间的视觉主次，重点保障高密度弹幕时的文字与瞄准可读性。
- 针对集中调参后仍不协调的局部 UI，直接修改其现有样式、绘制参数或资源，形成统一的正式视觉效果。

### 4. 最终检查和交付
- 以 1920×1080、16:9 为设计基准，在 Windows 与 Android 对应画面上查看主要 UI 组合。
- 检查低 / 高密度弹幕、战斗提示和典型阶段状态下的可读性、视觉层次、色彩一致性及动效协调。
- 整理一份简单的样式调整说明，注明常用颜色 / 字体 / 描边等参数位置、仍需单独修改的特殊材质或贴图入口。
- 记录全局调整前后代表性整屏画面，供策划和美术最终验收。

## 验收
- 各正式 UI 在同一张主战斗画面中具有协调的色彩、字体、描边、材质层级和视觉主次。
- 需要统一修改的公共颜色和基础样式可以从既有 Theme / 共享配置等明确入口调整，实际引用的 UI 同步更新。
- 玻璃弹幕、特殊材质、环形准星与手绘漫画提示保留各自可辨认的风格，同时融入统一画面。
- 密集弹幕、普通命中、惩罚提示、Tier 变化等典型状态的画面检查完成。
- Windows / Android 对应画面正常显示，Godot Output / Debugger 无新增相关错误。
- 提交样式调整说明、对比画面与最终验收记录。

## 环境与完成记录
- Godot 4.7.2 / GDScript / Windows / Android
- Godot-MCP-Native；godot_mcp
- 实施时复用已完成 UI 与现有场景和样式资源。
- 完成后新增 `docs/Shared/PresentationAssets/表现资产_PA-10_2026-10-09_log.md`，记录调整范围、公共样式入口、局部资产修改、对比画面与实际运行验收。
