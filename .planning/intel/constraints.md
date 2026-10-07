## AGENTS.md
- source: AGENTS.md
- type: protocol
- content:
  ~~~~text
  DATA_0QY8JA2V_START
  本文件只保存整个仓库长期有效、跨任务都成立的项目规则。

  1. 当前能够运行的代码和实际运行结果；

  2. `project.godot`、Scene、Resource 和其他当前工程配置；

  3. 当前系统对应的正式文档；

  4. `docs/Original/` 中保存的原始需求；

  所有顶层场景切换统一由 `SceneRouter` 负责。
  DATA_0QY8JA2V_END
  ~~~~

## 1. Identify 身份系统任务拆分
- source: docs/1. Identify/README.md
- type: schema
- content:
  ~~~~text
  DATA_O6HQ442U_START
  身份系统负责本周目的三件基础信息：

  - `IdentityOption` 是可编辑的 Godot `Resource`，包含稳定身份 ID、显示名称、`Texture2D` 图标引用和倾向 ID。

  - `data/identity/` 提供三份占位资源。正式身份名称和图标素材尚未进入仓库，资源中的图标目前为空，待正式内容到位后替换。

  - `IdentityConfirmationState` 首次只接受调用方从当前身份资源整理出的有效 ID，之后拒绝覆盖；运行持有者通过 `get_confirmed_identity_id()` 读取结果。

  - `SaveData.streamer_name`、`SaveData.fan_group_name` 与 `SaveData.identity_id` 保存本周目确认结果；新周目初始化为空值，确认后由 `SaveManager.set_identity_data()` 一次写入。
  DATA_O6HQ442U_END
  ~~~~

## 1. Identify 身份系统任务拆分 / 测试预算
- source: docs/1. Identify/README.md
- type: nfr
- content:
  ~~~~text
  DATA_CX18L13Y_START
  身份系统只给容易被以后改坏、同时可以快速运行的纯逻辑写单元测试：
  - 空白主播名和粉丝团名会分别回退到各自默认名字；
  - 正常主播名和粉丝团名会保留玩家输入；
  - 第一次身份确认会成功；
  DATA_CX18L13Y_END
  ~~~~

## 10. Repeat 复读系统任务拆分
- source: docs/10. Repeat/README.md
- type: schema
- content:
  ~~~~text
  DATA_DCK3Q2HD_START
  复读系统负责把“某句话被打中以后，大家跟着重复”变成可执行的数据和生成请求。

  - `RepeatPlan` 是可序列化的复读计划 Resource，字段包括原句 ID / 文本、原句内容类别、模板显示文本、普通或矛盾类型、已确定数量、生成档位、寿命和逐条等待偏移；`wait_offsets_seconds` 每项对应一个待复读条目的计划等待时间。

  - `RepeatPlan.create_normal_hit_plan(...)` 在普通命中时创建计划，并把原句、内容类别、结算后档位、调用方已解析的复读数量和寿命复制为固定值。neutral 普通话语的复读仍保留 `neutral` 类别。CS-08 已提供 `CombatStage.get_current_repeat_count_per_hit()`；命中结算完成并更新 Tier 后，普通复读计划创建方读取当前档位和数量并传入工厂，由 RepeatPlan 固定保存本次计划值。延迟队列与生成统计仍分别由 `RepeatDelayQueue` 和 `RepeatGenerationStats` 拥有。

  - `RepeatDelayQueue.new(maximum_pending_normal_count)` 接收调用方已解析的普通待生成容量；`enqueue_plan(plan)` 只保留剩余容量内的请求并直接丢弃溢出，返回实际接受数量。

  - `RepeatDelayQueue.advance(delta_seconds)` 返回到期单条请求；`advance_and_dispatch(delta_seconds, barrage_area)` 则直接调用 3. BarrageGeneration 的 `spawn_repeat_barrage(plan)`。弹幕成功出现后，队列将 1 条实际生成数记入自己持有的 `RepeatGenerationStats`；复读屏幕容量暂满时保留到期请求，等容量释放后重试。待生成队列容量独立于 3. BarrageGeneration 的屏幕弹幕容量。

  - `RepeatGenerationStats.record_generated(plan, actual_generated_count)` 仅根据计划类型把弹幕生成系统确认的实际生成数量按 `original_line_id` 累计；`get_normal_count(id)` 与 `get_contradiction_count(id)` 分别读取两类统计。
  DATA_DCK3Q2HD_END
  ~~~~

