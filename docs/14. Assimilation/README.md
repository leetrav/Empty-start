# 14. Assimilation 吞并系统任务拆分

## 系统目标

吞并系统负责保存“真正击败对手以后，玩家从对方那里带走了什么”。

它保存两类长期成果：

- 可继承词库与出现权重；
- 可继承弹幕特性。

同时区分“关卡通关”和“真正击败”，并把已获得内容提供给后续关卡、休息时刻和神降临。

## 当前数据底座

- `AssimilationData` 是吞并系统的数据 Resource，由当前周目的 `SaveData.assimilation_data` 持有。
- `completed_streamer_ids` 与 `defeated_streamer_ids` 分别保存已通关主播 ID 和真正击败主播 ID。
- `inherited_word_weights` 以稳定词库 ID 为键、出现权重为值；`inherited_trait_ids` 保存可继承特性 ID。
- `defeated_level_ids` 保存当前周目已经提交真正击败结果的稳定关卡 ID；与主播集合共同阻止同场重复提交和同主播重复奖励。
- `completed_level_ids` 与通关主播集合单独记录普通通关。`register_level_result(level_id, streamer_id, pk_won, contradiction_broken, oracle_confirmed)` 返回 `completed_added` / `defeated_added` 本次新增标记：PK 胜利可只新增通关，击破且正式确认后才新增击败。
- `register_defeated_streamer(level_id, streamer_id, contradiction_broken, oracle_confirmed)` 只在两项事实同时成立时登记，首次返回 `true`，重复返回 `false`。击破事实来自 CB 的 `Outcome.BREAKTHROUGH`，确认事实来自同周目同关的 `confirmation_committed` 或 `get_confirmed_selection(level_id)`。
- 真正击败自动包含通关；仅通关关卡无法使用词库和特性登记入口，既有吞并成果继续保留。
- `register_inherited_word_pool(level_id, pool_id, appearance_weight, can_inherit, is_contradiction_pool)` 只允许已登记真正击败关卡的可继承普通词库；稳定 pool_id 只保存首次权重，矛盾专属池和禁止继承的池被排除。
- `register_inherited_trait(level_id, trait_id, can_inherit)` 只登记已真正击败关卡允许继承的特性，跨主播来源的同一稳定 trait_id 只保留一次；实际特性装配与兼容仍归 4. BarrageTraits。
- `LevelProfile.normal_pool_inheritance` 可引用 `WordPoolInheritanceConfig`，提供整池稳定 `pool_id`、`appearance_weight`、`can_inherit` 和 `is_contradiction_pool`。实际内容通过同关 `get_normal_speech_pool()` 读取，兼容导表 `normal_speech_pool_source: LevelSpeechPool` 和旧内嵌词库；整池权重独立于单句权重。默认 null 表示没有配置词库奖励。
- `LevelProfile.inheritable_trait_ids` 是独立的稳定特性 ID 白名单，默认空；`special_trait_ids` 表示本关所用特性，不能直接当作继承白名单。登记时仅对白名单项传入 `can_inherit=true`，后续装配仍由 4 系统校验兼容。
- FO-11 已在 Sandbox 正式确认回调接通词库 / 特性登记，TEST_ONLY 配置在 `tests/fixtures/fo11/`，正式关卡配置仍未填写。AS-06 已提供后续关卡只读消费入口；实际混入生成和战斗特性触发留相应联调卡。

## AS-06：后续普通关卡读取

- 2 系统提供 `LevelCatalog.get_inherited_content_snapshot(assimilation_data)`，输入当前同一 `SaveData.assimilation_data`，复用 14 的 `get_current_content_snapshot()` 读取已提交池 ID / 权重与 trait ID。
- 返回 `{inherited_word_pools: Array[Dictionary], inherited_trait_ids: Array[StringName]}`；每个池为 `{pool_id: StringName, appearance_weight: float, speeches: Array[LevelSpeech]}`。没有吞并成果或数据为 null 时两项都是空数组。
- 使用已有完整关卡目录按 `normal_pool_inheritance.pool_id` 定位普通词库，并复用 `LevelProfile.get_normal_speech_pool()`；导表 Resource 的 pool_id 必须与继承 ID 一致。当前目录未配置、禁止继承、矛盾标记或 ID 不匹配的池不生成词句结果，不回写 14 的保存记录。
- 整池权重保留正式提交值，不从当前配置重算。目录复用同池时只返回一次；词句 Resource 为独立副本，返回权重 / trait 数组 / 词句的修改均不影响 14 或静态目录。未知池 ID 不猜测文件路径或创建第二份词库注册表，调用方需提供含已获池配置的完整目录。
- 4 系统从同一返回值的 `inherited_trait_ids` 读取实际已获 ID，现有 `BarrageTraitSet.add_trait()` / `are_compatible()` 继续负责装配与兼容；AS-06 不合并本关特性、不触发战斗效果或把特性装到矛盾实例。
- A 后续在第二关普通战斗准备处读取此入口，将池集合和 trait ID 交给各自消费者。本卡没有修改 Sandbox / Rest / DivineDescent / Ending，完整生成混池及 BT-13 触发不在本次范围。

