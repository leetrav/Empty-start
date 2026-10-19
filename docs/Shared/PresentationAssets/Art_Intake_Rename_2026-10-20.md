# 美术交付归档与漫画同步｜2026-10-20

本批共 13 张新图，已核查原始图像尺寸与 SHA-256，**仅分类/改名/移动**，未对像素进行重采样。来源为 2026-10-19 晚至 2026-10-20 00:50 放入 `assets/` 根目录的新文件。原始中文名按下表追踪。

| 原始文件名 | 整理后的工程路径 | 尺寸 | 用途 |
| --- | --- | --- | --- |
| 身份选择界面背景.png | `assets/ui/identity/identity_selection_background.png` | 1920×1080 | 身份选择整屏底图 |
| PK界面效果图.jpg | `docs/Shared/PresentationAssets/previews/live_pk_layout_reference_20261019.jpg` | 1920×1080 | **布局参考图**，非游戏内可直接叠加的背景 |
| 直播间背景.png | `assets/ui/live/livestream_layout_background.png` | 1920×1080 | 双直播间 + 中央棋盘 UI 底板 |
| 矛盾条背景.png | `assets/ui/combat/paradox_bar_background.png` | 532×144 | 矛盾计量条背景 |
| 暂停界面背景.png | `assets/ui/pause/pause_background.png` | 1920×1080 | 暂停界面 |
| 玩家点赞icon.png | `assets/ui/live/stats/player_likes.png` | 150×150 | 玩家直播间点赞 |
| 敌人点赞icon.png | `assets/ui/live/stats/opponent_likes.png` | 150×150 | 对手直播间点赞 |
| 玩家评论icon.png | `assets/ui/live/stats/player_comments.png` | 189×188 | 玩家直播间评论 |
| 敌人评论icon.png | `assets/ui/live/stats/opponent_comments.png` | 189×188 | 对手直播间评论 |
| 玩家粉丝icon.png | `assets/ui/live/stats/player_followers.png` | 189×188 | 玩家直播间粉丝 |
| 敌人粉丝icon.png | `assets/ui/live/stats/opponent_followers.png` | 189×188 | 对手直播间粉丝 |
| 玩家观看人数icon.png | `assets/ui/live/stats/player_viewers.png` | 189×188 | 玩家直播间观看人数 |
| 敌人观看人数icon.png | `assets/ui/live/stats/opponent_viewers.png` | 189×188 | 对手直播间观看人数 |

## 接入边界

- 本次仅作规范化归档，不主动覆盖游戏中现有的绘制层或接线；场景替换与视觉调参留给实际游戏验收。
- 8 张数字图标中浅色为玩家、绿色为敌方，不能混用阵营色。
- 参考布局 JPG 仍保留供美术和程序对齐，但不进入正式 assets/。
- 源 PNG/JPG 与目标文件的 SHA-256 一致；未更改图片尺寸、透明度或色值。
- Godot 会在新位置重新生成导入缓存和 `.import`，如需接入，应优先以新路径引用；不要再使用原根目录中文名。

## 漫画一并归档

- `data/comics/opening.tres`：P1～P4，共 13 个镜头节点。
- `data/comics/ending.tres`：正式通关结局 P5～P6，共 6 个镜头节点。
- 按当前策划口径，启动漫画仅播放前四幕，结局由 `ending` 路由触发。
- 运行时复用 `ui/comic/comic_caption.gd`、`comic_caption_view.gd`、`comic_player.gd` 的 Label/富文本/字体字号与 BBCode 效果。
- 可视化修改工具：`tools/comic_copy_editor/comic_copy_editor.tscn`，Godot 中 F6 运行、Ctrl+S 写回；工具不需要包含在发布 EXE 中。
- 资源文案来自用户当前本机 `.tres` 版本，已做原文完整复制及哈希核对。

## 待做事项

- 身份、直播、矛盾条、暂停背景及统计图标 **尚未接入正式场景**，本 PR 只负责把美术交付准备好。
- 漫画原分镜运动/场景切换及长文本视觉布局仍以玩家实际运行验收为准。
