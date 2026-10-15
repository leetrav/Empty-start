# SHEET-A 2026-10-15 紧急内测部分接线

新增 CombatNumericsConfig 与正式 Resource，BattleAttemptFlow 改从 Resource 启动 HitResolution、回拉、蓄力、准星半径、弹幕寿命、直播观众加权与 PK 奖励。
核心数值源表 06：PK 初始 50%，回拉 0.08 百分点/秒，单发收益强度 1/2/3 为 0.4/0.7/1.2 百分点，蓄力 0.8 秒，PC 半径 72px。
Godot 4.7.2 生产开场 headless 150 帧启动退出 0。INT-01 测试场景在当前 main 和本分支都触发相同的 null target/get_global_rect 错误，因此不能宣称此综合场景回归通过。
剩余：05/06/08/09 每个字段的自动原表映射还没有完成；所有更动需在合并后继续检查真实战斗体验。
