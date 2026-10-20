# PK-01 实机证据

修复代码SHA：e4bfd4dbcc42c29356c3d3a6d7df7fe525280452 。Godot4.7.2 Steam，D3D12 Forward+，RTX3050 Laptop，真实GUI1280×720。

before_1280.png与before.log为修改前Gula实际卡住；near-limit_1280.png为修复后未满显示99%；gula_contradiction_1280.png为自动推进到满值后的真实矛盾击破转场。

four-boss-runtime.log：四Boss全部从0.999995正常推进，末端与Flow满值信号各一次，矛盾阶段实际启动；另检查Host1%/0.4%显示，PK_GUI_DONE failures=0。boundary-unit.log：上下端点、累计、平局和debug结束去重均通过。

测试只布置临界起点/固定人口，不代替从头自然通关；正式场景预载隔离偶发后台冷加载超时。详细口径和未测范围见PK终点_PK-01日志。
