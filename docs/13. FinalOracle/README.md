# 13. FinalOracle 终结神谕系统任务拆分

## 系统目标

终结神谕系统只在矛盾击破成功后出现。

它负责：

1. 等待击破后的过渡与复读展示完成；
2. 冻结战斗；
3. 从本场成功命中的普通话语中生成最多三句候选；
4. 每种倾向优先选择普通复读最多的一句；
5. 处理并列、缺少某种倾向和不足三句；
6. 给玩家 10 秒选择；
7. 超时自动选择；
8. 确认后一次性提交圣典、败者卡和吞并结果；
9. 完成后进入休息时刻。

矛盾文本、复读文本和 neutral 普通闲聊都不进入候选；neutral 仍可保存在普通命中历史中。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| FO-01 | 击破成功后进入神谕并冻结战斗 | 无 |
| FO-02 | 建立合格候选池并按原句去重 | 2 个关键单元测试 |
| FO-03 | 每种倾向选复读最多的一句 | 1 个关键单元测试 |
| FO-04 | 候选并列裁决 | 2 个关键单元测试 |
| FO-05 | 候选补位并限制最多三句 | 1 个关键单元测试 |
| FO-06 | 展示后冻结候选列表 | 无 |
| FO-07 | 10 秒选择计时与暂停 | 无 |
| FO-08 | 超时自动选择 | 1 个关键单元测试 |
| FO-09 | 手动 / 自动确认共用一次提交 | 1 个关键单元测试 |
| FO-13 | 主游戏区内复用普通攻击选择神谕 | 无新增自动化测试 |
| FO-10 | 保存到圣典系统 | 无新增自动化测试 |
| FO-11 | 发放败者卡与吞并奖励 | 无新增自动化测试 |
| FO-12 | 完成后进入休息时刻 | 无新增自动化测试 |

## 测试预算

只保留 8 个纯逻辑 case：

- 同一原句多次命中后候选池只保留一条；
- 矛盾与复读文本不进入候选池；
- 每种倾向优先选普通复读最多的一句；
- 复读数并列时优先最近命中的句子；
- 命中时间仍并列时按原句标识排序；
- 候选缺倾向时能够补位且总数不超过三句；
- 超时自动选择按正式排序规则得到一句；
- 同一场手动 / 自动确认最终只提交一次。

UI、10 秒计时器、战斗冻结、奖励系统和休息流程全部做实际联调。

## 依赖顺序

`FinalOracleSession.open_after_breakthrough(level_id, normal_hit_history, repeat_stats, confirmation_state)` 是 FO-01 的真实接收入口：只接受一次击破完成事实，复用候选池并冻结展示快照；普通战斗冻结由 Sandbox 协调。FO-06～09 的候选快照、倒计时、自动排序和单次确认均已完成；FO-13 将展示与手动操作接入中央主游戏区的普通攻击链；FO-10 已复用 SC-02 的 Scripture 正式确认接收链。FO-11～12 继续等待各自奖励与休息依赖。

FO-01 等 12. ContradictionBreak 的成功与过渡完成事件。
FO-02～05 在【6. HitResolution】HR-14 的本场普通命中历史与【10. Repeat】普通复读统计存在后完成纯候选逻辑。
FO-06～09 完成神谕选择流程。
FO-13 在 FO-06～09 基础上替换正式交互表现：候选进入中央主游戏区，并复用普通攻击完成选择；应在 FO-10～12 奖励与休息联调前完成。
FO-10 已复用 SC-02 已接入的 Scripture 正式确认接口：Sandbox 创建并绑定当前周目的确认状态，确认事实携带 `level_id` 与候选原句 ID / 倾向，Scripture 从 `LevelCatalog` 解析原句文本、主播名、原关卡序号并按 `SaveData.scripture_data` 同关去重写入。
FO-11 已接入 16 / 14 的真正击败事实提交，完整奖励验收仍等待正式败者卡资料与关卡吞并配置，详见下方接线状态。
FO-12 等 18. Rest。

## FO-02 当前候选池接口

