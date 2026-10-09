# PresentationAssets 表现资产接入

## 目标

让程序可以稳定接入美术正式资源，同时保持占位素材和正式素材可以直接替换。

当前资产目录：

```text
assets/
├── characters/
├── environment/
├── fonts/
└── ui/
```

共享表现配置为 `data/shared/presentation_asset_config.tres`，保存跨场景共用的 UI Theme 和玩家主角外观引用。需要显式读取共享资源时使用 `PresentationAssetConfig` 对应字段；项目级默认主题仍由 `project.godot` 的 `[gui] theme/custom` 应用。

## 当前规则

各玩法系统的数据 Resource 继续直接保存自己使用的美术资源引用。

例如：

- `IdentityOption.icon` 保存身份图标；玩家主角跨场景复用的立绘、头像、直播背景、房间背景和粉丝牌由 `PresentationAssetConfig` 保存。
- `LevelProfile` 保存每关主播的立绘、头像、直播背景和粉丝牌；主角固定外观不写入样例对手关卡。
- 败者卡资料保存卡面；
- 结局配置保存教派主图；
- UI Theme 保存通用字体和控件样式。

常见资源归属：

| 资源目录 | 内容示例 | Resource 归属 |
| --- | --- | --- |
| `assets/characters/` | 主播立绘、头像、身份/神明图标、败者卡角色图 | 身份、关卡/主播或败者卡 Resource |
| `assets/environment/` | 直播背景、房间背景、转场画面 | 关卡或对应演出配置 Resource |
| `assets/fonts/` | 项目专用字体文件 | 共享 Theme 或排版配置 Resource |
| `assets/ui/` | 跨场景状态图标、准心和通用 UI 贴图 | 共享表现配置；单系统图标归该系统 Resource |

身份图标继续存放在 `IdentityOption.icon`；每关主播立绘、头像、背景和粉丝牌跟随 `LevelProfile`；玩家主角固定外观因会跨场景复用而放在 `PresentationAssetConfig`；败者卡卡面跟随败者卡资料；教派主图跟随结局配置。系统专属资源仍由对应系统 Resource 持有。

`player_streamer_avatar` 当前复用主角立绘纹理；交付独立头像后只替换该字段。PA-02 只建立 Resource 引用，Sandbox HUD 与背景的实际视觉接线由 PA-03 处理。

跨多个场景共同使用、并且需要集中替换的表现素材放进共享表现配置。

## 替换约定

- 占位资源和正式资源使用同一个字段；美术交付后替换该字段对应的 Godot Resource。
- 共享配置只添加已被多个场景共同使用的素材；新增前先核实实际消费者。
- 当前没有共享准心、状态图标、通用转场贴图或 Shader 资源，因此不预建这些字段。
- 不创建 AssetManager 或额外查找服务；需要时通过系统 Resource 字段或显式加载共享配置取得资源。

## 任务

| 任务卡 | 功能 | 单元测试 |
| --- | --- | --- |
| PA-01 | 建立表现资产引用规范与共享配置 | 无 |
| PA-02 | 正式美术资产入库与数据接线 | 无 |
| PA-03 | 主战斗界面正式美术接入 | 无 |
| PA-04 | 普通弹幕玻璃底板、倾向/强度外观与富文本文字表现 | 运行画面验证 |
| PA-05 | 特殊弹幕材质：铁质、预裂玻璃、果冻、镂空文字 | 运行画面验证 |
| PA-06 | 弹幕命中表现：曲线碎裂、漫画强调符号、硬碰、分裂、果冻回弹 | 运行画面验证 |

PA-02 负责把正式美术资产导入工程并接到对应 Resource；PA-03 负责将已经接线的正式资源替换到 Sandbox 主战斗界面。
