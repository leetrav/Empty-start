# 后半程系统审计：12–20

日期：2026-10-08

范围：`docs/12. ContradictionBreak/` 至 `docs/20. Ending/`，以及直接相关的 `core/`、`systems/`、`ui/`、`scenes/`、`tests/`、关卡与奖励配置。

本轮先阅读 `AGENTS.md` 与 `known_traps.md`，使用 `global-work-rules` 和 `gsd-onboard`。审计依据为当前源码、场景/配置、任务卡及既有日志；没有运行测试或 Godot，也没有修改产品源码。本文件是本轮唯一写入成果。

## 当前结论

普通 PK 可以进入真正的矛盾击破阶段，随后交给神谕或休息的状态入口。可操作神谕、成功奖励、休息展示及继续下一关尚未接通；神降临与结局尚未实现。当前项目的一局完整流程尚未到达结局。

9 个系统共 100 张任务卡；48 张有对应完成日志。这个数字包含独立逻辑完成，不能作为玩家完整流程的完成率。CB 额外有一份汇总集成日志，因此日志文件数为 49。

## 逐系统状态

| 系统 | 任务卡数 | 有日志且代码支持的完成任务 | 当前实际能力 | 剩余/集成缺口 |
| --- | ---: | --- | --- | --- |
| 12. ContradictionBreak | 12 | CB-01～12 | 真/假矛盾生成，10 秒与有限发射次数，释放同帧判定，结果锁定，矛盾复读，成功静音过渡后开放神谕，未击破进入休息入口，普通历史与本场倾向提交 | 核心卡已完成；正式复读节奏、音效和手感仍待 Godot GUI 人工验收 |
| 13. FinalOracle | 13 | FO-01～09 | 从本场普通历史生成最多三句候选；按普通复读数、最近命中、稳定 ID 排序；冻结展示快照；独立 10 秒计时器、自动选句函数、同周目同关一次确认 | FO-13 中央主游戏区攻击选句；FO-07/08 的运行接线；FO-11 发卡/吞并；FO-12 成功进入休息。FO-10 已有跨卡重叠实现，见下节 |
| 14. Assimilation | 9 | AS-01～05 | 周目成果 Resource；通关与真正击败分离；普通词库和继承特性的资格检查、稳定 ID 去重 API | AS-06～09；FO-11 真实结果调用与正式继承配置。AS-07 已有保留行为基础，仍缺专属交付/完整验收证据 |
| 15. Scripture | 8 | SC-01～05 | 接收真实神谕确认；首条经文保存；固定随机节号；原章号与缺章排序；未确认暂存及重开撤回；存读保留 | SC-06～08 的休息、终局、结局消费者 |
| 16. LoserCard | 7 | LCARD-01～06 | 卡片资料模型；真正击败发卡 API；同主播去重；周目存读；新周目独立清空 | LCARD-07 休息展示；FO-11 奖励调用；正式卡片资料 |
| 17. ThreeTendencies | 14 | TT-01～08、TT-13～14 | 本场暂存，胜利提交/失败撤回，主导/次要/并列/全零判定；neutral 零倾向及随 Tier 衰减 | TT-10 环境消费者，TT-11 最终冻结，TT-12 终局与结局读取。TT-09 的零额外奖励行为已包含在 FO-09 |
| 18. Rest | 11 | RS-01 | 验证结果类型，首次打开冻结结果，返回独立快照 | RS-02～11：展示、历史、空态、环境、幂等结算、下一关、进入终局、输入切换 |
| 19. DivineDescent | 17 | 无 DD 完成日志 | 仅有 TT-13 提供的三项倾向普通历史筛选 helper | DD-01～17，运行阶段 NOT IMPLEMENTED |
| 20. Ending | 9 | 无 EN 完成日志 | README 与任务卡 | EN-01～09，数据组合与页面 NOT IMPLEMENTED |

## 已实现的跨卡重叠

