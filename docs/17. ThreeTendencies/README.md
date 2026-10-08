# 17. ThreeTendencies 三项倾向系统任务拆分

## 系统目标

三项倾向系统负责记录玩家一路更偏向正统、异端还是荒谬。

它只接收普通话语产生的倾向变化，精确数值保持隐藏。

## 当前数据底座

- `TendencyState` 保存 `orthodox_total`、`heretical_total`、`absurd_total` 三个精确累计值和 `opening_identity_tendency_id` 比较参照。
- `attempt_orthodox_total`、`attempt_heretical_total`、`attempt_absurd_total` 保存当前关尚未提交的普通话语倾向；`record_normal_speech_tendency(tendency_id, tendency_delta)` 按稳定倾向 ID 只增加对应暂存值，不改周目累计值。
- 当前关失败时调用 `rollback_attempt_tendency()` 清空三个本场暂存，不修改此前已提交总值。
- 本关 PK 胜利的最终结果形成时调用 `commit_attempt_tendency()`，把三个本场暂存分别加到周目累计并清空暂存；重复结果不会重复累计。12 系统的未击破休息入口与成功后神谕确认事件均已接入。退出 Sandbox 时仍回滚未提交的本场暂存。
- DBG-01 的 `set_attempt_tendencies_for_debug(orthodox, heretical, absurd)` 只设置当前关暂存值并将负数限制为0，调试面板不改动已提交的周目累计。
- 当前周目通过 `SaveData.tendency_state` 持有此 Resource。
- 身份确认时调用 `initialize_from_identity_option(identity_option)`，从已选 `IdentityOption.tendency_id` 复制开局比较参照，并将累计值与本场暂存都初始化为 0。
- `get_primary_tendency_id()` 返回主导倾向 ID；最高值并列时优先并列项中的 `opening_identity_tendency_id`，否则按正统、异端、荒谬顺序裁决。`is_primary_tied()` 即时计算并列标记。
- `get_secondary_tendency_id()` 从剩余两项选择最高正分项，剩余项并列沿用相同裁决顺序；剩余项都没有正分时返回主导倾向。
- `has_no_effective_behavior()` 在三项值全零时返回 `true`，主导和次要都沿用 `opening_identity_tendency_id`。
- TT-13 的 `neutral` 是普通话语内容类别，不是第四项玩家倾向。命中 neutral 仍有普通 PK、历史、复读和直播表现，`tendency_delta = 0`，所以本场与周目三项值不变；只命中 neutral 时 `has_no_effective_behavior()` 仍为 `true`。开局身份、主导、次要和并列裁决仍只使用原三项。
- TT-14 让 Neutral 的生成类别权重随当前战斗 Tier 衰减：有效权重为关卡 `neutral_ratio × CombatStageTierConfig.neutral_weight_multiplier`。Tier 0～5 的倍率为 `1.00 / 0.99 / 0.70 / 0.40 / 0.15 / 0.00`；仅影响新生成话语，不改变已在场弹幕或 TT-13 的命中、倾向及候选过滤规则。
- INT-01 Sandbox 已把 HitResolution 整发逐目标结果中的 `tendency_id` / `tendency_delta` 交给 `record_normal_speech_tendency()`；复读和遮挡等结果跳过普通倾向。失败、重开及离开验收场调用 `rollback_attempt_tendency()`，此前周目累计保持原值。PK 满值后进入矛盾阶段，本场普通倾向在最终未击破休息或神谕正式确认时提交。精确值继续隐藏，仅由调试和验收读取。

本系统需要：

1. 三项累计值从 0 开始；
2. 开局身份数据里配置的对应倾向作为比较参照；
3. 本场 PK 胜利后提交本场倾向；
4. 本场失败重开时撤回本次未提交倾向；
5. 计算主导倾向、次要倾向、并列与全零状态；
6. 向休息时刻提供环境表现结果；
7. 进入神降临时冻结最终倾向；
8. 向神降临和结局提供同一份最终结果。

## TT-09 神谕选择额外倾向边界（已核实）

- 本版正式神谕选择额外倾向为 0；选中候选的 `tendency` 用于记录神谕内容，不作为普通命中增量输入。
- `FinalOracleSession.confirm_display_candidate()` → `FinalOracleConfirmationState.confirm_selection()` 冻结并广播首次确认，确认器本身不修改 `TendencyState`。
- 真实 Sandbox 的 `_on_oracle_confirmation_committed(run_data, level_id, _candidate)` 在验证同场击破成功后调用 `commit_attempt_tendency()`，只提交此前普通命中累积的三个 `attempt_*_total`，没有根据候选增加分数。
- 若确认前累计为 C、本场普通命中暂存为 A，则确认后的累计为 C + A，神谕选择额外增量仍为 0。A 为全零时三项累计原样保留；A 非零时正常提交并清空暂存。该 0 规则继续允许普通命中提交。
- 当前实现已满足边界，TT-09 没有新增运行接口或单元测试；Godot 4.7.2 真实 Sandbox / Session 确认 smoke 已覆盖三类候选、普通命中暂存提交和同关重复确认。

## TT-10：Rest 只读环境结果

RS-07 的消费方在普通胜利倾向正式提交后，从所属周目的 `SaveData.tendency_state` 调用现有公开查询。结果可直接用于选择环境状态；没有新增环境数值、视觉资源映射或第二套结果接口。

