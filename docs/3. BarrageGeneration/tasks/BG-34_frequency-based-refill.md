# BG-34 现有计时批次在新 Tier 容量下补位

**状态：已有批次补位 · 待 Tier 容量联调**

## 开始前阅读
- `AGENTS.md`、`project.godot`、本系统 README 与最新实际完成日志
- 当前相关 GDScript、场景和数值配置
- 关联：BG-16 / 现有 BG-02、BG-04、BG-07

## 当前已实现的基础
现有 _spawn_normal_batch、_restart_spawn_timer 与释放容量重启计时已工作，本卡聚焦新 Tier 配额接线。

## 本卡唯一功能
现有计时批次在新 Tier 容量下补位。

## 触发条件
当前 Tier 的前景占用数低于本档名额时

## 应发生的行为
继续复用 BarrageArea 当前 SpawnTimer 和 NormalSpeechSelector，在后续生成时机按现有批次数量产生随机话语，直至达到本档名额。

## 验收
T2 容量 13，移除 4 条后按照定时批次持续补位；达到容量后按现有上限控制。

## 交付
提交本功能对应的变更与 Godot 实际运行验收结果，并更新系统 README 与完成日志。
