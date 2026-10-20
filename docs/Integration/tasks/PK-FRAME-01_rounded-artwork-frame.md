# PK-FRAME-01 · 顶部原画圆角长框遮挡修复

用户明确最外层指直播背景顶部圆角长框，提供T0、T1、T2、T5和矛盾截图。检查原图livestream_layout_background.png及参考live_pk_layout_reference_20261019.jpg，原图已有圆角外框；运行态PkTierBar深色矩形与暂停按钮盖住原画，顶部72px布局又裁掉约90px原框下沿。

本任务只改PlanBBattleUI显示：透明化旧底板与暂停常态底板，从原直播图以AtlasTexture引用完整外框映射到现有72px顶栏；清除进度条StyleBox上下留白，将16px填充收在框内；状态字加描边。保留原PK、Tier、阶段皮肤/不规则尖角、三列/棋盘范围、暂停按钮触控尺寸。运行验证初始49%、T1/56%、T2/64%、T5/90%、矛盾100%，点击暂停及Esc恢复与卡片发表。仅本地，不推送。
