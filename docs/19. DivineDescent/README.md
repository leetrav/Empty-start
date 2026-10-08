# 19. DivineDescent 神降临系统任务拆分

## 系统目标

神降临系统是普通关卡全部结束后的终局演出。

进入时，它会固定整局已经提交的倾向、圣典、普通话语命中历史、复读历史和吞并成果。

终局依次经历：

1. 扩散；
2. 新话生成率逐渐降到 0；
3. 根据历史权重锁定一句话；
4. 只继续生成锁定句；
5. 锁定句占可见弹幕达到 90% 后收束；
6. 全屏强调；
7. 进入结局。

终局期间不再运行普通 PK 胜负、档位升降和矛盾击破。

当前没有正式 DivineDescent Session 或场景入口。DD-04 提供可组合的 `DivineDescentCombatMode`：`enter_terminal_mode(tier_catalog, hit_resolution, combat_stage, contradiction_break, barrage_area, opponent_pk_bar)` 读取 Tier 5 配置、应用后续弹幕表现倍率，并直接调用各系统的公开锁定入口。进入后 HitResolution 拒绝普通 PK 更新，CombatStage 固定 Tier 5 并忽略后续升降，ContradictionBreakSystem 拒绝窗口启动；矛盾生成和 PK 回拉停止，普通新话继续保持当前生成状态。

DD-05 在同一模式对象上提供 `start_new_word_decay(config)` 与 `advance_new_word_decay(delta_seconds)`：起始频率读取 Tier 5 配置，衰减时长读取 `data/divine_descent/divine_descent_decay_config.tres`，每次推进只调整 BarrageArea 的生成频率，配置时长结束后频率为 0。该对象不负责终局进入、整局结果冻结或历史候选。

TT-13 提供 `DivineDescentCandidateFilter.filter_three_tendency_history(committed_history)` 作为未来 DD-02 候选归并前的输入边界：已提交普通命中历史中的 neutral 仍保留在存档，但只将正统、异端、荒谬原句交给终局候选与锁句流程。当前神降临运行阶段尚未实现；DD-02 接入时必须复用此筛选入口，再处理归并和权重。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| DD-01 | 进入终局并冻结整局结果 | 无 |
| DD-02 | 汇总普通话语历史候选 | 1 个关键单元测试 |
| DD-03 | 读取吞并内容 | 无新增自动化测试 |
| DD-04 | 使用 Tier 5 初始表现并停用普通战斗规则 | 无 |
| DD-05 | 新话生成率逐渐降到 0 | 无 |
| DD-06 | 计算候选基础权重 | 2 个关键单元测试 |
| DD-07 | 圣典句加权且同句只加一次 | 2 个关键单元测试 |
| DD-08 | 按当前权重加权随机生成复读并动态加权 | 无 |
| DD-09 | 新话率归零后锁定最高权重句 | 1 个关键单元测试 |
| DD-10 | 锁句并列裁决 | 2 个关键单元测试 |
| DD-11 | 锁定后只继续生成目标原句 | 无 |
| DD-12 | 计算锁定句可见占比 | 2 个关键单元测试 |
| DD-13 | 达到 90% 后进入收束 | 1 个关键单元测试 |
| DD-14 | 锁句后玩家输入只强化表现 | 无 |
| DD-15 | 空历史直接进入结局空态 | 1 个关键单元测试 |
| DD-16 | 终局继承特性边界 | 无 |
| DD-17 | 全屏强调后进入结局 | 无新增自动化测试 |

## 测试预算

只保留 12 个纯逻辑 case：

- 普通命中历史按原句归并；
- 基础权重 = 普通命中数 + 实际普通复读数；
- 基础权重最低为 1；
- 圣典句得到一次“候选池最大基础权重”加成；
- 同一句即使多章也只加一次；
- 新话率归零时选择最高权重句；
- 权重并列时优先首次已提交命中更早的句子；
- 首次命中仍并列时按原句标识排序；
- 可见占比按原句归并复读变体；
- UI 装饰不进入可见占比；
- 锁定句占比达到 90% 后满足收束条件；
- 普通历史为空时直接得到结局空态。

