# PA-03 主战斗界面正式美术接入

## 开始前先阅读
- AGENTS.md
- docs/System_Collaboration.md
- docs/Shared/PresentationAssets/README.md
- docs/Original/美术需求汇总.md
- scenes/sandbox/sandbox.tscn
- scenes/sandbox/sandbox_battle_hud.gd
- ui/live_data/live_data_hud.tscn
- PA-02 最新 log
- 当前相关系统最新 log

## 本次任务

把已经由 PA-02 入库并接好 Resource 的正式美术资产接入当前 Sandbox 主战斗界面。

### 1. 当前主界面优先替换

按以下顺序接入：

1. 玩家 / 对手主播立绘
2. 玩家 / 对手直播间背景
3. 观看、点赞、评论、粉丝四个正式 ICON
4. PK 条正式视觉
5. Tier 正式视觉
6. 准心正式视觉
7. 蓄力条正式视觉
8. 已交付字体与通用 UI 样式

### 2. 布局规格

继续使用当前 1920×1080 设计规格：

```text
左 448
  信息区 448×128
  立绘区 448×432
  直播数据 448×520

中 1024
  PK / Tier 1024×72
  弹幕区 1024×760
  底部交互 1024×248

右 448
  信息区 448×128
  立绘区 448×432
  直播数据 448×520
```

本卡以正式美术替换现有占位表现，保持现有玩法逻辑和区域规格。

### 3. 直播数据

- 使用正式观看 / 点赞 / 评论 / 粉丝 ICON。
- 玩家继续靠左显示“图标 + 数字”。
- 对手继续靠右显示“数字 + 图标”。
- 继续使用现有 RichTextLabel 作为数字表现入口。

### 4. 资源读取

- 主播专属素材从对应主播 / LevelProfile Resource 读取。
- 跨场景共用素材从当前共享表现配置或现有 Theme 读取。
- Scene 只负责显示，不复制一份业务数据。

## 验收

- Sandbox 中不再使用主播立绘占位块作为正式显示。
- 已交付的直播背景、直播 ICON、PK 条、Tier、准心、蓄力条能在实际运行中显示。
- 玩家和对手资源能按当前关卡 / 主播配置正确加载。
- 1920×1080 设计布局保持现有区域边界。
- 直播数据继续随现有 LiveSessionData 更新。
- PK、Tier、攻击与 DEBUG 功能继续正常工作。
- Godot Output / Debugger 没有新增相关错误。

本卡以实际运行与画面验收为主，不新增单元测试。

## 完成日志

完成后新增：

`docs/Shared/PresentationAssets/表现资产_PA-03_2026-10-07_log.md`

记录已替换的占位内容、实际使用的资源路径、仍待美术交付的项目和运行验证结果。
