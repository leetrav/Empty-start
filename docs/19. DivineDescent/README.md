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

DD-01 已提供独立 `DivineDescentSession.enter(run_data)` 终局进入 / 冻结接口；当前尚无 RS-10 正式场景路由。DD-04 提供可组合的 `DivineDescentCombatMode`：`enter_terminal_mode(tier_catalog, hit_resolution, combat_stage, contradiction_break, barrage_area, opponent_pk_bar)` 读取 Tier 5 配置、应用后续弹幕表现倍率，并直接调用各系统的公开锁定入口。进入后 HitResolution 拒绝普通 PK 更新，CombatStage 固定 Tier 5 并忽略后续升降，ContradictionBreakSystem 拒绝窗口启动；矛盾生成和 PK 回拉停止，普通新话继续保持当前生成状态。

DD-05 在同一模式对象上提供 `start_new_word_decay(config)` 与 `advance_new_word_decay(delta_seconds)`：起始频率读取 Tier 5 配置，衰减时长读取 `data/divine_descent/divine_descent_decay_config.tres`，每次推进只调整 BarrageArea 的生成频率，配置时长结束后频率为 0。该对象不负责终局进入、整局结果冻结或历史候选。

TT-13 提供 `DivineDescentCandidateFilter.filter_three_tendency_history(committed_history)` 作为 DD-02 候选归并前的唯一输入边界：已提交普通命中历史中的 neutral 仍保留在存档，但只将正统、异端、荒谬原句交给终局候选。DD-01 进入时复用 DD-02 归并入口冻结候选，后续演出阶段继续等待各自任务。

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

DD-01 进入 / 冻结接口已完成；18 的 RS-10 后续在普通关卡全部完成时调用，17 / 15 等源数据继续通过已有真实接口读取。
DD-02 等【6. HitResolution】HR-15 的已提交普通命中历史与【10. Repeat】已提交普通复读历史。
DD-03 等 14. Assimilation。
DD-04～16 完成终局逻辑。
DD-17 等 20. Ending。

## DD-01 进入与唯一冻结归属

- 每次终局创建一个 `DivineDescentSession`；普通关卡完成的组合方调用 `enter(current_run_data) -> bool`。首次合法进入返回 true；重复调用、空周目或缺少倾向 Resource 返回 false，首次快照保持原值。调用前需完成本场正式结果提交，19 不替上游提交暂存。
- `is_entered()` 读取进入状态；`get_entry_snapshot()` 返回独立深拷贝，进入前返回 `{}`。会话不保留 SaveData / TendencyState / ScriptureEntry 等源 Resource 引用，也没有改变冻结结果的公开写入接口。
- 快照字段：`tendency_result`、`scripture_entries`、`committed_normal_hit_history`、`normal_repeat_counts_by_line_id`、`history_candidates`、`assimilation_content`。普通历史与 DD-02 候选分别保留来源及已归并数据；圣典 / 吞并字段沿用 SC-07 / AS-09 的结构。
- EN-01 补齐进入时的 `identity_id` 与 `streamer_name` 标量，直接复制 SaveData 已有字段；Ending 接收后仍使用进入时依据，避免后续源身份 / 姓名变化。其余历史与候选冻结规则保持原状。
- `tendency_result` 保存 `orthodox_total / heretical_total / absurd_total`、`opening_identity_tendency_id` 和 17 公开方法得到的 `primary_tendency_id / secondary_tendency_id / is_primary_tied / has_no_effective_behavior`。仅复制已提交事实，排除 `attempt_*`；并列和全零规则仍由 TendencyState 计算。
- 唯一归属约定：17 拥有倾向事实和裁决规则，19 持有本次终局不可变使用快照。TT-11 已核实后续源变化和副本修改不能改变首次事实；TT-12 已增加 20 的 `EndingDisplayData.build_from_frozen_tendency()` / `EndingIdentityResultClassifier.classify_frozen_result()`，直接读取本 Session 的 `tendency_result` 副本，沿用主次 / 并列 / 全零及开局依据。EN-01 的正式接收 / 转场仍待后续任务。
- 源存档后续写入、暂存经文变化和调用方修改返回副本均不改变内部快照。空历史仍可进入并提供明确空集合；直接跳过演出或转入 Ending 的规则留 DD-15 / DD-17。
- DD-01 只负责进入时固定数据，不在本卡接入 Sandbox、Rest UI、RS-10 路由、DD-04 运行模式、DD-05 计时或新的权重 / 演出业务。后续组合方可独立组合现有模式与会话。

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
- RP-12 已提供真实复读来源 `RepeatGenerationStats.get_committed_normal_counts_by_line_id(run_data)`，只读 RP-10 已提交普通历史并跨关按原句求和，直接作为上述候选入口第二个参数。第一参数继续通过 `run_data.get_committed_normal_hit_history()` 取得；未提交和矛盾复读排除。DD-01 的 Session 已在进入时组合这两个来源并固定结果，本接口不执行新的权重规则。

