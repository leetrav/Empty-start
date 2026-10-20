# PK外框 PK-FRAME-01 2026-10-21

## 修改
只修改ui/plan_b/plan_b_battle_ui.gd。直播大背景顶部本来包含圆角长框，旧PkTierBar不透明方形底板及暂停按钮遮住原画。现将二者常态底色设透明；暂停悬停/按下保留轻反馈，不缩小触控目标。原背景截取(432,0,1044,90)通过AtlasTexture完整呈现于(432,0,1044,72)，避免棋盘从y72开始裁掉原外框下沿；没有修改任何PNG。PK状态内边距调整，进度条上下StyleBox留白归零，实际高度恢复16px，位置(463,47)，保持内部皮肤可见。浅色原画上原文字加描边。

## 验证
Godot4.7.2 Steam，D3D12 Forward+、RTX3050 Laptop；隔离D盘APPDATA。正式Sandbox里受控暂停业务更新，仅给原进度控件和皮肤设定展示状态，不冒充自然战斗推进。
- 原生1920×1080截图：initial.png(49%,T0)、tier1.png(56%,T1)、tier2.png(64%,T2)、tier5.png(90%,T5)、full.png(100%,矛盾)，位于previews/PK-FRAME-01。已查看关键运行图，圆角框与阶段皮肤分层可见。
- 三列布局、两侧视频窗和中央棋盘(448,72,1024,828)不变。
- 点击透明暂停按钮可打开菜单；Esc恢复；原生卡片+棋盘点击恰好一次发表请求。
- 最终进程退出0，无ERROR/SCRIPT ERROR，原始日志runtime.log。Godot MCP不可用，使用D盘引擎原生GUI。

## 限制
未改PkBarSkin选图逻辑/进度计算或美术；未进行完整周目、Android回归。本次截图为受控显示，人物依旧由本地夹具显露费米供对齐。只在本地分支fix/pk-outer-frame-20261021提交，未推送。project.godot及导入侧文件保留。新长期陷阱已补入known_traps.md。
运行代码SHA：0a3de38c8953fa3007db82b4a5b3c9ad63775fad