## AS-07：当前关失败与重开

- `Sandbox.restart_current_attempt()` 沿用当前 `SaveManager.data` 和同一 `SaveData.assimilation_data`，重建本场战斗对象；此前已提交的通关 / 击败 ID、词库整池权重、特性 ID 与 `committed_additions_by_level` 来源记录保持不变。
- `OpponentPKBar.attempt_failed` 触发 Sandbox 清理当前普通命中、复读和倾向暂存；重开还丢弃待提交经文并重置失败锁。这些清理入口只处理当前尝试，吞并成果继续由 14 的周目 Resource 持有。
- 当前关奖励仍只在同周目、同关卡的真实击破成功与 FinalOracle 正式确认后，经 FO-11 回调登记。普通战斗暂存、击破但尚未确认，以及未击破的 PK 胜利均不产生真正击败型吞并成果；无需增加吞并暂存或回滚接口。
- Godot 4.7.2 真实场景 smoke 已验证：第一关正式提交后，经 Rest 继续到第二关，手动重开、PK 归零失败后重开、神谕确认前重开及未击破结果后重开均保留前关成果与来源，当前关奖励保持未登记，AS-06 消费入口仍可读取前关内容。
- 本卡复用已存在的失败 / 重开行为，只补文档和验收日志。验证范围为同一运行中周目的关卡重开；新周目由 `SaveManager.new_game()` 创建新的数据，磁盘存档往返不属于本卡。

## AS-08：已提交来源与休息读取

- `committed_additions_by_level` 由 14 持有，按 `level_id` 保存 `{streamer_id, inherited_word_weights, inherited_trait_ids}`。真正击败首次登记成功时建立来源；词库 / 特性首次登记成功时同步写入该来源的新增记录。重复或被拒绝的登记不新增来源条目。
- 现有登记函数仍是同步正式写入入口：调用方完成本场词库 / 特性登记后再进入休息读取。来源记录随 `SaveData.assimilation_data` 保存；Rest 读取不会再次发奖，也不会消费或清空记录。
- `get_new_content_for_source(level_id, streamer_id)` 返回 `{level_id, streamer_id, inherited_word_weights, inherited_trait_ids}` 的独立快照。只含该来源首次实际新增的词库 ID / 权重和特性 ID；未知来源、主播不匹配、仅通关、已击败但无新增均返回 `{}`。
- `get_current_content_snapshot()` 返回 `{inherited_word_weights, inherited_trait_ids}` 的周目总量独立快照，可在无本场新增时读取既有内容。
- 旧存档缺少来源字段时默认空字典，既有总量保留。历史归属不从总量或 ID 列表顺序补算；继承登记要求已经保存的正式来源，缺少来源的旧关卡拒绝新的无归属写入。
- Rest 消费端通过上述查询读取结果；AS-08 不修改 RS-03 分支，合入后再补 RS-03 的调用。

## AS-09：神降临读取

- 终局调用方在进入时调用现有 `DivineDescentAssimilationInput.build_snapshot(run_data)`；该入口通过 `SaveData.assimilation_data.get_current_content_snapshot()` 取得实际已获得的全部词库权重与特性 ID。
- 总量与来源记录继续由 14 持有，19 仅持有公开接口返回的独立快照；后续登记或修改快照互不影响。
- 没有成果时固定返回 `{inherited_word_weights: {}, inherited_trait_ids: []}`。总量读取沿用 AS-08，包含旧存档已有但缺少来源记录的成果。
- 本卡完成读取接口联调；完整终局进入组合仍归 DD-01，Rest 本场新增、特性装配与权重计算由各自任务负责。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| AS-01 | 吞并成果数据 | 无 |
| AS-02 | 真正击败后登记主播结果 | 2 个关键单元测试 |
| AS-03 | 登记可继承词库与权重 | 2 个关键单元测试 |
| AS-04 | 登记可继承特性并去重 | 2 个关键单元测试 |
| AS-05 | 区分通关与真正击败 | 1 个关键单元测试 |
| AS-06 | 提供给后续关卡 | 无新增自动化测试 |
| AS-07 | 当前关失败时保留既有吞并成果 | 无新增自动化测试 |
| AS-08 | 提供给休息时刻 | 无新增自动化测试 |
| AS-09 | 提供给神降临 | 无新增自动化测试 |

## 测试预算

只保留 7 个纯逻辑 case：

- 同一主播第一次真正击败可以登记；
- 同一主播重复登记不会重复；
- 新词库可以登记；
- 同一词库重复登记不会重复；
- 新特性可以登记；
- 同一特性重复登记不会重复；
- 只有通关、没有真正击败时，不产生真正击败型吞并成果。

词库实际生成、特性实际装配、休息展示和终局读取全部做跨系统联调。

## 依赖顺序

AS-01 可先做。
AS-02～05 等 13. FinalOracle 的真正击败结果。
AS-06 等 2. LevelConfiguration / 4. BarrageTraits。
AS-07 等 7. OpponentPKBar。
AS-08 等 18. Rest。
AS-09 等 19. DivineDescent。
