# 8. CombatStage 战斗阶段系统任务拆分

## 系统目标

INT-01 已在正式 Sandbox 完成 HitResolution、BarrageArea、OpponentPKBar 和 AudioManager 的绑定，开局调用 `begin_combat()`。每次最终 PK 更新先同步档位，再由攻击提交回调读取档位创建复读计划；生成倍率只影响新弹幕。Tier 状态已连接可见反馈，Viewer / Like 的档位数值规则仍待配置。PK 满值由 Sandbox 停止普通战斗并启动真实 ContradictionBreak 入口。

战斗阶段系统负责根据当前 PK 判断普通战斗处于 Tier 0～5 的哪个档位，并把这个档位告诉其他系统。

它负责：
1. 开局 Tier 0；
2. 升档、降档和跨多档；
3. 一发命中全部结算完以后再更新档位；
4. 把当前档位配置交给弹幕生成、复读、对手回拉和表现系统；
5. PK 满时结束普通战斗并进入矛盾阶段；
6. 协调进入矛盾阶段前的清理。

## 当前已实现数据

`data/combat_stage/tier_catalog.tres` 为 Tier 0～5 的静态配置来源。`CombatStageTierCatalog.get_tier_config(tier)` 按档位读取各自的升/降档阈值、生成数量/频率/移动/寿命倍率、对手回拉倍率、每次命中复读数和对手立绘状态标识。

TT-14 在 `CombatStageTierConfig` 增加 `neutral_weight_multiplier`（默认 1.0）；正式 Tier 0～5 分别为 `1.00 / 0.99 / 0.70 / 0.40 / 0.15 / 0.00`。CombatStage 随当前 Tier 通过 `neutral_weight_multiplier_changed` 把该倍率交给 BarrageArea，绑定时也补发。它只改变后续普通话语类别抽取，不改动静态关卡比例或已有弹幕。

CS-02 的运行时 `CombatStage` 对象通过 `CombatStage.new(tier_catalog)` 接收 Tier 配置目录；`begin_combat()` 在新一场或当前关重开时把当前 Tier 设为 0，`get_current_tier()` 只读该状态。CS-03 的 `try_tier_up(final_player_pk)` 按当前 Tier 配置，在最终 PK 达到升档阈值时升一档；CS-04 的 `try_tier_down(final_player_pk)` 在最终 PK 严格低于降档阈值时降一档。CS-05 的 `update_tier_for_pk(final_player_pk)` 循环应用这两条既有规则，直到最终 Tier 与 PK 所在区间一致。

CS-06 的 `bind_hit_resolution(hit_resolution)` 连接 `HitResolution.final_player_pk_updated`，每次收到整发或回拉更新后的最终 PK 时调用 `update_tier_for_pk()`。命中中间计算不会进入该回调。CS-09 在当前 Tier 确定后广播回拉倍率与 Tier 5 状态；OpponentPKBar 通过 `bind_opponent_pk_bar()` 接收。

CS-07 通过 `bind_barrage_area(barrage_area)` 连接 BarrageArea 的真实倍率入口：`set_generation_multipliers()` 接收生成数量、频率和移动速度倍率，`set_lifetime_multiplier()` 接收寿命倍率。开局和最终 Tier 变化后，CombatStage 从当前 Tier 配置广播四个值；绑定时也立即补发当前配置。倍率具体应用和新弹幕实例仍由 BarrageArea 负责，既有弹幕保留生成时的速度和寿命。Sandbox 组合时由场景拥有者实例化并加入 BarrageArea 后，再调用 `bind_barrage_area()`；Lane C 不修改 Sandbox。

CS-08 提供 `get_current_repeat_count_per_hit()`，返回当前 Tier 配置的 `repeat_count_per_hit`。命中结算完成并更新 Tier 后，普通复读计划创建方读取该数量与 `get_current_tier()`，传给 `RepeatPlan.create_normal_hit_plan()`；RepeatPlan 在创建时保存固定数量和结算档位。CombatStage 不缓存复读计划，也不拥有复读统计。

CS-10 提供 `tier_state_changed(current_tier)`，在开局同步 Tier 0，并在跨档计算完成后只广播一次最终 Tier。Tier 上升时发出 `audio_event_requested(&"tier_up")`；`bind_audio_manager(audio_manager)` 将该事件接到 AU-01 的 `AudioManager.play_event(StringName)`。当前 LiveDataHud 只显示四项计数，没有 Tier 接收端；Sandbox 场景拥有者需把 `tier_state_changed` 接到实际 Tier 表现组件。此接口不包含 AU-02 音乐状态切换。

## 任务顺序

CS-11 提供 `get_stage_result(final_player_pk, maximum_player_pk)`：低于配置满值返回 `StageResult.NORMAL_COMBAT`，达到满值返回 `StageResult.ENTER_CONTRADICTION`。该结果即时派生，不保存第二份 PK 或阶段状态。Sandbox 收到最终 PK 后读取结果，立即调用 `HitResolution.set_normal_pk_resolution_enabled(false)` 固定满值，并停止对手回拉与普通生成；本发事实提交后沿用既有 `_complete_normal_combat()` 启动 12 系统。延迟切换期间的负增量也无法改低 PK。重开创建新的 HitResolution，普通结算恢复。真假矛盾内容和成败判定继续归 12 系统；缺失内容只用独立 TEST_ONLY 关卡验收，正式配置保持原样。

