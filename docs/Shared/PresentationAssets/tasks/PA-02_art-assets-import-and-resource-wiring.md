# PA-02 正式美术资产入库与数据接线

## 开始前先阅读
- AGENTS.md
- docs/System_Collaboration.md
- docs/Shared/PresentationAssets/README.md
- docs/Original/美术需求汇总.md
- data/shared/presentation_asset_config.gd
- data/level_configuration/level_profile.gd
- data/identity/identity_option.gd
- 当前相关系统最新 log

## 本次任务

接收已经按项目美术命名规范放入仓库的正式美术资产，并把它们接到现有 Godot Resource 字段。

### 1. 资产目录

按现有目录归类：

```text
assets/
├── characters/
├── environment/
├── fonts/
└── ui/
```

### 2. 数据字段

先检查实际消费者，再给缺少正式美术入口的数据 Resource 补最小字段。

当前优先检查：

- 主播立绘
- 主播头像
- 直播间背景
- 粉丝牌
- 身份图标
- 主角头像 / 立绘
- 通用字体
- 后续已经真实交付的系统专属贴图

主播相关资源继续跟随关卡 / 主播数据；身份资源继续跟随 IdentityOption；跨多个场景复用的素材才进入 PresentationAssetConfig。

### 3. 实际接线

- 将正式图片、字体或其他美术文件导入 Godot。
- 将资源引用写入对应 `.tres` / Resource。
- 保持稳定资源字段，正式素材直接替换当前占位引用。
- 已有字段能够表达资产时直接复用。
- 只有真实交付素材存在消费者时才新增字段。

### 4. 本任务交付边界

本卡负责“资产文件已经进入工程，并且数据层能正确引用”。

主战斗 Scene、HUD 排版、动画和视觉替换交给 PA-03。

## 验收

- 正式资产能够被 Godot 正常导入。
- 对应 Resource 能正确加载正式资源引用。
- 主播正式资源至少具备立绘、头像、直播背景的可引用入口。
- 已交付的身份 / 主播 / UI 共用资产放在正确目录并拥有明确 Resource 归属。
- 现有占位引用可以直接替换为正式资源。
- Godot 加载相关 `.tres` / Scene 时没有新增资源错误。

本卡以 Resource / Scene 加载验证为主，不新增单元测试。

## 完成日志

完成后新增：

`docs/Shared/PresentationAssets/表现资产_PA-02_2026-10-07_log.md`

记录本次实际接入了哪些资产、补了哪些 Resource 字段、哪些素材仍待美术交付。