- `FinalOracleCandidatePool.build_from_normal_hit_history(normal_hit_history)` 只接收 `HitResolution.get_normal_hit_history()` 返回的普通命中快照，并仅保留 `orthodox / heretical / absurd` 三类正式候选。
- 候选按 `original_sentence_id` 去重，并保留首次出现顺序及 HR-14 的原始记录字段；返回值是独立深拷贝。
- 普通复读统计和矛盾复读记录不作为候选来源。后续排序只读取 `RepeatGenerationStats.get_normal_count(original_line_id)`，不会从复读记录新增候选。
- HR-14 已将同一句的普通命中次数和最近命中顺序合并到唯一记录；若输入重复 ID，候选池保留首条记录，不自行汇总第二份统计。

## FO-03 / FO-04 倾向排序接口

- `FinalOracleCandidatePool.select_most_repeated_per_tendency(candidates, repeat_stats)` 对正统、异端、荒谬分别选择普通复读实际生成数最高的一句。
- 计数通过 `RepeatGenerationStats.get_normal_count(StringName(original_sentence_id))` 读取；矛盾复读统计不参与。
- 复读数相同时优先最近命中更晚的句子；最近命中顺序仍并列时按稳定原句 ID 升序裁决。

## FO-05 候选补位接口

- `FinalOracleCandidatePool.fill_missing_tendency_candidates(candidates, repeat_stats)` 先保留各倾向领头候选，再从剩余普通命中候选补足，最多返回三句。
- 补位顺序读取普通复读实际生成数降序、HR-14 的 `last_hit_order` 降序、`original_sentence_id` 升序；复读数由 `RepeatGenerationStats.get_normal_count()` 提供，矛盾复读不参与。若普通话语不足三句，则返回实际数量。

## FO-06 展示快照接口

- 候选展示开放时调用 `snapshot_for_display(final_candidates)` 一次，并保留返回的深拷贝数组作为本次展示列表。
- 选择期间继续显示该快照的原顺序和内容；后续命中或复读统计变化不会重建或重排当前列表。
- Sandbox 在 `final_oracle_opened` 后将 Session 的展示快照交给 `FinalOracleCandidateDisplay.show_candidates()`；正文从当前 `LevelProfile.normal_speech_pool` 按稳定 ID 补到 HitResolution 返回的深拷贝，不写回命中历史。
- FO-13 的候选显示为中央 `BattleArea` 内的普通 Label，最多三条，文字框也是普通攻击的目标区域；不显示倾向、序号、卡片或选择按钮。

## FO-07 倒计时接口

- 候选列表可操作时调用 `FinalOracleSelectionTimer.start()`，从 10 秒开始计时。
- Sandbox 在候选显示且普通攻击目标配置成功后启动计时器，并在 `_process()` 中调用 `advance(delta, get_tree().paused)`。
- PauseMenu 暂停 `SceneTree` 时 Sandbox 不推进计时；`remaining_time_changed(seconds_remaining)` 更新既有战斗状态栏。
- 到期时发出 `expired`，由 Sandbox 执行 FO-08 自动候选选择。

## FO-08 超时自动选择接口

- 计时器 `expired` 后，调用 `select_auto_pick_from_display(display_snapshot, repeat_stats)` 从冻结展示列表选择一条候选。
- 正式排序为普通复读实际数量降序、最近命中顺序降序、稳定原句 ID 升序；空展示列表返回空 Dictionary。
- 计时器到期后 Sandbox 调用 `FinalOracleSession.select_timeout_candidate()`，从冻结展示快照和 Repeat 统计中选句，再交给 FO-09 共同确认入口。

## FO-09 单次确认接口

- 每个当前周目创建并复用一个 `FinalOracleConfirmationState.new(SaveManager.data)`。
- 手动攻击命中和超时自动选择都调用 `confirm_display_candidate(candidate)` → `confirm_selection(level_id, candidate)`；同一周目同一 `level_id` 只接受第一次有效结果。
- 首次确认发出 `confirmation_committed(run_data, level_id, candidate)`；重复调用返回 `false` 且不会重发信号。`get_confirmed_selection(level_id)` 始终返回首次候选快照。
- 本版确认不改写三项倾向累计值，额外倾向保持为 0。

