# 前十个系统现状审计

日期：2026-10-08
仓库：`D:/Godot/Empty-start`
范围：`docs/1. Identify/` 至 `docs/10. Repeat/`，对应任务卡、任务日志、直接相关代码、场景与现有测试源码。跨系统文件只用于确认这些系统的真实调用方。

## 结论与证据边界

普通战斗的攻击、整发结算、PK 回拉、Tier、延迟复读、评论计数、暂停与失败重开已经形成可玩链路。当前代码进一步接通普通 PK 满值进入矛盾窗口，以及击破后打开神谕数据入口、未击破后打开休息数据入口。历史集成日志记录过真实输入和 GUI 验证。

整局流程仍缺关卡推进调用；本场普通复读统计没有周目提交存储；陷阱和整发异常没有扣分实现；直播观看、点赞与新增粉丝规则尚未接入。正式内容仍以示例资源为主，第二关缺普通词库和矛盾内容。

本审计只读取现状，没有运行 Godot、测试、解析检查或 GUI 验收。文中“历史验证”指已有日志记载，并未在 2026-10-08 重现。静态阅读可以确认调用关系与缺失实现，当前工作树的运行结果统一保留为 `TO VERIFY`。只新增本审计文件。

状态含义：

- `IMPLEMENTED`：当前代码已有该能力；运行证据另列。
- `PARTIAL`：任务的部分能力已经存在，仍有明确验收缺口。
- `NOT IMPLEMENTED`：当前生产代码未找到所需能力。
- `UNVERIFIED`：缺少覆盖该验收条件的实际运行记录。

## 1. Identify

**任务状态：ID-01～ID-07 IMPLEMENTED。**

- 三种身份 Resource、主播名与粉丝团名空白回退、有效身份首次锁定、周目字段、身份设置 UI、主菜单新游戏到身份确认再进入 Sandbox 均有代码。身份确认同时初始化三项倾向的开局比较参照。
- 代码入口：`data/identity/identity_option.gd`、`core/identity/identity_name_rules.gd`、`identity_confirmation_state.gd`、`core/autoload/save_manager.gd:19`、`ui/identity_setup/identity_setup.gd:127`、`ui/main_menu/main_menu.gd`、`core/autoload/scene_router.gd`。
- 七张任务卡均有同 ID 日志。ID-06 日志记录 headless 完整开局与存档重载，探针曾用 SettingsManager 存根并暂时移除无关 Autoload；ID-07 日志记录主播名、粉丝团名、身份存档往返。对应纯逻辑 runner 为 `tests/unit/identity_name_rules_test.gd` 和 `identity_confirmation_state_test.gd`。
- 遗留：正式身份名称与图标；默认“新主播”“新粉丝团”为临时文案。后续展示 `fan_group_name` 与结局读取身份属于消费者接线，当前字段已经可读。
- 文档漂移：README 仍称 Game 为“技术测试场景”；现在同一 Sandbox 已承载普通战斗与矛盾窗口。

## 2. LevelConfiguration

**任务状态：LC-01～LC-06 IMPLEMENTED；LC-08 的同关重开行为由 INT-01 IMPLEMENTED；LC-07、LC-09 NOT IMPLEMENTED。**

- `data/level_configuration/level_profile.gd` 保存主播资源、普通话语、类别比例、强度、权重、特殊特性 ID、真假矛盾及生成参数。`level_run_state.gd:37` 已实现当前关首次完成、推进、去重及普通关全部结束状态。
- `scenes/sandbox/sandbox.gd:67` 原地重开保留同一 `LevelRunState`，重新读取当前关配置，并重建本场系统。LC-08 的旧日志为延期记录，代码后来由 INT-01 补齐。
- LC-07 日志明确 `DEFERRED / NOT IMPLEMENTED`。当前生成仍直接读取静态当前关 `normal_speech_pool`；`special_trait_ids` 也没有生产消费者。已获得吞并词库和特性尚未组合进当前有效关卡内容。
- LC-09 日志明确延期。生产 `core/ systems/ ui/ scenes/ data/` 内 `complete_level()` 只有定义，没有调用；`SceneRouter` 只有主菜单、身份设置、游戏和重载入口。当前 Rest 打開只产生数据会话，未推动第二关或终局。
- 数据缺口：`data/level_configuration/level_001.tres` 为三条强度 1 示例词、一真一假示例矛盾；`level_002.tres` 只有基本主播信息，词库、类别比例和矛盾列表沿用空默认值。即使接通推进，第二关也需要可玩的内容。
- 历史验证：LC-05 记录 2 个当前关选择用例通过，LC-06 记录 3 个完成/去重/末关用例通过；LC-01 初期字段读取曾标为 UNVERIFIED。INT-01 后续真实场景验证覆盖当前关配置与同关重开。
- 文档漂移：LC-07～09 旧日志仍按 2026-10-05 的依赖缺失描述；部分依赖现在已有数据 API，需重新按真实消费者梳理。不得按九份日志计算九卡完成。

