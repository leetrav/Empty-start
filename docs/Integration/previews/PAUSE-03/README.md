# PAUSE-03 PK触屏暂停证据

代码d431a2e；Godot4.7.2 Steam / Windows D3D12 Forward+ / RTX3050 Laptop。两张图均1280×720真实Viewport，无加工：pk_pause_button.png显示原PK栏右侧的暂停按钮，pk_touch_paused.png显示通过原生ScreenTouch打开的既有暂停菜单。

runtime.log：PK_TOUCH_PAUSE_DONE failures=0。鼠标、关闭触屏模拟鼠标后的原生ScreenTouch、PK／音乐冻结、设置、恢复、Esc兼容通过。2400×1080窗口现有16:9内容黑边策略下触点按最终视口变换注入，默认模拟开启也只请求一次；未误发射或发表。不是Android真机／APK运行证据。

当前代码仍承接旧main上的本地优化，未拉取最新main，未推送或创建PR。