## SC-07 圣典输入接口

- `DivineDescentScriptureInput.build_snapshot(run_data)` 通过 15 的 `get_ordered_entries()` 读取已提交经文，返回 `Array[Dictionary]` 独立快照；空圣典、空周目或缺少 ScriptureData 均返回空数组。
- 每章字段为 `level_id`、`streamer_name`、`original_sentence_id`、`original_sentence_text`、`tendency`、`chapter_number`、`verse_number`。原句 ID 从 `ScriptureEntry.original_line_id` 转为 String，与 DD-02 候选的 `original_sentence_id` 一致。
- 排序、原文和固定章 / 节号由 Scripture 的正式读取接口提供；未提交暂存排除，同句多章保留，原章号不压缩。修改返回值不会写回圣典。
- DD-01 的 Session 已在正式进入接口调用并持有此快照；DD-07 使用稳定原句 ID 匹配历史候选，执行同句一次加权规则。本接口只提供读取依据。

## DD-06 基础权重接口

- `DivineDescentCandidateFilter.calculate_base_weights(candidates)` 接收 DD-02 输出，按原顺序返回候选深拷贝，并新增 `base_weight` 字段。
- `base_weight = max(hit_count + normal_repeat_count, 1)`；仅使用已有普通命中数和实际普通复读数，保留候选其他字段，输入历史与候选保持原值。
- 基础权重属于 DivineDescent 的派生数据；HitResolution 和 Repeat 继续拥有各自历史。DD-07 已提供纯圣典加成，DD-08 已提供动态权重扩散，锁句及主流程接线留给后续任务。

## DD-07 圣典候选加成

- `DivineDescentCandidateFilter.apply_scripture_bonus(base_weight_candidates, scripture_entries)` 接收 DD-06 的基础权重候选与 DD-01 冻结的 SC-07 经文，按 `original_sentence_id` 匹配，只对历史池内候选加成。
- 输出深拷贝保留原字段及 `base_weight`，新增 `weight = base_weight + 圣典加成`；加成等于本次输入候选池加成前的最大 `base_weight`，同句多章只加一次，非圣典候选 `weight = base_weight`。每次从基础值派生，不读取旧 `weight`。
- 空经文只返回基础权重；空候选返回空数组；单句圣典候选加成等于自身基础权重。圣典中池外原句不会新增候选，输入候选、经文与 Session 冻结快照保持原值。
- 保留 DD-02 的原候选顺序，不按本卡输出权重重新排序；DD-09 / DD-10 的最高权重与并列裁决留对应卡。没有改动 FO-05 的本场候选排序。
- DD-08 已组合调用：从 Session 读取 `history_candidates / scripture_entries` → `calculate_base_weights(history_candidates)` → `apply_scripture_bonus(base_candidates, scripture_entries)`。返回池作为扩散工作数据，冻结来源仍留在 Session；DD-07 本身只提供纯加成规则。

## DD-08 自动扩散组件