## 3. BarrageGeneration

**任务状态：BG-01～BG-08、BG-10～BG-12 IMPLEMENTED；BG-09、BG-13 的集成行为由 INT-01 IMPLEMENTED；BG-14 后续沿 INT-02 静态 Scene 布局约定完成。**

- 当前 `systems/barrage_generation/barrage_area.gd` 具有普通抽词/批次 Timer、Tier 对未来生成的倍率、生成时寿命快照、普通/复读独立容量、实际空位检查、生成事实、指定实例结束、清场、矛盾生成和矛盾复读可见状态查询。`barrage_view.gd` 负责移动、到期/离区释放和暂停寿命补偿。
- BG-09 的原日志仅记录阻塞；当前 `end_barrage()` 与 Sandbox 按最终 Trait Result 结束目标的接线已存在。BG-13 原日志仅记录阻塞；当前 `sandbox.gd:460` 同时停生成、清场、停攻击/回拉、清普通复读队列。
- BG-12 有两份同日期日志：旧 `弹幕生成_BG-12...` 为阻塞；`弹幕生成系统_BG-12...` 记录入口实现。2026-10-07 CB 集成日志与当前 `sandbox.gd:430` 确认该入口已实际调用。
- 当前矛盾生成使用独立 Paradox 配置（数量×2、频率×3、速度×2.5、10 秒），真伪由 12 系统读取 ID 列表判定。普通生成实例的 `trait_set` 默认空，雷/假牌/反击等正式内容生成仍缺特性分配与内容配置。
- 历史验证：BG-06 两个寿命用例、BG-07 两个容量用例、BG-10 两个独立复读容量用例；BG-11 记录真实场景 7 项暂停检查；INT-01 记录空位和真实 Timer 补测。现有资产在 `tests/barrage_generation/` 与 `tests/integration/int_01_playable_battle_sandbox_test.gd/.tscn`。
- 文档漂移：README 仍称 BG-12 尚未合入 main，当前代码与 CB 集成日志已覆盖该状态。BG-14 原先运行时读取布局的实现被 INT-02 静态父场景布局替换，当前正式文档已说明这一决定。

## 4. BarrageTraits

**任务状态：BT-01～BT-05、BT-07～BT-09 IMPLEMENTED；BT-06 PARTIAL；BT-10 的过滤由 CA-08 IMPLEMENTED；BT-11 PARTIAL；BT-12 当前生成边界存在、完整验收 UNVERIFIED；BT-13 NOT IMPLEMENTED。**

- `systems/barrage_traits/barrage_trait_set.gd` 已有六种稳定特性 ID、多特性装配、不可选、复制品来源与禁止继续复制、一次分裂标记、反弹→遮挡→基础结果解析及明确兼容规则。
- BT-06 当前只有 `try_begin_split()`，生产代码没有调用方。母体结束、两个子话语、独立原句 ID、倾向/强度配置、母体截止时间继承均缺实现；BT-06 日志也明确子话语尚未生成。
- BT-10 当前释放扫描调用 `is_selectable()`，到达读取 `get_hit_result()`。BT-11 的最终结果已进入 HitResolution 输入，遮挡跳过普通奖励、反弹进入 ShotAnomaly 分类；假牌惩罚分支依赖 HR-03，当前仍缺，因此 BT-11 验收未完全满足。
- BT-12：真假矛盾使用独立生成入口新建空 TraitSet，攻击模式直接交给 12 系统；没有独立 BT-12 日志。普通阶段正式特性分配尚未形成，未来接入普通/继承特性时仍要验收矛盾排除边界。
- BT-13：生产代码未读取吞并的继承特性。`LevelProfile.special_trait_ids` 只保存 ID，没有装到具体实例的规则。
- 历史验证：BT-08 3 个结果优先级用例、BT-09 4 个兼容用例；CA-08 有临时真实场景混合特性结果检查；INT-01 Review 日志记录五种目标真实攻击和移除行为。BT-01～05/07 初期日志主要为解析检查，完整正式陷阱生成、复制演出和分裂场景仍未验证。
- 区分范围：BT-05 任务卡明确只要求复制品运行状态，完整复制生成不属于该卡；该完整玩法仍是产品遗留，不能靠 BT-05 完成推出已可玩。

