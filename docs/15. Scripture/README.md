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
- 未提交暂存和重开撤回由 SC-05 继续实现。
- Sandbox 周目初始化已经绑定 Scripture 接收方；场景节点结构保持现状。

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
