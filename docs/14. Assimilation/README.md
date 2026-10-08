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
- `LevelProfile.normal_pool_inheritance` 可引用 `WordPoolInheritanceConfig`，提供整池稳定 `pool_id`、`appearance_weight`、`can_inherit` 和 `is_contradiction_pool`。实际内容继续由同关 `normal_speech_pool` 拥有，整池权重独立于单句权重。默认 null 表示没有配置词库奖励。
- `LevelProfile.inheritable_trait_ids` 是独立的稳定特性 ID 白名单，默认空；`special_trait_ids` 表示本关所用特性，不能直接当作继承白名单。登记时仅对白名单项传入 `can_inherit=true`，后续装配仍由 4 系统校验兼容。
- FO-11 TEST_ONLY 配置在 `tests/fixtures/fo11/`，已用真实登记 / 来源读取 API 验证；正式关卡配置仍未填写。Sandbox 词库 / 特性奖励接线、后续混入生成和特性装配分别留 FO-11、AS-06 与 BT-13。

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