## 5. CombatAttack

**任务状态：CA-01～CA-09、CA-11 IMPLEMENTED；CA-10 行为由 CB 集成 IMPLEMENTED；CA-12 NOT IMPLEMENTED。**

- `systems/combat_attack/` 已有鼠标准心、设计坐标圆/矩形相交、蓄力、未满取消、释放时目标去重快照、普通飞行到达复核、硬直、Trait 过滤与统一结算、全局暂停和停止当前攻击入口。
- 当前矛盾模式在释放时冻结 `AttackTargetSnapshot` 中的原句事实，由 `sandbox.gd:283` 立即判定和生成矛盾复读；飞行仅保留演出，绕过普通 HitResolution。CA-10 没有独立日志，但 2026-10-07 CB 集成/Review 日志和当前代码具有证据。
- CA-12：`aim_reticle.gd` 只处理 `InputEventMouseMotion`；`attack_charge_input.gd:101` 只处理左键 `InputEventMouseButton`；未找到触摸事件接线。Android 整体输入仍待实际设备验证。
- 历史验证：纯逻辑相交/蓄力/取消/快照 runner；CA-05～11 临时真实场景联调；CA-01、INT-01 Review 记载 GUI 鼠标命中及四种尺寸下视觉/判定一致。`tests/combat_attack/test_int01_attack_boundaries.gd` 为现有边界资产。
- 文档漂移：README 依赖段仍称 CA-10 等待真实接口，上方当前实现已描述矛盾模式；后者与代码一致。

## 6. HitResolution

**任务状态：HR-01～HR-02、HR-04～HR-09、HR-14～HR-15 IMPLEMENTED；HR-10/11 由 INT-01 IMPLEMENTED；HR-13 边界由 CB 集成 IMPLEMENTED；HR-03、HR-12 NOT IMPLEMENTED。**

- `core/combat/hit_resolution.gd` 拥有唯一 PK，支持范围限制、强度 1/2/3 固定奖励、neutral 倾向增量 0、复读有效零收益、整发汇总一次更新、异常优先级、部分目标失效、PK 已归零时整发取消、普通命中历史归并、一次提交及未提交回滚。
- `scenes/sandbox/sandbox.gd:355` 将最终逐目标结果交给本场倾向和普通复读；`:269` 神谕确认、`:320` 未击破最终结果提交普通命中历史与倾向；失败及重开丢弃未提交命中历史。HR-10/11 的旧日志是早期阻塞，已经被这些接线覆盖。HR-15 日志尾部有补做结果，应连同前部旧阻塞一起读。
- HR-03 真实缺口：`attack_charge_input.gd:239` 算出 `shot_anomaly` 后，只把它放入提交字典；调用 `resolve_shot_results()` 的目标结果没有异常扣分。非正常 Trait Result 也没有写入负 `pk_delta`。当前假牌、反击、反弹、遮挡及落空的 PK 惩罚均未实现，雷弹幕运行类别也未形成。
- HR-12：普通/陷阱命中只更新战斗反馈，未调用 LiveSessionData 的观看/点赞事件规则；需与 LD-03 的配置和消费者共同补齐。
- 历史验证：`tests/hit_resolution/` 保留 PK、汇总、异常优先级、目标失效、零 PK、历史与提交回滚的 runner。HR-15 补做日志记录两个用例和 Resource 往返；CB 集成日志记录候选确认后才提交普通历史。
- 文档漂移：README 开头仍称“跨关提交等待正式胜利流程”，后续 HR-15 节与当前代码已经说明最终结果提交。数据写入当前内存 SaveData 已成立，整局跨关推进与统一持久保存仍需按后续流程确认。

