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

共享表现配置为 `data/shared/presentation_asset_config.tres`，目前只引用跨场景共用的 `ui/theme/base_theme.tres`。需要显式读取共享主题的资源可读取 `PresentationAssetConfig.ui_theme`；项目级默认主题仍由 `project.godot` 的 `[gui] theme/custom` 应用。

## 当前规则

各玩法系统的数据 Resource 继续直接保存自己使用的美术资源引用。

例如：

- 身份数据保存身份图标和主角头像；
- 关卡数据保存主播立绘、头像、直播背景和粉丝牌；
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

身份图标继续存放在 `IdentityOption.icon`；主播立绘、头像、背景和粉丝牌跟随关卡/主播数据；败者卡卡面跟随败者卡资料；教派主图跟随结局配置。不要把系统专属资源复制进共享配置。

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

PA-02 负责把正式美术资产导入工程并接到对应 Resource；PA-03 负责将已经接线的正式资源替换到 Sandbox 主战斗界面。