- **FO-10 / SC-02：已实现来源交付和一次写入。** `scenes/sandbox/sandbox.gd:44` 调用 `ScriptureData.bind_confirmation_state()`；`core/scripture/scripture_data.gd:117` 接收同周目确认事件，按真实关卡解析原句文本、主播名和章号；`write_confirmed_oracle()` 首次写入并固定节号。SC-02 日志记录真实 FinalOracleSession 确认、存读、重建确认器后去重的 runtime smoke。没有 FO-10 专属日志；后续应核销任务交付记录，复用现有接线。
- **TT-09 / FO-09：零额外倾向行为已存在。** `core/final_oracle/final_oracle_confirmation_state.gd` 只固定并广播确认事实；Sandbox 确认回调提交既有本场普通命中倾向，没有选句额外奖励。FO-09 日志明确额外倾向为 0。没有 TT-09 专属日志；需要与 TT-03 的普通本场提交区分。
- **AS-07：保留成果已有基础。** `Sandbox.restart_current_attempt()` 保留同一 `SaveData`；`tests/integration/int_01_playable_battle_sandbox_test.gd:242` 检查此前击败主播 ID 保留。代码没有重置吞并 Resource。缺 AS-07 专属日志，以及此前词库权重/特性集合与当前关未提交成果的完整实际联调证据，因此保留为 PARTIAL / TO VERIFY。
- **RS-08：RS-01 已提供会话级首次打开规则。** `RestSession.open_result()` 拒绝覆盖首份快照，日志有临时 smoke；奖励提交及重复打开实际休息 UI 的完整验收仍待后续流程。

## 运行流程与上游依赖

1. **神谕目前只有入口与可复用逻辑。** `Sandbox._on_oracle_silence_finished()` 打开 `FinalOracleSession` 后关闭攻击、显示状态提示并发出 `final_oracle_opened`。现有 UI 没有订阅该事件；生产流程没有创建/推进 `FinalOracleSelectionTimer`；`select_auto_pick_from_display()` 仅在测试中被调用。`confirm_display_candidate()` 可供后续交互复用。当前玩家无法通过正式界面完成选择。
2. **成功确认后尚未提交奖励或进入休息。** `Sandbox._on_oracle_confirmation_committed()` 只提交普通命中历史与本场倾向。`AssimilationData.register_level_result()`、词库/特性登记与 `LoserCardData.grant_on_true_defeat()` 的调用方目前只有测试。`breakthrough_oracle_complete` 被 `RestSession` 接受，但当前生产流程没有传入该类型。
3. **下一关尚未进入生产流程。** `LevelRunState.complete_level()` 已具备推进和全部普通关完成判定，但当前仅在关卡测试中被调用；`RestSession` 没有继续操作，RS-09/10 尚未接通。当前 `SceneRouter` 只有菜单、身份设置、Sandbox 和重载入口。
4. **终局缺普通复读的跨关历史。** `SaveData` 已保存 `committed_normal_hit_history`；`RepeatGenerationStats` 仍归本场 `RepeatDelayQueue`，重开会建立新队列，周目没有已提交普通复读历史。RP-10 提交/回滚和 RP-12 的神降临消费是 DD-02/06 的上游缺口。FO-01 已能读取本场统计，因此 RP-12 是部分接线。
5. **奖励配置尚未提供。** `LevelProfile` 尚无稳定 pool_id、继承权重和继承许可；`special_trait_ids` 只表示本关使用特性，不能直接充当继承白名单。`data/loser_card/loser_card_catalog.tres` 的 profiles 为空，资料缺失时发卡 API 返回 false。
6. **普通关内容缺口。** `data/level_configuration/level_002.tres` 仅有来源信息和待填写主题，缺正常话语与矛盾内容。实际进入第二关前需补充可运行关卡内容。
7. **最终结果冻结及终局运行缺失。** `TendencyState` 目前只有可变累计与即时判定 API，TT-11 的最终冻结快照未实现；DD 扩散、加权、锁句、90% 收束、输入表现与转场，以及 EN 教名/分类/判词/页面均未实现。

## FO-13 的当前任务约束