## 7. OpponentPKBar

**任务状态：OP-01～OP-06 IMPLEMENTED；OP-07 的本场数据回滚主要行为已由 INT-01/CB IMPLEMENTED；OP-08 保留当前 SaveData 的机制存在，全部成果验收仍 PARTIAL / UNVERIFIED；OP-09 计数核心与失败加一 IMPLEMENTED，关卡完成清零接线缺失。**

- `core/combat/opponent_pk_bar.gd` 按游戏帧时间产生回拉增量，通过唯一 HitResolution 更新 PK；可暂停/停止/恢复、更新 Tier 倍率和 Tier5 状态、归零只发一次失败、重开解除失败锁并保留连败。
- 当前 Sandbox 监听失败，关闭攻击、清场、回滚本场倾向/命中，显示真实重开按钮；重开重建 HitResolution/RepeatDelayQueue/CombatStage，并回滚尚未确认经文。前关 SaveData 成果对象继续保留。
- `complete_current_level()` 与 `start_new_run()` 纯接口存在。生产流程未调用完成清零；LC-09 接通时需要一起补齐 OP-09 完成节点。新周目进入新 Sandbox 会自然新建 OpponentPKBar。
- OP-06～08 专属日志仍为早期阻塞。INT-01 runner 使用预置倾向和已吞并主播验证保留；当前 runner 未覆盖前关圣典、败者卡与真实奖励提交后再重开的完整矩阵，OP-08 的全部验收应继续保留。
- 历史验证：OP-01 回拉计算、OP-05 归零只发一次、OP-09 连败纯逻辑 runner；INT-01 记录实际回拉、失败页 GUI 重开、同关重置与历史保留。当前成果真实发放链及完整跨关保留受后续奖励/关卡流程限制。

## 8. CombatStage

**任务状态：CS-01～CS-10 IMPLEMENTED；CS-11/12 的可见阶段行为由 Sandbox/CB 集成 IMPLEMENTED，专属卡文档收尾待完成。**

- `data/combat_stage/tier_catalog.tres` 与 `core/combat/combat_stage.gd` 已有 Tier0 开局、升降阈值、多档变化、最终 PK 后重算、普通生成四倍率、复读数量、回拉/Tier5 状态、Tier 广播与升档音效请求。当前新增 neutral 权重倍率只影响后续类别抽取。
- 满 PK 处理在 `sandbox.gd:400/430`：同步停回拉/普通生成，完成本发提交，再清场和普通待复读，启动真实矛盾窗口。当前 `CombatStage` 本身仍只管理档位，场景负责阶段组合。
- CS-07/08/10 的逐卡日志曾为运行 UNVERIFIED；INT-01 后续实际场景记录补齐普通倍率、复读与 Tier 可见反馈。CS-10 对手立绘资源状态/直播热度/音乐的完整表现仍需要对应资产与消费者验收，当前升档音效是公开事件请求。
- CS-11/12 没有独立日志；README 仍显示矛盾等待提示，已落后于 CB 集成。CS-11 卡要求一个专属纯逻辑用例，`tests/combat_stage/` 目前只有 CS-03/04/05；阶段行为在真实集成 runner 覆盖。后续收尾时应按项目当前最小集成验证约定确认验收方式，避免重复建设测试。
- 历史验证：3 份 Tier 纯规则 runner，以及 INT-01、2026-10-07 CB 的真实输入集成记录。

## 9. LiveDataPresentation

**任务状态：LD-01/02/05/09 IMPLEMENTED；LD-08 重开行为由 INT-01 IMPLEMENTED；LD-03/04/06/07/10 NOT IMPLEMENTED。**