CS-11 仅新增 `tests/combat_stage/test_cs_11_enter_contradiction.gd` 一个用例；图形运行 Sandbox 的临时验收驱动验证满值冻结、回拉停止、真实矛盾入口和重开恢复，驱动在验收后删除。

CS-12 已核实并沿用 Sandbox `_stop_normal_combat()` 的协调入口：AttackChargeInput 停用时取消蓄力、飞行快照与硬直 Timer；BarrageArea 停止生成并清空旧普通 / 复读视图与容量；RepeatDelayQueue 清空普通等待请求，实际生成统计保留供胜利提交。全部清理完成后 `_complete_normal_combat()` 才启动 ContradictionBreak 内容、矛盾生成与限时窗口。各状态继续由所属系统清理。

满值通知与帧尾清理之间，Sandbox 的普通复读调度还检查 `HitResolution.allows_normal_pk_resolution()`，普通结算关闭后立即停止推进，防止到期请求在延迟窗口生成并进入胜利统计；本发事实提交仍按原流程完成。矛盾复读继续按矛盾阶段开关调度。CS-12 未新增永久自动化测试；Godot 4.7.2 TEST_ONLY 图形 Sandbox 临时冒烟已覆盖蓄力、飞行和硬直三种清理状态。

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| CS-01 | 定义 Tier 配置数据 | 无 |
| CS-02 | 开局固定 Tier 0 | 无 |
| CS-03 | 升档判定 | 1 个关键单元测试 |
| CS-04 | 降档判定 | 1 个关键单元测试 |
| CS-05 | 一次 PK 变化跨多档 | 2 个关键单元测试 |
| CS-06 | PK 更新后重新判断档位 | 无新增自动化测试 |
| CS-07 | 把生成倍率交给弹幕生成 | 无新增自动化测试 |
| CS-08 | 把复读配置交给复读系统 | 无新增自动化测试 |
| CS-09 | 把回拉倍率和 Tier 5 状态交给对手系统 | 无新增自动化测试 |
| CS-10 | 把档位变化交给直播/视听表现 | 无新增自动化测试 |
| CS-11 | PK 满进入矛盾阶段 | 1 个关键单元测试 |
| CS-12 | 进入矛盾阶段前清理普通战斗 | 无新增自动化测试 |
| CS-13 | Tier 升档清屏、降档震动反馈（需求暂存，未完成） | 待后续正式拆卡 |

## 测试预算

只保留 5 个纯逻辑 case：

- 到达升档阈值会升档；
- 低于降档阈值会降档；
- 一次 PK 上升可以跨多档；
- 一次 PK 下降可以跨多档；
- PK 满会得到“进入矛盾阶段”的阶段结果。

Tier 配置字段、跨系统通知、画面音乐、阶段清理和静音过渡全部做最小联调。

## 依赖顺序

CS-01～05 可以先完成纯档位逻辑。
CS-06 等 6. HitResolution。
CS-07 已接入 3. BarrageGeneration 的 BarrageArea 公开接口。
CS-08 已提供 10. Repeat 创建普通复读计划所需的当前 Tier 数量接口。
CS-09 等 7. OpponentPKBar。
CS-10 的 Tier 状态与 AU-01 音效绑定已在 INT-01 Sandbox 接通；直播热度数值变化继续等待具体规则。
CS-11 等 12. ContradictionBreak 有真实入口后联调。
CS-12 等 3/5/10 的清理入口存在。

## 待整理：CS-13 升降档表现需求

策划新增需求：T0→T1 以及其他**向上突破**时短暂清空场上弹幕，并配合阶段突破动效；T1→T0 **不清屏**，用屏幕抖动表现降档。清屏类别、其他下行路径、多档跨越、时长和输入影响仍待确认。详见 `tasks/CS-13_pending-tier-transition-feedback.md`。**仅记录，未修改程序，暂不派工。**

## 2026-10-09 战斗打磨单功能开发卡

本轮确认的高密度弹幕、四种运动、交叉层级、富文本、舆论潮汐、弹幕群聚、伪纵深、命中冲击波、复读感染、Tier 升降档与沉默爆发，现已拆为单一功能开发卡。每张卡仅定义触发条件、预期行为与验收结果；可调数值以实测和后续策划配置为准。卡片状态均为**待实施**。

| 卡号 | 本卡唯一功能 | 状态 |
| --- | --- | --- |
| [CS-14](tasks/CS-14_tier-up-clear-all.md) | 所有升档清空全部可见弹幕 | 待实施 |
| [CS-15](tasks/CS-15_tier-up-breakthrough.md) | 升档短暂突破动效 | 待实施 |
| [CS-16](tasks/CS-16_tier-down-shake.md) | 全部降档只震屏 | 待实施 |
| [CS-17](tasks/CS-17_silence-and-burst.md) | 关键阶段沉默后爆发 | 待实施 |

关联依赖及实施顺序以各卡的上游功能卡为准；共享场景与组件按实际 Owner 的任务流程依次集成。