## 10. Repeat 复读系统任务拆分 / 测试预算
- source: docs/10. Repeat/README.md
- type: nfr
- content:
  ~~~~text
  DATA_69U7RH4J_START
  只保留 8 个纯逻辑 case：
  - 普通命中创建计划时会固定生成数量；
  - 普通命中创建计划时会固定结算后档位；
  - 普通复读到达上限时溢出部分被丢弃；
  DATA_69U7RH4J_END
  ~~~~

## 12. ContradictionBreak 矛盾击破系统任务拆分
- source: docs/12. ContradictionBreak/README.md
- type: protocol
- content:
  ~~~~text
  DATA_NH98YALL_START
  矛盾击破系统负责普通 PK 条打满后的特殊阶段。
  DATA_NH98YALL_END
  ~~~~

## 12. ContradictionBreak 矛盾击破系统任务拆分 / 测试预算
- source: docs/12. ContradictionBreak/README.md
- type: nfr
- content:
  ~~~~text
  DATA_2KCCGB2J_START
  只保留 9 个核心 case：
  - 已蓄满实际发射才消耗一次发射机会；
  - 未蓄满取消不消耗机会；
  - 一发含真矛盾 → 成功；
  DATA_2KCCGB2J_END
  ~~~~

## 13. FinalOracle 终结神谕系统任务拆分
- source: docs/13. FinalOracle/README.md
- type: api-contract
- content:
  ~~~~text
  DATA_1VFL5CMO_START
  终结神谕系统只在矛盾击破成功后出现。

  矛盾文本、复读文本和 neutral 普通闲聊都不进入候选；neutral 仍可保存在普通命中历史中。

  - `FinalOracleCandidatePool.select_most_repeated_per_tendency(candidates, repeat_stats)` 对正统、异端、荒谬分别选择普通复读实际生成数最高的一句。

  - 复读数相同时优先最近命中更晚的句子；最近命中顺序仍并列时按稳定原句 ID 升序裁决。

  - 手动选择和超时自动选择都调用 `confirm_selection(level_id, candidate)`；同一周目同一 `level_id` 只接受第一次有效结果。

  - 本版确认不改写三项倾向累计值，额外倾向保持为 0。
  DATA_1VFL5CMO_END
  ~~~~

## 13. FinalOracle 终结神谕系统任务拆分 / 测试预算
- source: docs/13. FinalOracle/README.md
- type: nfr
- content:
  ~~~~text
  DATA_8B19SY7B_START
  只保留 8 个纯逻辑 case：
  - 同一原句多次命中后候选池只保留一条；
  - 矛盾与复读文本不进入候选池；
  - 每种倾向优先选普通复读最多的一句；
  DATA_8B19SY7B_END
  ~~~~

## 14. Assimilation 吞并系统任务拆分
- source: docs/14. Assimilation/README.md
- type: schema
- content:
  ~~~~text
  DATA_PPD493MD_START
  吞并系统负责保存“真正击败对手以后，玩家从对方那里带走了什么”。

  - `register_inherited_word_pool(level_id, pool_id, appearance_weight, can_inherit, is_contradiction_pool)` 只允许已登记真正击败关卡的可继承普通词库；稳定 pool_id 只保存首次权重，矛盾专属池和禁止继承的池被排除。

  - 当前 `LevelProfile` 尚无稳定 pool_id、继承权重及允许继承标记；以上 API 接收配置方显式提供的值，配置与实际生成接线留 AS-06 / FO-11。`special_trait_ids` 表示本关所用特性，不能直接当作继承白名单。
  DATA_PPD493MD_END
  ~~~~

