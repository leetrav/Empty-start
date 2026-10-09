# LC-11 前景同屏数量配置读取入口

**状态：已由 CS-24 统一承接 · 归档**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：CS-24 / BG-16

## 当前已实现的基础
已核对 LevelProfile 现有 normal_barrage_screen_cap 为整关基础值，CombatStageTierConfig 尚未有前景名额字段；本卡归档为口径索引。

## 本卡唯一功能
前景同屏数量配置读取入口。

## 触发条件
关卡加载当前战斗配置时

## 应发生的行为
当前关卡的基础生成配置继续由 LevelProfile 提供；T0～T5 各档前景名额统一读取 CombatStageTierConfig 的现行配置。

## 验收
关卡读取接口与 CS-24 的同一份 Tier 配置对应；前景容量按 BG-16 消费。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