演出时间、自动生成、画面强化、音效和场景转场全部做实际运行联调。

## 依赖顺序

DD-01 等 18. Rest、17. ThreeTendencies、15. Scripture。
DD-02 等【6. HitResolution】HR-15 的已提交普通命中历史与【10. Repeat】已提交普通复读历史。
DD-03 等 14. Assimilation。
DD-04～16 完成终局逻辑。
DD-17 等 20. Ending。

## DD-03 吞并输入接口

- 终局调用方在进入时调用 `DivineDescentAssimilationInput.build_snapshot(run_data)`，并持有返回快照。
- AS-09 已将输入接到 14 的公开只读入口 `SaveData.assimilation_data.get_current_content_snapshot()`，返回当前总 `inherited_word_weights` 与 `inherited_trait_ids`：词库 ID → 原权重的 Dictionary，以及稳定特性 ID 的 Array。
- 集合隔离由吞并系统的公开快照接口负责：词库字典使用 Godot 原生深拷贝，特性数组复制稳定 ID；后续源数据变化不会影响已取得的快照，修改快照也不会写回吞并数据。
- 没有成果时两个字段分别为明确空 Dictionary / Array；未提供周目或吞并数据时也采用同一空结构。
- 本接口只读取总量，保留缺少历史来源记录的既有成果；本场新增 / 来源归属仍归 14，没有修改 AssimilationData，也不计算候选权重、圣典加权或实际生成。

## DD-02 历史候选接口

- `DivineDescentCandidateFilter.filter_three_tendency_history(committed_history)` 是普通历史进入终局前的唯一三项倾向边界，Neutral 仍保留在存档但不会进入候选。
- `DivineDescentCandidateFilter.build_history_candidates(committed_hit_history, normal_repeat_counts_by_line_id)` 复用上述边界，按 `original_sentence_id` 归并候选，保持第一次出现的顺序。
- 候选字段为 `original_sentence_id`、`original_sentence_text`、`tendency`、`hit_count`、`normal_repeat_count` 和 `first_committed_hit_order`，供 DD-06 以后直接读取。
- `hit_count` 对同一原句的多条已提交命中快照累加；`normal_repeat_count` 独立读取 Repeat 提供的按原句统计字典，不从命中历史字段推断。

## SC-07 圣典输入接口

- `DivineDescentScriptureInput.build_snapshot(run_data)` 通过 15 的 `get_ordered_entries()` 读取已提交经文，返回 `Array[Dictionary]` 独立快照；空圣典、空周目或缺少 ScriptureData 均返回空数组。
- 每章字段为 `level_id`、`streamer_name`、`original_sentence_id`、`original_sentence_text`、`tendency`、`chapter_number`、`verse_number`。原句 ID 从 `ScriptureEntry.original_line_id` 转为 String，与 DD-02 候选的 `original_sentence_id` 一致。
- 排序、原文和固定章 / 节号由 Scripture 的正式读取接口提供；未提交暂存排除，同句多章保留，原章号不压缩。修改返回值不会写回圣典。
- DD-01 的正式进入组合以后调用并持有此快照；DD-07 使用稳定原句 ID 匹配历史候选，再执行其同句一次加权规则。本接口只提供读取依据。

## DD-06 基础权重接口

- `DivineDescentCandidateFilter.calculate_base_weights(candidates)` 接收 DD-02 输出，按原顺序返回候选深拷贝，并新增 `base_weight` 字段。
- `base_weight = max(hit_count + normal_repeat_count, 1)`；仅使用已有普通命中数和实际普通复读数，保留候选其他字段，输入历史与候选保持原值。
- 基础权重属于 DivineDescent 的派生数据；HitResolution 和 Repeat 继续拥有各自历史。圣典加成、动态权重、锁句及运行阶段接线留给后续任务。