- `DivineDescentSpread` 是独立 Node，进入树后调用 `start(session, barrage_area, speech_catalog, interval_seconds, repeat_lifetime_seconds, display_template, random_generator = null)`。每个终局 Session 组合一个扩散组件，由它唯一持有可变 `weight` 工作池；Session 继续只持有冻结来源。
- 启动复用 DD-06 / DD-07 初始化权重。已有正文优先保留；存档候选只有原句 ID 时，按真实 `LevelCatalog.profiles` → `LevelProfile.get_normal_speech_pool()` 解析并复制正文，支持 #61 导表 Resource。空候选、缺少正文、未进入 Session 或非法时长会拒绝启动，既不补造句子也不丢弃候选。空历史路由仍留 DD-15。
- 调用方先让 BarrageArea 进入当前关卡上下文，之后可停止普通生成；扩散直接调用现有 `spawn_repeat_barrage(RepeatPlan)`。间隔、寿命与模板必须从当前真实配置显式注入，本组件没有自定策划值。现有配置组合可读取当前关基础间隔 / Tier 5 频率、运行配置的复读寿命与模板；终局专用配置后续可替换同一参数入口。
- 原生可暂停 Timer 在无玩家输入时逐次推进；每次用当前工作池调用 Godot [`RandomNumberGenerator.rand_weighted()`](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html#class-randomnumbergenerator-method-rand-weighted)，创建一条 NORMAL RepeatPlan。只有 BarrageArea 返回真实生成实例后，该原句 `weight +1` 并发出 `repeat_generated(original_sentence_id, view, current_weight)`，下一轮读取新值。
- `generate_next_repeat()` 是一次生成公开命令，返回成功实例或 null；容量 / 位置不足返回 null，权重保持原值，Timer 下一轮重试，不建立积压队列。`is_generation_blocked()` 读取上次尝试是否失败，成功后清除；区域离树时停止。生成实例、位置、同屏容量和寿命继续由 3 持有。
- 不订阅攻击、复读命中或移除事件，命中不会触发扩散。NORMAL 复读继续走既有零收益命中规则；正式终局组合沿用 DD-04 的普通战斗关闭接口，本卡没有复制命中规则。
- `get_current_candidates()` 返回动态工作池深拷贝，保留原句 ID、正文、倾向、命中 / 复读统计、首次提交顺序、基础权重和当前权重，供 DD-09 读取；修改副本不会回写。`stop()` 停止计时并保留工作池，`is_running()` 读取真实 Timer 状态；同一个组件启动后不重新初始化权重。
- 当前仅在独立最小场景验证本组件，没有接入 RS-10 / Sandbox / Rest / Ending，没有执行 DD-09 锁句或后续演出。

## DD-09 新话归零后锁最高动态权重句

- `DivineDescentSpread.bind_new_word_decay(combat_mode)` 订阅 DD-05 的真实 `new_word_rate_changed`，可以在扩散启动前或启动后调用；已完成衰减的晚绑定也会立即检查当前池。重复绑定同一模式不重复订阅，另一个模式不会替换本次来源。
- 锁句同时要求 DD-05 的衰减完成且 `get_new_word_rate_multiplier() == 0.0`；未开始、尚有正新话率（包括极小正数）时保持未锁。归零后停止 DD-08 自动扩散，从其当前 `weight` 池选最高句，保存首次独立快照并只发一次 `sentence_locked(candidate)`。
- `get_locked_candidate()` 返回深拷贝，`is_sentence_locked()` 读取锁态；通知副本与读取副本均不能回写。`bind_new_word_decay()` / `start()` 可能同步锁句，组合方应先订阅通知；晚订阅可通过 getter 读取首次结果。锁句与动态池仍归扩散组件，Session 和已提交历史继续保持冻结。
- `DivineDescentCandidateFilter.select_highest_weight_candidate(candidates)` 是本卡纯最高权重选择接口，只比较当前 `weight`；并列暂保留输入顺序首个最高项，未实现 DD-10 的首次提交命中顺序 / ID 裁决。空候选返回 `{}`，不补造锁句。
- 本卡没有实现 DD-11 的锁定句持续生成或待生成内容清理，没有提前结束已有弹幕生命周期。真实场景组合仍由后续任务接入，当前使用最小真实 DD-05 / DD-08 场景验收。
