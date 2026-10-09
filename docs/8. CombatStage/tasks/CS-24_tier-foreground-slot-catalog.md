# CS-24 T0～T5 唯一前景名额配置

**状态：待实施**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：BG-16 / 现有 CombatStageTierCatalog

## 当前已实现的基础
当前 CombatStageTierConfig 有生成数量、频率等倍率，但尚未保存前景同屏名额；LC-11 已归档为旧口径索引。

## 本卡唯一功能
T0～T5 唯一前景名额配置。

## 触发条件
每一普通战斗 Tier 的策划参数被读取时

## 应发生的行为
在 CombatStageTierConfig 中提供唯一的本档前景同屏名额配置：T1=10、T2=13、T3=16；T4=19、T5=22 作为每档递增 3 条的当前规划；T0 值留待策划填写。将当前 Tier 对应名额交给 BarrageArea。

## 验收
Tier 切换时公开的前景名额能反映 T1=10/T2=13/T3=16；每档数据可单独调整。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