## 14. Assimilation 吞并系统任务拆分 / 测试预算
- source: docs/14. Assimilation/README.md
- type: nfr
- content:
  ~~~~text
  DATA_CPWNT9ZO_START
  只保留 7 个纯逻辑 case：
  - 同一主播第一次真正击败可以登记；
  - 同一主播重复登记不会重复；
  - 新词库可以登记；
  DATA_CPWNT9ZO_END
  ~~~~

## 15. Scripture 圣典系统任务拆分
- source: docs/15. Scripture/README.md
- type: schema
- content:
  ~~~~text
  DATA_26OOV47G_START
  圣典系统保存玩家每关最终确认的神谕句子。

  - `ScriptureEntry` Resource 保存 `level_id`、`streamer_name`、`original_line_id`、`original_line_text`、`tendency_id`、`chapter_number` 和 `verse_number`。

  - `ScriptureData.entries` 持有当前周目的经文记录；数据由 `SaveData.scripture_data` 保存并随当前周目读写。

  - `write_confirmed_oracle(level_profile, candidate)` 将首次正式确认写入 `entries`，同周目同关后续提交保持首条记录；去重直接查询保存列表，重建确认状态或读档后仍生效。

  - `get_chapter_slots(level_catalog)` 为真实目录中的每关返回 `{level_id, chapter_number, entry}`；无经文时 `entry = null`。缺章参与排序，原章号不压缩；全空圣典仍返回目录中的全部空章，章节视图即时生成且不写回保存列表。
  DATA_26OOV47G_END
  ~~~~

## 15. Scripture 圣典系统任务拆分 / 测试预算
- source: docs/15. Scripture/README.md
- type: nfr
- content:
  ~~~~text
  DATA_RWUYB71D_START
  只保留 7 个纯逻辑 case：
  - 同一关第一次可以写入一条经文；
  - 同一关第二次不会再新增；
  - 首次写入会生成节号；
  DATA_RWUYB71D_END
  ~~~~

## 16. LoserCard 败者卡系统任务拆分
- source: docs/16. LoserCard/README.md
- type: schema
- content:
  ~~~~text
  DATA_X48YEBJD_START
  败者卡系统负责记录本周目真正击败过哪些主播。

  - `LoserCardProfile` Resource 以稳定 `streamer_id` 标识主播，提供 `streamer_name`、`card_art` 和 `card_text` 展示入口。

  - `LoserCardCatalog` 保存资料列表，并通过 `find_profile(streamer_id)` 查找卡片。

  只有“矛盾击破成功 + 终结神谕确认完成”后才发卡。只赢下 PK 不发新卡。

  - `LoserCardData` Resource 保存周目获卡主播 ID 和已发卡关卡 ID；`grant_on_true_defeat(level_id, streamer_id, contradiction_broken, oracle_confirmed, catalog)` 同时要求 CB 击破成功和同关 FinalOracle 正式确认，并通过 Catalog 查到对应资料。同场重复不发，资料缺失不合成卡片。
  DATA_X48YEBJD_END
  ~~~~

## 16. LoserCard 败者卡系统任务拆分 / 测试预算
- source: docs/16. LoserCard/README.md
- type: nfr
- content:
  ~~~~text
  DATA_QXP957PG_START
  只保留 5 个纯逻辑 case：
  - 真正击败后可以获得对应卡片；
  - 非真正击败结果不满足发卡条件；
  - 同主播重复发卡只保留一张；
  DATA_QXP957PG_END
  ~~~~