## FO-13 主游戏区攻击选择

- `FinalOracleCandidateDisplay` 位于 `BattleHud/BattleArea` 内，候选控件固定排布，原句正文直接使用 Label 显示。
- Sandbox 将这些 `Control` 注入 `AttackChargeInput.set_selection_targets()`；玩家仍使用现有准心、蓄力、发射和飞行阶段。
- `AttackTargetSnapshot` 在释放时冻结命中候选 ID 和准心中心；到达时只复核仍可见的冻结目标。同发命中多句时只发出准心中心最近的一句，等距时保留展示顺序。
- 选择模式不会调用 HitResolution、PK、倾向或普通复读结算；普通弹幕生成和对手回拉在进入神谕时保持停止。
- 手动攻击命中和超时自动选择统一进入 `Sandbox._confirm_oracle_candidate()`，最终由 FO-09 的当前周目 `SaveData + level_id` 确认器防重。
- 旧 `FinalOracleScreen` Panel / Button 页面已删除；Sandbox 保留 `final_oracle_opened(session)` 作为阶段事实通知。

## Scripture 确认接收

- SC-02 已由 `run_data.scripture_data.bind_confirmation_state(confirmation_state, level_catalog)` 订阅正式确认事实；Sandbox 在创建确认状态后完成绑定。
- 当前候选仅有原句 ID 和倾向，Scripture 从注入的真实关卡目录解析原句文本、主播名和章号，保存首条经文；同关重复提交保持首条。
- Scripture 的未确认快照由 `stage_oracle()` 单独暂存；正式确认按本次候选写入并清同关暂存，重开只撤回暂存，已经确认的经文和节号保留。

## FO-10 圣典接线状态

- FO-10 没有新增接口：当前 main 已具备 `FinalOracleConfirmationState.confirmation_committed`、`ScriptureData.bind_confirmation_state()` 和 Sandbox 周目初始化绑定。
- 手动候选与超时候选都经过同一 `FinalOracleSession.confirm_display_candidate()`，首次确认触发 Scripture 写入；同关第二次确认由确认状态和 Scripture 保存列表共同拒绝。
- Scripture 写入保留原句 ID、原句文本、倾向、主播名、关卡 ID 和章号；本卡只确认接线，不改动节号、奖励或休息流程。

## FO-11 奖励接线状态（配置阻塞，任务尚未完成）

- 手动 / 自动选择仍共用现有 Session 和确认状态。`confirmation_committed` 后，Sandbox 的现有回调检查当前周目、Session 关卡、CB `BREAKTHROUGH` 与当前 LevelProfile，提交普通历史后调用 `LoserCardData.grant_on_true_defeat()` 和 `AssimilationData.register_defeated_streamer()`。
- 关卡 / 主播来源直接读取当前 `LevelProfile.level_id / streamer_id`；状态数据继续由 `SaveData.loser_card_data / assimilation_data` 拥有。首次确认广播一次，接收方沿用已有周目内关卡 / 主播去重；仅 PK 胜利未击破分支不会进入此接线。
- Sandbox 的 `loser_card_catalog` 默认读取正式 `data/loser_card/loser_card_catalog.tres`。当前目录仍为空，16 收到提交请求后按已有规则拒绝无资料卡片，正式发卡验收尚未成立。
- 14 已可登记真正击败及来源，但 `LevelProfile` 尚无词库 `pool_id`、词库继承 `appearance_weight / can_inherit / is_contradiction_pool` 和允许继承的 trait 白名单。普通话语的 appearance_weight 与本关 special_trait_ids 不能替代这些配置，所以当前只提交击败事实，词库 / 特性奖励验收尚未成立。
- 配置方补齐后，在同一确认回调中使用 14 现有词库 / 特性登记 API 提交允许继承内容，再复验正式卡片和本场新增吞并内容。FO-11 保留等待状态；本轮没有接入 FO-12。
