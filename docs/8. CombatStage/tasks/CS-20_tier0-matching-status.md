# CS-20 T0 展示搜索 PK 对手的状态文案

**状态：已有状态标签 · 待文案接线**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：CS-19 / 现有 SandboxBattleHud

## 当前已实现的基础
BattleHud 现有 BattleStateFeedback 标签可直接显示状态字符串。

## 本卡唯一功能
T0 展示搜索 PK 对手的状态文案。

## 触发条件
新一场普通战斗开始且当前 Tier 为 T0 时

## 应发生的行为
通过现有 BattleHud.show_battle_state() 展示策划可配置的「正在搜索 PK 对手……」或「等待对手连线……」。

## 验收
新开局和重开时正确显示待连接文字，T1 正式连线后显示对手状态。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