- `core/live_data/live_session_data.gd` 保存观看/点赞/评论/粉丝，属性变化通知 HUD；提供开播计算入口与按实际生成数累计评论。`ui/live_data/live_data_hud.gd/.tscn` 已按四个 RichTextLabel 显示左右镜像数字，支持显式数据绑定与单纯显示值。
- Sandbox 当前只通过 `barrage_generated` 累计评论；普通和复读成功生成各计一次。重开 `initialize_session(_opening_fan_count)` 重置观看、点赞、评论并保留入关粉丝。
- LD-02 计算能力完成，但生产代码未调用 `set_opening_viewers()`；缺正式起始粉丝/倍率范围及单次抽取的开播流程。LD-03/04 日志仍写真实事件未形成，当前攻击提交/Tier 广播已经存在，配置与消费者接线继续缺失。
- LD-06 缺击破/神谕短时上涨；LD-07 缺 PK 胜利粉丝只结算一次；LD-10 缺休息结果读取和展示。当前默认粉丝为 0，观看与点赞不会随普通战斗增长。敌方 HUD 的四项 0 是明确占位。
- LD-08 专属日志为旧阻塞，当前原地重开代码及 INT-01 已覆盖核心规则。LD-09 原日志描述右上角卡片是历史版本，现行 INT-03 富文本叠层及 README 已更新。
- 历史验证：LD-02 两个计算用例，LD-01 Resource 往返探针，LD-05 临时评论/reset smoke；INT-03 记录两个分辨率 GUI、真实 Resource 单项更新、镜像与 6 位数可读性。Android emoji 字体回退与正式数字动画未验收。

## 10. Repeat

**任务状态：RP-01～RP-06、RP-08/09/11 IMPLEMENTED；RP-07 命中行为由 INT-01 IMPLEMENTED；RP-10 NOT IMPLEMENTED；RP-12 仅本场神谕消费者 IMPLEMENTED，终局历史消费者 NOT IMPLEMENTED。**

- `core/repeat/repeat_plan.gd` 创建普通/矛盾固定数量、结算后 Tier、原句 ID/文本、类别和寿命计划。`repeat_delay_queue.gd` 拆为单条 0.5～3 秒请求，普通待生成上限溢出丢弃，屏幕容量/位置不足时保留到期请求重试，成功后才分类统计。普通/矛盾清队列互相独立。
- `sandbox.gd:355` 真实普通命中建计划；复读再次命中有效零收益并不递归；`:283` 真假矛盾释放命中均建计划；成功过渡等待 pending 矛盾请求和实际可见矛盾复读清空。RP-07 日志旧阻塞已被 INT-01 覆盖；RP-08 日志的旧“到达”接手入口已被 2026-10-07 释放即时判定替换。
- RP-10 真实缺口：`RepeatGenerationStats` 只有本场两个字典与累加/getter，没有提交/回滚方法；`SaveData` 没有已提交普通复读计数；重开新建队列及 stats。失败重开可以丢弃本场统计，PK 胜利后的跨关提交能力尚未建立。RP-10 没有完成日志或对应提交/回滚 runner。
- RP-12：`sandbox.gd:246` 将当前队列 stats 传给 FinalOracleSession；`core/final_oracle/final_oracle_candidate_pool.gd:42` 按 `get_normal_count()` 排序，矛盾统计保持分开。向神降临提供周目已提交复读历史仍依赖 RP-10。
- 历史验证：普通计划两个用例、容量队列两个用例、分类统计两个用例；RP-04/06/11 临时实际探针；RP-08 记录 120 请求接受、首轮实际显示 17、103 保留等待；INT-01/CB 后续真实场景验证实际生成与矛盾来源。

## 优先进入的未完成工作

1. **完整关卡流程：LC-09 配合休息、神谕最终结果和终局入口。** 当前生产流程从未调用 `LevelRunState.complete_level()`；接通时同时完成 OP-09 的关卡清零，并准备 `level_002.tres` 的可玩内容。完整界面任务由对应后续系统审计确定。
2. **周目复读历史：RP-10 → RP-12 终局部分。** 正式胜利触发源已存在，可沿 HR-15 的最终结果节点接入真实 Repeat 数据拥有者；终局权重所需的已提交实际复读数当前缺来源。
3. **惩罚与特殊玩法：HR-03 + BT-11 + 正式实例分配。** 当前已有假牌/反击/反弹/遮挡结果类型，旧“无真实类型”的阻塞已部分解除；雷类别、数值来源与一次异常扣分仍要结合正式规则补齐。随后完成 BT-06 的实际两子话语分裂。
4. **继承：LC-07 + BT-13。** 从吞并真实输出构造当前有效内容，保持静态关卡 Resource 只读；明确特性装到具体实例的配置规则。
5. **直播表现：LD-03/04/06/07/10、开播流程。** 先落实正式数值与胜利生命周期，再连接当前真实攻击/Tier/矛盾/神谕事件。
6. **目标平台：CA-12 与 Android 实机输入/HUD。** 鼠标现状无法直接推出触摸完成。