## 17. ThreeTendencies 三项倾向系统任务拆分
- source: docs/17. ThreeTendencies/README.md
- type: schema
- content:
  ~~~~text
  DATA_8ZM7SVE3_START
  三项倾向系统负责记录玩家一路更偏向正统、异端还是荒谬。

  - `get_primary_tendency_id()` 返回主导倾向 ID；最高值并列时优先并列项中的 `opening_identity_tendency_id`，否则按正统、异端、荒谬顺序裁决。`is_primary_tied()` 即时计算并列标记。

  - `has_no_effective_behavior()` 在三项值全零时返回 `true`，主导和次要都沿用 `opening_identity_tendency_id`。

  - TT-13 的 `neutral` 是普通话语内容类别，不是第四项玩家倾向。命中 neutral 仍有普通 PK、历史、复读和直播表现，`tendency_delta = 0`，所以本场与周目三项值不变；只命中 neutral 时 `has_no_effective_behavior()` 仍为 `true`。开局身份、主导、次要和并列裁决仍只使用原三项。
  DATA_8ZM7SVE3_END
  ~~~~

## 17. ThreeTendencies 三项倾向系统任务拆分 / 测试预算
- source: docs/17. ThreeTendencies/README.md
- type: nfr
- content:
  ~~~~text
  DATA_LIFKNAWU_START
  只保留 9 个纯逻辑 case：
  - PK 胜利会把本场倾向提交到累计值；
  - 失败重开撤回本场未提交倾向；
  - 单一最高值得到主导倾向；
  DATA_LIFKNAWU_END
  ~~~~

## 18. Rest 休息时刻系统任务拆分
- source: docs/18. Rest/README.md
- type: protocol
- content:
  ~~~~text
  DATA_AMACYIQ7_START
  休息时刻系统负责一场直播结束后的结算与过渡。
  DATA_AMACYIQ7_END
  ~~~~

## 18. Rest 休息时刻系统任务拆分 / 测试预算
- source: docs/18. Rest/README.md
- type: nfr
- content:
  ~~~~text
  DATA_YMRUTASZ_START
  只保留 3 个关键纯逻辑 case：
  - 同一份结算重复打开不会再次提交奖励；
  - 还有普通关时选择下一关；
  - 普通关全部结束时选择神降临。
  DATA_YMRUTASZ_END
  ~~~~

## 19. DivineDescent 神降临系统任务拆分
- source: docs/19. DivineDescent/README.md
- type: protocol
- content:
  ~~~~text
  DATA_ERSRFYSM_START
  神降临系统是普通关卡全部结束后的终局演出。
  DATA_ERSRFYSM_END
  ~~~~

## 19. DivineDescent 神降临系统任务拆分 / 测试预算
- source: docs/19. DivineDescent/README.md
- type: nfr
- content:
  ~~~~text
  DATA_AUH26P8D_START
  只保留 12 个纯逻辑 case：
  - 普通命中历史按原句归并；
  - 基础权重 = 普通命中数 + 实际普通复读数；
  - 基础权重最低为 1；
  DATA_AUH26P8D_END
  ~~~~

## 2. LevelConfiguration 关卡配置系统任务拆分
- source: docs/2. LevelConfiguration/README.md
- type: schema
- content:
  ~~~~text
  DATA_NPC5VN2G_START
  关卡配置系统负责回答三类问题：

  - `LevelProfile`、`LevelCatalog`、`LevelRunState` 已实现，`data/level_configuration/` 提供可编辑的示例关卡。

  普通话语比例字段为 `orthodox_ratio`、`heretical_ratio`、`absurd_ratio`、`neutral_ratio`，类型均为浮点数；`neutral_ratio` 默认 0，旧关卡保持原生成结果。本数据类型只保存比例，不负责抽取、归一化或玩家倾向累计；具体内容与比例由策划填写。

  `LevelRunState.complete_level(level_id)` 只接受当前关的首次完成：存在更大的 `level_order` 时返回 `ADVANCED` 并推进；重复提交返回 `ALREADY_COMPLETED`；最后一关返回 `ALL_NORMAL_LEVELS_COMPLETED`，`is_all_normal_levels_completed()` 同时报告结束状态。空白或未知 ID 返回 `INVALID_LEVEL`，已知但非当前关返回 `LEVEL_NOT_CURRENT`。
  DATA_NPC5VN2G_END
  ~~~~

