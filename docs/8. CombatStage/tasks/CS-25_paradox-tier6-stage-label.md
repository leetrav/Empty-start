# CS-25 Paradox 阶段界面显示为 T6

**状态：待显示接线**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：现有 CS-11 / CB-13 / SandboxBattleHud.refresh_pk

## 当前已实现的基础
现有 CombatStageCatalog 仅保存 T0～T5，矛盾击破是独立 ContradictionBreak 状态。

## 本卡唯一功能
Paradox 阶段界面显示为 T6。

## 触发条件
普通 T5 PK 达到满值，已经进入 ContradictionBreak 时

## 应发生的行为
让 BattleHud 的阶段展示清楚标记 T6 / Paradox，并与当前六句矛盾区域匹配；普通阶段 Tier 状态继续保留 T0～T5 的运行数值。

## 验收
T5 正常战斗仍显示 T5，普通满值转入矛盾击破时显示 T6 / Paradox。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
