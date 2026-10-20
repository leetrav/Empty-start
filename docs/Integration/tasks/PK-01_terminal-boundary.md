# PK-01 · PK终点卡住与百分比显示

2026-10-20，分支fix/pk-terminal-boundary-20261020，接续当前本地bd6ae2c。入口：AGENTS.md、known_traps.md、PlanBBattleHost、BattleAttemptFlow、Sandbox Plan B接线、PlanBBattleUI，以及PERF-01日志。

问题：用户咕拉T5界面显示100%，仍未进入矛盾/击破。先隔离分析，再按用户授权在真实GUI复现后修复。保持感染、人口、PK增长速率和满值阈值不变。

验收：真实咕拉场景复现99.9995%卡住；修复后四Boss同起点逐帧推进至1.0，Host结束与正式Flow满值各一次，矛盾阶段实际启动；0%失败与微小增量累计测试；1%不误解为100%，未满显示99%，不足1%显示<1%。