## 2. LevelConfiguration 关卡配置系统任务拆分 / 测试预算
- source: docs/2. LevelConfiguration/README.md
- type: nfr
- content:
  ~~~~text
  DATA_N58RIK4P_START
  本系统只给“关卡推进状态”写单元测试，因为这里一旦出错会直接造成跳关、重复结算或进不了终局。
  - 默认读取第一关；
  - 切换当前关后读取正确关卡；
  - 一关第一次完成会推进；
  DATA_N58RIK4P_END
  ~~~~

## 20. Ending 结局系统任务拆分
- source: docs/20. Ending/README.md
- type: protocol
- content:
  ~~~~text
  DATA_9WDCEDGW_START
  结局系统负责把整局已经固定的结果组合成最终页面。
  DATA_9WDCEDGW_END
  ~~~~

## 20. Ending 结局系统任务拆分 / 测试预算
- source: docs/20. Ending/README.md
- type: nfr
- content:
  ~~~~text
  DATA_QP7UTZD2_START
  只保留 9 个关键纯逻辑 case：
  - 一个纯倾向组合能得到对应教名；
  - 两个不同混合组合能得到各自不同配置教名；
  - 无有效行为 → 无行为类；
  DATA_QP7UTZD2_END
  ~~~~

## 3. BarrageGeneration 弹幕生成系统任务拆分
- source: docs/3. BarrageGeneration/README.md
- type: protocol
- content:
  ~~~~text
  DATA_1IN73NSB_START
  弹幕生成系统负责把“这一关允许出现的内容”真正变成场上的弹幕，并管理这些弹幕从出现到消失的生命周期。

  `BarrageArea.start_contradiction_generation(level_profile, true_lines, false_lines, config)` 停止普通生成，轮换两组矛盾原句，按 Paradox 配置使用每批数量 ×2、生成频率 ×3、移动速度 ×2.5，以及 10 秒实例寿命，不沿用当前普通 Tier 倍率。每个实例保留稳定 `original_sentence_id` 和 `is_contradiction` 标识；真伪由 12 系统按照关卡列表判断，不在弹幕系统结算。`stop_contradiction_generation()` 只停止新批次，`clear_barrages()` 清理场上内容并同时停止两种生成模式。

  `end_barrage(target_instance_id: int) -> bool` 只结束当前区域中的目标，立即离树释放容量，随后排队释放节点。Sandbox 根据最终 `BarrageTraitResult` 决定是否调用：仅遮挡未命中结果保留，正常、假牌、反击复制品及反弹结果都结束。移除与正常收益分别判断。无效、其他区域或已经结束的目标返回 `false`。
  DATA_1IN73NSB_END
  ~~~~

## 3. BarrageGeneration 弹幕生成系统任务拆分 / 测试预算
- source: docs/3. BarrageGeneration/README.md
- type: nfr
- content:
  ~~~~text
  DATA_1118Z5WO_START
  本系统只给两个高风险边界写少量单元测试：
  - 已经生成的弹幕，到期时间在档位变化后保持不变；
  - 档位变化后新生成的弹幕使用新的寿命配置。
  - 普通话语和陷阱共同占用普通弹幕上限；
  DATA_1118Z5WO_END
  ~~~~

## 4. BarrageTraits 弹幕特性模块系统任务拆分
- source: docs/4. BarrageTraits/README.md
- type: protocol
- content:
  ~~~~text
  DATA_FHRBOTE5_START
  弹幕特性模块系统负责给弹幕追加特殊规则。
  DATA_FHRBOTE5_END
  ~~~~

## 4. BarrageTraits 弹幕特性模块系统任务拆分 / 测试预算
- source: docs/4. BarrageTraits/README.md
- type: nfr
- content:
  ~~~~text
  DATA_2EPSKWOW_START
  本系统只给两类纯规则写单元测试。
  - 同时存在反弹和遮挡时取反弹；
  - 没有反弹、有遮挡时取遮挡；
  - 都没有时使用基础类型。
  DATA_2EPSKWOW_END
  ~~~~

