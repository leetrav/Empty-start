# LD-15 评论按粉丝身份显示双方专属粉丝牌

**状态：待开发 · 普通直播评论流**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 及最新完成日志
- 现有 `LiveDataHud`、`Sandbox`、源表导出器与主播粉丝牌资源
- 前置或接口参考：LD-14；现有 PA-02/PA-03 与 `LevelProfile`、`PresentationAssetConfig`

## 当前实现与复用入口
玩家已有 `data/shared/presentation_asset_config.tres` 的 `player_fan_badge`，对手关卡已有 `LevelProfile.fan_badge_texture`；Sandbox 的 `configure_streamer_assets()` 已将对应纹理传给主播 HUD。

## 本卡唯一功能
评论按粉丝身份显示双方专属粉丝牌。

## 触发条件
LD-14 准备显示一条粉丝或路人评论时。

## 应发生的行为
通过当前条目 `audience_type` 决定用户名左侧的徽章展示：`fan` 使用本侧主播的粉丝牌纹理；`passerby` 直接显示用户名与正文。玩家侧从既有 `PresentationAssetConfig.player_fan_badge` 读取，敌方从当前关卡的 `LevelProfile.fan_badge_texture` 读取，沿用现有显式 HUD 资源接线并支持后续替换美术。两侧纹理、用户名与评论正文构成同一条滚动行。

## 验收
玩家粉丝带玩家粉丝牌，对手粉丝带该关对手粉丝牌；两边路人不显示粉丝牌；更换对手关卡后其粉丝牌跟随切换，滚动效果不变；资源暂缺时界面保持正常。

## 交付
提交本卡对应的程序、Godot 实际运行验证与日期日志，更新本系统 README。
