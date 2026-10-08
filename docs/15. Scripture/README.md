# 15. Scripture 圣典系统任务拆分

## 系统目标

圣典系统保存玩家每关最终确认的神谕句子。

每条经文需要保存：

- 原关卡；
- 主播；
- 原句；
- 倾向；
- 章号；
- 首次生成后固定的节号。

同一关最多一条。没有形成神谕的关卡保留缺章。

## 当前数据底座

- `ScriptureEntry` Resource 保存 `level_id`、`streamer_name`、`original_line_id`、`original_line_text`、`tendency_id`、`chapter_number` 和 `verse_number`。
- `ScriptureData.entries` 持有当前周目的经文记录；数据由 `SaveData.scripture_data` 保存并随当前周目读写。
- `bind_confirmation_state(confirmation_state, level_catalog)` 接收真实 `confirmation_committed(run_data, level_id, candidate)`；只处理所属 `SaveData.scripture_data`，并按关卡目录解析来源。
- `write_confirmed_oracle(level_profile, candidate)` 将首次正式确认写入 `entries`，同周目同关后续提交保持首条记录；去重直接查询保存列表，重建确认状态或读档后仍生效。
- 候选当前提供 `original_sentence_id` 和 `tendency`；原句文本从该关 `normal_speech_pool` 按 ID 匹配，主播名和章号复制自 `LevelProfile.streamer_name` / `level_order`。未知原句拒绝写入。
- 节号范围只保存在 `data/scripture/verse_number_config.tres`（当前 1～99）；首条正式写入时抽取一次整数并存入 `ScriptureEntry.verse_number`，读取、重复提交和读档都沿用该值。
- `get_entry_for_level(level_id)` 返回单关经文独立快照；`get_ordered_entries()` 按经文保存的原章号返回排序快照。
- `get_chapter_slots(level_catalog)` 为真实目录中的每关返回 `{level_id, chapter_number, entry}`；无经文时 `entry = null`。缺章参与排序，原章号不压缩；全空圣典仍返回目录中的全部空章，章节视图即时生成且不写回保存列表。
- `pending_entry` 是现有 ScriptureData 中的单条本场暂存；`stage_oracle(level_profile, candidate)` 保存未确认快照，暂存节号为 0，不进入正式经文 / 章节视图。同关可更新暂存，已有正式经文的关卡拒绝暂存。
- 正式 `confirmation_committed` 仍直接调用 `write_confirmed_oracle()`，以真实确认候选写入并清掉同关暂存；只有此时抽取并固定节号。
- `rollback_uncommitted(level_id)` 只撤回匹配当前关的暂存，正式 `entries` 保留。Sandbox 的真实 `restart_current_attempt()` 已调用该入口，读档后的本场暂存也适用。
- Sandbox 周目初始化已经绑定 Scripture 接收方；场景节点结构保持现状。

## SC-07：神降临读取

- 19 的 `DivineDescentScriptureInput.build_snapshot(run_data)` 直接消费 `SaveData.scripture_data.get_ordered_entries()`，返回已提交经文的独立 `Array[Dictionary]` 快照；暂存经文排除，空圣典或缺少输入返回空数组。
- 输出保留 `level_id`、`streamer_name`、原章号 `chapter_number` 和固定 `verse_number`；`original_line_id` / `original_line_text` / `tendency_id` 分别映射为 DD-02 使用的 `original_sentence_id` / `original_sentence_text` / `tendency`。原句 ID 转为同候选一致的 String。
- 原文、章序、固定节号继续读取 15 的正式记录。同句多章完整保留，缺章不生成假经文且后续章号保持原值；DD-07 后续按稳定原句 ID 处理加权。
- 本卡只建立读取适配；终局进入时调用并持有快照的组合归 DD-01，圣典加权归 DD-07。

## SC-08：结局读取

- 正式供给链复用已有 `EndingScriptureDisplayData.build_from_scripture(run_data.scripture_data, level_catalog)` → `ScriptureData.get_chapter_slots(level_catalog)`。调用方传入所属周目的已提交圣典与完整关卡目录，即可获得全部经文及每关缺章行。
- 每行保留 `level_id`、`chapter_number`、`verse_number`、`streamer_name`、`original_line_id`、`original_line_text`、`tendency_id`、`has_oracle`、`status`。已提交章号 / 节号和原文读取保存快照，后续关卡配置变化、重复读取及读档均沿用已保存值。
- 缺章沿用目录原章号，`has_oracle=false`、`verse_number=0`、`status=not_formed_oracle`；暂存经文也采用缺章显示，原章号不压缩。
- EN-07 的 `EndingDisplayData.build(...)` 已消费该适配，输出 `scripture.rows`，并通过 `get_ordered_entries().is_empty()` 得到 `scripture.is_empty`。全空圣典保留全部缺章，区域 `status=not_formed_oracle`。
- 15 继续拥有经文与编号；20 只持有独立显示快照。SC-08 已用正式确认和原生 SaveData 存读验证现有链路，沿用现有实现；EN-01 终局接收与 EN-08 页面仍归对应任务。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| SC-01 | 经文记录数据 | 无 |
| SC-02 | 确认神谕写入经文 | 2 个关键单元测试 |
| SC-03 | 首次生成并固定节号 | 2 个关键单元测试 |
| SC-04 | 按原关卡序号排列并保留缺章 | 2 个关键单元测试 |
| SC-05 | 未提交经文在重开时撤回 | 1 个关键单元测试 |
| SC-06 | 提供给休息时刻 | 无新增自动化测试 |
| SC-07 | 提供给神降临 | 无新增自动化测试 |
| SC-08 | 提供给结局 | 无新增自动化测试 |

## 测试预算

只保留 7 个纯逻辑 case：

- 同一关第一次可以写入一条经文；
- 同一关第二次不会再新增；
- 首次写入会生成节号；
- 再次查看沿用原节号；
- 经文按关卡序号排列；
- 没有经文的关卡保留缺章位置；
- 当前关未提交经文在失败重开时撤回。

## 依赖顺序

SC-01 可先做。
SC-02～05 等 13. FinalOracle 的确认结果 / 7 的重开流程。
SC-06 等 18. Rest。
SC-07 等 19. DivineDescent。
SC-08 等 20. Ending。