## 5. CombatAttack 战斗攻击系统任务拆分
- source: docs/5. CombatAttack/README.md
- type: api-contract
- content:
  ~~~~text
  DATA_G8QM20BN_START
  战斗攻击系统负责玩家从“移动准心”到“一发攻击完成”的过程。

  - `reticle_diameter` 是准心局部设计坐标中的直径；INT-01 将 `AimReticle` 放在 `BattleHud` 内，与弹幕统一继承 1920×1080 舞台缩放。默认 32 设计像素在 1152×648 窗口显示为 19.2 像素。

  矛盾阶段由 Sandbox 调用 `set_contradiction_mode(true)`；满蓄释放的 `shot_snapshot_created` 携带当帧冻结的矛盾原句事实，由 12 系统立即判定并消耗机会。飞行计时只保留演出，不再复核目标或发送到达结算；结果锁定后 `lock_new_attacks()` 禁止下一发而保留当前飞行。进入 Rest / FinalOracle 时停止攻击；重开普通战斗时调用 `set_contradiction_mode(false)`。
  DATA_G8QM20BN_END
  ~~~~

## 5. CombatAttack 战斗攻击系统任务拆分 / 测试预算
- source: docs/5. CombatAttack/README.md
- type: nfr
- content:
  ~~~~text
  DATA_GIDEWXIL_START
  只保留 7 个纯逻辑 case：
  - 相交时可选；
  - 边缘接触也算相交；
  - 没有目标仍可蓄力；
  DATA_GIDEWXIL_END
  ~~~~

## 6. HitResolution 命中结算系统任务拆分
- source: docs/6. HitResolution/README.md
- type: api-contract
- content:
  ~~~~text
  DATA_NO0C9OER_START
  命中结算系统是普通战斗的统一结算中心。

  HR-01 由 `core/combat/hit_resolution.gd` 持有本场唯一玩家 PK，脚本为场景解耦的 `RefCounted` 对象。创建对象时传入本场初始 PK、下限和上限；重开时可调用 `initialize_player_pk()` 重置。`apply_player_pk_delta()` 统一修改并限制 PK，`get_player_pk()` 提供只读值。

  HR-02 的 `calculate_normal_word_reward(strength, tendency_id)` 按内容强度返回 `pk_delta` 和 `tendency_delta`，不修改当前 PK，也不提交三项倾向。PK 奖励从百分比换算为内部 0–1 比例：强度 1 为 `0.0012 / +1`，强度 2 为 `0.002 / +5`，强度 3 为 `0.005 / +10`；普通 `neutral` 命中保留对应强度的 PK 收益，但倾向增量固定为 0。Tier 不参与该接口。

  HR-15 由 `HitResolution.commit_normal_hit_history(SaveData)` 在最终 PK 胜利结果提交本场普通命中一次。`SaveData.committed_normal_hit_history` 按原句累计次数，用 `first_committed_hit_order` 保存第一次正式提交的跨关顺序；再次命中旧句不改变该顺序。失败或手动重开调用 `discard_uncommitted_normal_hit_history()` 丢弃本场暂存，之前已提交的周目历史保持不变。读取方使用 `SaveData.get_committed_normal_hit_history()` 的深拷贝。
  DATA_NO0C9OER_END
  ~~~~

## 6. HitResolution 命中结算系统任务拆分 / 测试预算
- source: docs/6. HitResolution/README.md
- type: nfr
- content:
  ~~~~text
  DATA_1U4YWN80_START
  只保留 11 个核心 case：
  - PK 低于下限会被限制；
  - PK 高于上限会被限制；
  - 多目标同发只做一次最终 PK 更新；
  DATA_1U4YWN80_END
  ~~~~

## 7. OpponentPKBar 对手 PK 条系统任务拆分
- source: docs/7. OpponentPKBar/README.md
- type: api-contract
- content:
  ~~~~text
  DATA_IXFTK3I4_START
  对手 PK 条系统负责“对手一直把玩家 PK 往回拉”和“玩家 PK 归零后的失败流程”。

  唯一 PK 值仍由【6. HitResolution】维护。

  OP-09 由 OpponentPKBar 记录本关连败：`record_current_level_failure()` 加一，`complete_current_level()` 与 `start_new_run()` 均归零。连败只作为记录，不改变难度参数。
  DATA_IXFTK3I4_END
  ~~~~

