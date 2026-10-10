# PA-01 表现资产引用规范与共享配置

## 开始前先阅读以下文档
- AGENTS.md
- project.godot
- docs/System_Collaboration.md
- docs/Shared/PresentationAssets/README.md
- 【当前任务直接依赖的最新 log】

## 已经实现的功能
- 仓库已经有 `assets/characters/`、`assets/environment/`、`assets/fonts/`、`assets/ui/`。
- 全局 UI Theme 已经存在。
- 1～20 各系统任务卡已经在需要美术资源的地方使用 Resource 引用思路。

## 本次任务
只实现“程序用统一方式引用和替换表现资产”这一件事。

完成后按下面方式接入资产：

1. 属于某个游戏数据对象的素材，直接保存在该对象的 Resource 中。
   - 身份图标跟身份数据走；
   - 主播立绘、头像、背景、粉丝牌跟关卡 / 主播数据走；
   - 败者卡卡面跟败者卡资料走；
   - 教派主图跟结局配置走。
2. 跨多个场景共同使用的素材放进一个共享表现配置 Resource。
3. 共享表现配置只保存当前已经需要跨场景复用的素材，例如通用弹幕外观、通用准心、通用状态图标、通用转场素材。
4. 占位素材和正式素材使用同一个字段位置；正式素材到位后直接替换 Resource 引用。
5. 资产文件继续按 `characters / environment / fonts / ui` 目录分类。

本任务同时补一份简短的资产字段说明，让 GPT-4o 和美术接手时能知道“这张图应该放在哪个数据里”。

### 验收条件
- 至少有一个可加载的共享表现配置 Resource。
- 配置只包含当前跨场景共同使用的表现资产。
- 身份、主播、败者卡、结局等专属素材继续保存在各自数据 Resource。
- 一个占位素材替换成正式素材时，只需要修改对应 Resource 引用。
- 文档写清楚常见素材的存放目录和数据归属。
- 本任务不新增单元测试。

## 环境与验收记录
- 使用仓库现有 Godot 4.7.2、`AGENTS.md`、现有 Theme 与 Resource 结构工作。
- 资源加载与占位替换通过 Godot 实际加载检查；本卡不新增单元测试。
- 参考已完成日志 `docs/Shared/PresentationAssets/表现资产_PA-01_2026-10-05_log.md` 获取已交付字段、资源路径及验证结果。
