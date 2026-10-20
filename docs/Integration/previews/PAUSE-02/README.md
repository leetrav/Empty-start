# PAUSE-02 结算页暂停证据

代码3e9e892；Godot4.7.2 Steam / Windows D3D12 Forward+ / RTX3050 Laptop；真实1280×720。result_paused.png为原正式Sandbox结算组合页收到实际Esc后，暂停菜单显示于结算页上方的Viewport截图，无加工。

runtime.log：REST_PAUSE_DONE failures=0。结算页、历史圣典、历史败者卡均实际Esc打开菜单，并通过真实鼠标点击进入设置／继续恢复，音乐冻结、焦点恢复、全屏设置退出、结果不变、返回菜单通过。结算上下文由RestSession夹具准备，不冒充人工通关。

global_regression.log：原六个正式顶层页面GLOBAL_PAUSE_DONE failures=0；两个日志均无ERROR/WARNING。仅本地提交，用户要求PR继续暂缓。