## 7. OpponentPKBar 对手 PK 条系统任务拆分 / 测试预算
- source: docs/7. OpponentPKBar/README.md
- type: nfr
- content:
  ~~~~text
  DATA_C6BHCSTO_START
  只保留 6 个纯逻辑 case：
  - 正时间间隔按速度计算回拉；
  - 零时间间隔回拉为零；
  - PK 到零触发失败；
  DATA_C6BHCSTO_END
  ~~~~

## 8. CombatStage 战斗阶段系统任务拆分
- source: docs/8. CombatStage/README.md
- type: schema
- content:
  ~~~~text
  DATA_EVUDYSVT_START
  INT-01 已在正式 Sandbox 完成 HitResolution、BarrageArea、OpponentPKBar 和 AudioManager 的绑定，开局调用 `begin_combat()`。每次最终 PK 更新先同步档位，再由攻击提交回调读取档位创建复读计划；生成倍率只影响新弹幕。Tier 状态已连接可见反馈，Viewer / Like 的档位数值规则仍待配置。PK 满值目前由 Sandbox 停止普通战斗并显示矛盾击破等待提示。

  TT-14 在 `CombatStageTierConfig` 增加 `neutral_weight_multiplier`（默认 1.0）；正式 Tier 0～5 分别为 `1.00 / 0.99 / 0.70 / 0.40 / 0.15 / 0.00`。CombatStage 随当前 Tier 通过 `neutral_weight_multiplier_changed` 把该倍率交给 BarrageArea，绑定时也补发。它只改变后续普通话语类别抽取，不改动静态关卡比例或已有弹幕。

  CS-08 提供 `get_current_repeat_count_per_hit()`，返回当前 Tier 配置的 `repeat_count_per_hit`。命中结算完成并更新 Tier 后，普通复读计划创建方读取该数量与 `get_current_tier()`，传给 `RepeatPlan.create_normal_hit_plan()`；RepeatPlan 在创建时保存固定数量和结算档位。CombatStage 不缓存复读计划，也不拥有复读统计。
  DATA_EVUDYSVT_END
  ~~~~

## 8. CombatStage 战斗阶段系统任务拆分 / 测试预算
- source: docs/8. CombatStage/README.md
- type: nfr
- content:
  ~~~~text
  DATA_SP7WUB3T_START
  只保留 5 个纯逻辑 case：
  - 到达升档阈值会升档；
  - 低于降档阈值会降档；
  - 一次 PK 上升可以跨多档；
  DATA_SP7WUB3T_END
  ~~~~

## 9. LiveDataPresentation 直播数据表现系统任务拆分
- source: docs/9. LiveDataPresentation/README.md
- type: schema
- content:
  ~~~~text
  DATA_BMO01S19_START
  直播数据表现系统只负责把直播间表现做得像“真的在涨热度”。

  - `LiveSessionData` 是直播数据系统唯一持有的四项数据 Resource，字段为 `viewer_count`、`like_count`、`comment_count` 和 `fan_count`。

  - `LiveSessionData.initialize_session(initial_fan_count)` 清空本场观看、点赞、评论，并设置本周目当前粉丝数；新周目默认粉丝数为 0，正式起始粉丝值待策划配置。

  - `LiveSessionData.record_generated_comments(actual_generated_count)` 只累计弹幕系统确认成功生成的实例数量。INT-01 Sandbox 统一监听 `BarrageArea.barrage_generated(view)`，普通与复读每个成功实例传 1；队列返回数量不再重复计评论。

  - 这些值只供表现和展示读取，不作为 PK、倾向或关卡解锁输入。
  DATA_BMO01S19_END
  ~~~~