| 现有查询 | 给 Rest 的信息 |
| --- | --- |
| `get_primary_tendency_id()` | 当前环境采用的主导 ID：`orthodox`（正统）、`heretical`（异端）、`absurd`（荒谬） |
| `get_secondary_tendency_id()` | 已提交结果的次要 ID，单一正分项时与主导相同 |
| `is_primary_tied()` | 当前已提交最高项是否并列 |
| `has_no_effective_behavior()` | 当前已提交三项是否全零 |

- 四项查询只读取已提交累计，普通命中新增的 `attempt_*` 在正式提交前不影响结果；失败撤回仍保留已有环境结果。Rest 只读取 ID / 布尔标记，精确累计和本场暂存继续归 17，环境读取不会调用提交或回滚。
- 有效结果并列时，主导优先并列项中的开局身份，否则按正统 → 异端 → 荒谬裁决；次要沿用现有剩余正分项规则。消费方直接采用查询结果，不重算裁决。
- 全零时主导与次要沿用 `opening_identity_tendency_id`，`has_no_effective_behavior()=true`，现有 `is_primary_tied()` 也为 `true`。消费方先识别全零标记，再处理有效行为并列；保留已有两个标记的实际含义。
- 输入前提是身份已初始化的有效周目；未提供周目 / TendencyState 时消费方保持尚无环境结果，未初始化参照可能为空 ID，不推测正式场景或替代倾向。
- TT-10 已使用真实 TendencyState 提交 / 回滚与 RestSession 打开事件验证此读取方式。当前 RS-07 页面接线与房间视觉切换仍由 B 完成；本卡未修改 Rest UI 或 Sandbox。终局冻结与同一结果供 19 / 20 留 TT-11 / TT-12。

## TT-11：进入终局冻结最终倾向

- 复用 DD-01 的 `DivineDescentSession.enter(run_data)`：普通关卡结果正式提交后调用一次，19 保存本次终局的 `entry_snapshot.tendency_result`；17 继续拥有源 TendencyState 的累计、开局参照及裁决规则。
- 冻结字段为三个已提交 `*_total`、`opening_identity_tendency_id`、`primary_tendency_id`、`secondary_tendency_id`、`is_primary_tied`、`has_no_effective_behavior`。主次 / 并列 / 全零直接读取现有公开判定，`attempt_*` 排除，进入不会提交或清空暂存。
- 后续源普通命中暂存、正式提交、初始化依据变化均不影响该次终局快照。Source Resource 保持原归属，终局通过同一 Session 的 `get_entry_snapshot()` 读取首次事实；返回副本修改和重复 `enter()` 也不能替换内部结果。
- TT-11 没有另建冻结状态或新增运行接口。新增且只新增一个单元测试 `tests/unit/tendency_state_final_freeze_test.gd`，覆盖冻结后保持不变；真实 Resource / 场景 smoke 同时核实全零结果和存读后的暂存隔离。
- 本卡只核实倾向冻结边界，RS-10 正式进入组合及终局演出输入仍由其系统负责；TT-12 的统一结果消费和 Ending 接线留下一张卡。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| TT-01 | 三项倾向运行时状态 | 无 |
| TT-02 | 普通话语累计本场倾向 | 无 |
| TT-03 | PK 胜利提交本场倾向 | 1 个关键单元测试 |
| TT-04 | 失败重开撤回本场倾向 | 1 个关键单元测试 |
| TT-05 | 主导倾向基础判定 | 1 个关键单元测试 |
| TT-06 | 主导倾向并列裁决 | 2 个关键单元测试 |
| TT-07 | 次要倾向判定 | 2 个关键单元测试 |
| TT-08 | 全零状态 | 1 个关键单元测试 |
| TT-09 | 神谕不追加倾向 | 无 |
| TT-10 | 提供休息时刻环境结果 | 无新增自动化测试 |
| TT-11 | 进入神降临时冻结最终倾向 | 1 个关键单元测试 |
| TT-12 | 提供给神降临与结局 | 无新增自动化测试 |
| TT-13 | Neutral 普通闲聊接入 | 3 个最小规则测试及 Sandbox 冒烟 |
| TT-14 | Neutral 随 Tier 衰减 | Tier 配置、类别抽取与切档后新批次的最小验证 |

## 测试预算

只保留 9 个纯逻辑 case：

- PK 胜利会把本场倾向提交到累计值；
- 失败重开撤回本场未提交倾向；
- 单一最高值得到主导倾向；
- 主导并列且包含开局身份对应倾向时优先该倾向；
- 主导并列且不含开局身份时按正统→异端→荒谬裁决并保留并列标记；
- 次要倾向取剩余最高正分项；
- 剩余项全为 0 时次要倾向采用主导倾向；
- 三项全为 0 时主导/次要沿用开局身份对应倾向并标记无有效行为；
- 进入神降临后后续输入不能修改冻结的最终倾向。

精确数值显示、环境视觉和跨系统读取都不写额外单元测试。

## 依赖顺序

TT-01 可先做。
TT-02 等 6. HitResolution 的普通话语倾向事件。
TT-03 / TT-04 等本场胜负与 7. OpponentPKBar 重开流程。
TT-05～08 可完成纯判定逻辑。
TT-10 等 18. Rest。
TT-11 已复用 DD-01 Session 核实终局冻结；TT-12 后续消费同一 Session 的固定结果，等待单独任务分配。
TT-13 建立 Neutral 普通话语链路；TT-14 在 TT-13 基础上接入随 Tier 变化的 Neutral 生成权重。