## 与 Original 的差异及文档漂移

### 已明确记录为临时原型的差异

- `data/sandbox/attack_timing.tres` 为蓄力 0.20 秒、飞行 0.10 秒、硬直 0.15 秒；Original 数值表为 0.8 秒蓄力、0.15～0.25 秒飞行。INT-01 日志明确授权临时攻击时长，正式调参仍待完成。
- 当前 `playable_battle_config.tres` 回拉基数 0.001、普通基础寿命 10 秒、复读 6 秒；Original 回拉基数为 0.005，强度 1/2/3 基础寿命 8/7/6 秒、普通复读 3 秒且随 Tier 倍率。当前所有强度普通词使用同一基础寿命，复读生成按计划固定寿命；正式生命周期配置尚未逐类型落地。
- 原始布局保留在 `docs/Original/`；INT-02 的现行静态 Scene 区域为左右 128/432/520、中央 72/760/248，已由当前系统文档记录。应按当前正式决定接手。
- neutral 是后续确定的普通内容类别扩展，当前关卡类型、抽词、命中和复读均已接通，玩家仍只有三项倾向。原始三类别描述不能覆盖这项新决定。

### 仍会改变玩法或流程的实现缺口

- Original 的逐目标陷阱惩罚及单发反弹/遮挡/落空最多一次异常扣分当前缺失，直接影响普通战斗风险。
- Original 要求普通复读历史随 PK 胜利提交并供神降临读取，当前本场 stats 尚未保存到周目。
- Original 要求休息后推进关卡及最终进入神降临，当前只有关卡纯逻辑 API，无生产推进调用。
- Original 的特性装配、两子话语分裂、继承内容、观看/点赞变化和胜利粉丝结算当前尚未全部实现。

### 优先修正文档的条目

- LC-08、BG-09/13、HR-10/11、OP-06/07、LD-08、RP-07 的旧阻塞日志已被后续集成覆盖，应保留原始历史并追加当前收尾状态。
- BG-12、CS-11/12、CA-10、HR-13 的当前代码已进入真实矛盾阶段；README 中“等待矛盾/尚未合入”的表述过期。
- RP-08 的接手函数 `_on_contradiction_shot_arrived()` 已不存在，现入口为 `_on_contradiction_shot_created()`。
- CS-11/12、CA-10、HR-13、BT-10～13 等无专属完成日志。部分行为可由集成日志证明，剩余验收应按各卡边界核对，不能据缺日志断言整项功能缺失。

## 历史运行验证索引

- `docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md`：正式 Sandbox 84/84、GUI 普通命中/失败按钮、暂停与真实 Timer、五种 Trait 结果、四种尺寸准心一致性。
- `docs/Integration/直播数据富文本_INT-03_2026-10-06_log.md`：实际完成日期 2026-10-07，HUD 两种尺寸 GUI 与 84/84 既有场景回归，敌方正式值仍为零占位。
- `docs/12. ContradictionBreak/矛盾击破系统_CB-01至12_2026-10-07_log.md`：先记录 97 项，Review 后记录 104 项真实 InputEvent 集成；覆盖 Paradox 独立倍率、释放同帧判定、Rest/FinalOracle 数据交接；另有临时超时/击破/候选确认提交 smoke。
- 对应持久测试源码：`tests/integration/int_01_playable_battle_sandbox_test.gd/.tscn`、`tests/combat_attack/test_int01_attack_boundaries.gd`、`tests/barrage_generation/`、`tests/hit_resolution/`、`tests/combat_stage/`、`tests/level_configuration/`、`tests/opponent_pk_bar/` 及 `tests/unit/` 中 identity/repeat/live/trait runners。

这些历史通过记录证明当时覆盖到的路径。当前完整新游戏→多关→终局→结局、真实全部奖励提交、全部收藏保留、正式特殊玩法、触摸以及整局手感继续需要后续任务的实际验证。
