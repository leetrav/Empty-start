# 8. CombatStage 战斗阶段系统任务拆分

## 系统目标

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

CS-02 的运行时 `CombatStage` 对象通过 `CombatStage.new(tier_catalog)` 接收 Tier 配置目录；`begin_combat()` 在新一场或当前关重开时把当前 Tier 设为 0，`get_current_tier()` 只读该状态。CS-03 的 `try_tier_up(final_player_pk)` 按当前 Tier 配置，在最终 PK 达到升档阈值时升一档；CS-04 的 `try_tier_down(final_player_pk)` 在最终 PK 严格低于降档阈值时降一档。CS-05 的 `update_tier_for_pk(final_player_pk)` 循环应用这两条既有规则，直到最终 Tier 与 PK 所在区间一致。

CS-06 的 `bind_hit_resolution(hit_resolution)` 连接 `HitResolution.final_player_pk_updated`，每次收到整发或回拉更新后的最终 PK 时调用 `update_tier_for_pk()`。命中中间计算不会进入该回调。CS-09 在当前 Tier 确定后广播回拉倍率与 Tier 5 状态；OpponentPKBar 通过 `bind_opponent_pk_bar()` 接收。

## 任务顺序

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
CS-07 等 3. BarrageGeneration。
CS-08 等 10. Repeat。
CS-09 等 7. OpponentPKBar。
CS-10 等 9. LiveDataPresentation / 视听表现。
CS-11 等 12. ContradictionBreak 有真实入口后联调。
CS-12 等 3/5/10 的清理入口存在。
