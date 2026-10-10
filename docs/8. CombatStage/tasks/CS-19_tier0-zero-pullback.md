# CS-19 T0 对手 PK 回拉倍率调为 0

**状态：只需配置与实测**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：现有 CombatStage.bind_opponent_pk_bar / OpponentPKBar

## 当前已实现的基础
data/combat_stage/tier_catalog.tres 当前 Tier0 的 multiplier=1.1；OpponentPKBar 已接受 0 倍率。

## 本卡唯一功能
T0 对手 PK 回拉倍率调为 0。

## 触发条件
普通战斗处于 T0 搜索对手阶段时

## 应发生的行为
将正式 Tier0 配置中的 opponent_pullback_multiplier 设为 0；进入 T1 时继续读取已有 T1 回拉倍率。

## 验收
T0 等待时 PK 随时间保持稳定，进入正式 T1 且对白完成后开始按当前配置回拉。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