- 正式交互直接发生在当前中央主游戏区；显示 1～3 条固定候选，复用普通准心、蓄力与发射流程。
- 同一发命中多个候选时，选择候选中心到准心中心距离最近的一句；只提交一次。
- 候选出现并可操作后启动 10 秒计时；暂停冻结；手动与超时共用 FO-09 确认入口。
- 任务卡提到现有 `FinalOracleScreen` Panel/Button，但当前仓库没有该 Scene 或脚本。后续实现应依据当前 `FinalOracleSession` 和真实 BattleArea。
- **不新增零候选兜底决定。** 任务卡第 8 节明确本卡不新增零候选兜底，并声明设计通过 Tier 5 neutral 权重为 0 保证有效非 neutral 候选。该非空候选保证记录为 **TO VERIFY 任务假设**，应在后续真实攻击选择联调中检查；本审计没有修改设计。

## 文档漂移

- FinalOracle README 的早期段落仍写 FO-07～12 待实现；FO-07/08 已有独立逻辑，FO-10 行为已由 SC-02 接线。应区分逻辑完成、运行接线和任务日志交付状态。
- ThreeTendencies README 留有早期 INT-01 “PK 满后尚未跨关提交”描述；当前代码与 CB 汇总日志已在未击破进入休息、成功神谕确认节点提交本场倾向。
- TT-14 日志仍称 TT-13 PR 未合并；当前 Git 历史已包含 PR #23 / #24 的集成合并。日志中的历史执行记录应保留，当前状态摘要应以已合入代码为准。
- FO-13 提到的 `FinalOracleScreen` 在当前仓库不存在。

## 历史验证证据与边界

| 证据 | 已记录的验证 | 适用边界 |
| --- | --- | --- |
| `docs/12. ContradictionBreak/矛盾击破系统_CB-01至12_2026-10-07_log.md` | CB 核心 9 case、FO 候选回归、真实 Sandbox/InputEvent 104 checks，包含 Paradox 参数、释放同帧判定、Rest/FinalOracle 入口交接 | 支持普通战斗到入口的集成；完整选择、奖励、后续页面仍缺 |
| FO-01、FO-07、FO-09 日志 | 实际 Sandbox 成功入口 smoke；临时计时器 smoke；会话展示内/外候选及重复确认 smoke | 计时器未接正式 UI，临时 probe 已删除 |
| FO-02～09 日志及 `tests/unit/final_oracle/test_candidate_pool.gd` | 候选、排序、补位、自动选择、单次确认共 8 个核心 case | 纯逻辑验证，玩家攻击选择未联调 |
| SC-02～05 日志 | 7 case；真实确认、ResourceSaver/Loader 往返、暂存重开撤回、正式经文和节号保留 smoke | 数据/确认接线，休息、终局、结局展示未验证 |
| AS-02～05 日志 | 7 case，资格、通关/击败、去重 | 数据 API；真实奖励、词库生成和继承装配未联调 |
| LCARD-02～06 日志 | 5 case；LCARD-05 跨进程存读、真实失败/重开保留、旧存档默认空 Resource smoke | 数据/保存；正式 Catalog 与玩家发卡缺 |
| TT-01～08、TT-13/14 日志 | 倾向判定/提交/回滚；neutral 真实生成、鼠标攻击、历史/复读 smoke；104 checks 回归。TT-14 使用可写临时 APPDATA 重跑退出码 0，相关日志干净 | neutral 正式策划内容尚未填写；未人工画面试玩；最终冻结缺 |
| RS-01 日志 | 首次打开、重复拒绝、输入输出深拷贝临时 smoke | 状态入口验证，休息 UI 与继续流程缺 |

历史 headless 验证有 `user://` 设置/日志写入与证书警告的记录；TT-14 后续临时 APPDATA 重跑记录已消除相关运行环境错误。本轮没有重跑这些验证，当前 checkout 的新运行结果标记为 **UNVERIFIED**。

完整 GUI 试玩、正式复读/音效节奏、可操作神谕到奖励/休息、跨关推进、神降临到结局均没有完整验证证据。

## 后续接手入口

按现有任务约束，先接 FO-13 与既有 FO-07/08/09，再复用 FO-10/SC-02，补 FO-11/12 与奖励配置、Rest 流程和实际后续关内容。RP-10/12 与 TT-11/12 为终局准备已提交历史和最终快照；随后实现 DD 与 EN。复用现有 API 和测试预算，避免再次实现已交付的候选、经文与奖励数据规则。