## 9. LiveDataPresentation 直播数据表现系统任务拆分 / 测试预算
- source: docs/9. LiveDataPresentation/README.md
- type: nfr
- content:
  ~~~~text
  DATA_HWBSXIOV_START
  只保留 6 个纯逻辑 case：
  - 开播人数按粉丝数与倍率计算；
  - 开播人数不会小于 0；
  - 同一场 PK 胜利第一次可以结算粉丝；
  DATA_HWBSXIOV_END
  ~~~~

## Audio 共用音频接入
- source: docs/Shared/Audio/README.md
- type: api-contract
- content:
  ~~~~text
  DATA_TR74CWS5_START
  ## 当前底座

  - 玩法系统通过 `AudioManager.play_event(&"attack_fire")` 播放；管理器按事件类型复用现有 Music 播放器或 SFX / UI 播放池。

  - 当前稳定事件 ID 包含 `attack_charge`、`attack_ready`、`attack_fire`、`hit_normal`、`hit_trap`、`tier_up`、`contradiction_start`、`contradiction_break`、`oracle_confirm`、`divine_descent_start` 和 `divine_descent_lock`。

  音乐还需要支持阶段切换时的淡入淡出、交叉切换、临时压低和静音过渡。
  DATA_TR74CWS5_END
  ~~~~

## Shared Debug
- source: docs/Shared/Debug/README.md
- type: protocol
- content:
  ~~~~text
  DATA_MTP7UWYF_START
  这里记录仅供开发和验收使用的游戏内调试能力，不占用玩法系统编号。

  Sandbox 中按 F3 打开或关闭 DEBUG 面板。面板置于普通 HUD 和 PauseMenu 上层，打开时不暂停游戏。

  面板状态由场景组合方即时读取 `LevelRunState`、`HitResolution`、`CombatStage`、`AttackChargeInput`、`BarrageArea`、`LiveSessionData` 和 `TendencyState`。UI 不保存第二份可写玩法状态。

  调试操作通过拥有者公开方法执行：PK 仍经 HitResolution 的最终 PK 信号联动 Tier/HUD；直播计数写入当前 `LiveSessionData`；倾向只设置本关暂存；弹幕操作复用 BarrageArea 与 RepeatDelayQueue 的现有生成和清理状态。正式玩法不依赖 DEBUG 面板。
  DATA_MTP7UWYF_END
  ~~~~

## PresentationAssets 表现资产接入
- source: docs/Shared/PresentationAssets/README.md
- type: schema
- content:
  ~~~~text
  DATA_34894Q44_START
  让程序可以稳定接入美术正式资源，同时保持占位素材和正式素材可以直接替换。

  共享表现配置为 `data/shared/presentation_asset_config.tres`，保存跨场景共用的 UI Theme 和玩家主角外观引用。需要显式读取共享资源时使用 `PresentationAssetConfig` 对应字段；项目级默认主题仍由 `project.godot` 的 `[gui] theme/custom` 应用。

  - 占位资源和正式资源使用同一个字段；美术交付后替换该字段对应的 Godot Resource。

  - 不创建 AssetManager 或额外查找服务；需要时通过系统 Resource 字段或显式加载共享配置取得资源。
  DATA_34894Q44_END
  ~~~~

## Shared 共用任务
- source: docs/Shared/README.md
- type: protocol
- content:
  ~~~~text
  DATA_QDKFOJED_START
  这里保存多个系统共同使用、又不属于某一个玩法系统的横向任务。

  当前Sandbox的共享设计规格保存在`StageLayoutProfile`，实际设计Rect保存在`scenes/sandbox/sandbox.tscn`。基准 `1920×1080` 下，左右为 `448×1080`：信息区 `448×128`、立绘区 `448×432`、直播数据区 `448×520`。中央由顶部状态 `1024×72`、BarrageArea `(448,72,1024,760)` 和底部交互 `1024×248` 接续填满。运行时HUD仅整体缩放；尺寸变更时同步更新资源规格与SceneRect。
  DATA_QDKFOJED_END
  ~~~~
