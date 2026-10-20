# PAUSE-03 PK触屏暂停按钮

用户要求Android没有键盘时可在PK页触摸暂停。复用原PauseMenu与暂停信号，顶部PK栏右侧加入原生Button「暂停」，触控区域不少于96×72逻辑像素；不覆盖棋盘、手牌、头像操作。HUD只发pause_requested，Sandbox交给原pause_game，沿用取消蓄力、音乐冻结、设置与恢复。不创建第二套菜单，不改项目触控模拟设置。真实GUI检查鼠标／ScreenTouch、暂停前后计时与攻击未误发、恢复、720p及20:9布局，声明Android真机尚未验证。继续当前本地旧main优化，不fetch／rebase／推送／PR。
