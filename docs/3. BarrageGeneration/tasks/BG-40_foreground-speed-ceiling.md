# BG-40 普通前景运动速度上限

**状态：待实施**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 前置：现有 CS-07 的移动倍率入口
- 后续消费者：BG-20、BG-21、BG-22、BG-23

## 当前已实现的基础
当前 _movement_speed_multiplier 直接乘 LevelProfile.base_move_speed_pixels_per_second。

## 本卡唯一功能
普通前景运动速度上限。

## 触发条件
前景普通话语生成及其运动速度发生变化时

## 应发生的行为
将运动速度限制在可调整的阅读友好范围内，覆盖基础速度、Tier 倍率以及四种运动方式。

## 验收
T1～T5 各种运动的前景实例符合速度上限，短话语在游戏区内可辨读。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
