# Roadmap: Empty-start

## Overview

已有工程包含身份开局、普通战斗、真实矛盾阶段及神谕/休息数据入口。本路线图从剩余玩家流程出发，依次交付神谕奖励、战斗规则、休息多关、神降临、结局、正式视听和 Windows/Android 构建。v1.0 为本次规划的完整可玩交付里程碑；已有代码基准详见 PROJECT，当前运行仍为 UNVERIFIED。

**Granularity**: standard
**Phase ID convention**: sequential
**Coverage**: 40/40 剩余 v1 需求各映射一次；40 个 Original 分组另见 REQUIREMENTS 来源覆盖表。
**Baseline**: INT-01/CB 等历史通过记录保留，GSD 完成阶段为 0。

## Phases

- [ ] **Phase 1: 神谕攻击选择与真实奖励** - 玩家击破矛盾后能在原战斗区域确认神谕，并取得一次真实奖励与休息结果。
- [ ] **Phase 2: 普通战斗规则与直播成长** - 玩家在真实战斗中体验特性风险与直播变化，胜利后的实际普通复读能累计到周目。
- [ ] **Phase 3: 休息、继承与多关推进** - 玩家能查看真实结算与收藏，带着已提交成果继续下一关，并在普通关结束后进入终局。
- [ ] **Phase 4: 神降临历史收束** - 玩家完成普通关后，已提交话语历史形成可操作的终局演出，锁句收束后提供冻结结果与结局交接请求。
- [ ] **Phase 5: 结局与整局闭环** - 玩家能从新游戏走到与整局结果一致的结局，空收藏和未击破路线均可完成。
- [ ] **Phase 6: 正式内容、视听与手感** - 玩家在完整流程中读到正式内容，看清玩法状态，并听到与各阶段一致的音乐及反馈。
- [ ] **Phase 7: Windows 与 Android 可交付版本** - 玩家能安装并运行 Windows 与 Android 构建，移动端可操作全部阶段并走完整局。

整数阶段为本里程碑计划工作，后续紧急插入使用小数阶段。所有阶段尚未创建执行计划。

## Phase Details

### Phase 1: 神谕攻击选择与真实奖励

**Goal**: 玩家击破矛盾后能在原战斗区域确认神谕，并取得一次真实奖励与休息结果。
**Depends on**: Nothing (first phase；复用已实现普通战斗、CB 与神谕数据入口)
**Requirements**: ORAC-01, ORAC-02, ORAC-03, ORAC-04, FANS-01
**Success Criteria** (what must be TRUE):

  1. 玩家通过真实攻击选择中央固定正文候选，多目标一发只确认最近的一句。（ORAC-01）
  2. 玩家能暂停选择倒计时；恢复后手动选择或等待 10 秒，均只提交一次。（ORAC-02）
  3. 玩家确认神谕后能从实际周目成果读到正确吞并内容与败者卡；未击破和重复确认符合奖励边界。（ORAC-03）
  4. 确认所得经文保留主播、原句、原章号与固定节号，倾向只提交普通命中所得，随后开放成功休息结果。（ORAC-04）
  5. 两个 PK 胜利分支都只增加一次粉丝，重复操作保持同一结果。（FANS-01）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [FO-13](<../docs/13. FinalOracle/tasks/FO-13_battle-area-attack-selection.md>) → FO-07/08/09 接线 → [FO-11](<../docs/13. FinalOracle/tasks/FO-11_rewards-integration.md>) → [FO-12](<../docs/13. FinalOracle/tasks/FO-12_to-rest.md>)；[LD-07](<../docs/9. LiveDataPresentation/tasks/LD-07_fan-settlement-once.md>)。
**已有基础与日志**: AUDIT-LATE；FO-01～09、SC-02～05、AS-02～05、LCARD-02～06 历史日志。
**任务边界**: 当前没有 FinalOracleScreen，按真实 BattleArea 与 FinalOracleSession 接线。FO-13 的非 neutral 候选非空保证为 TO VERIFY；沿第 8 节保留本卡边界，发现反例后按当前任务契约记录处理。

### Phase 2: 普通战斗规则与直播成长

**Goal**: 玩家在真实战斗中体验特性风险与直播变化，胜利后的实际普通复读能累计到周目。
**Depends on**: Phase 1
**Requirements**: BTTL-01, BTTL-02, BTTL-03, LIVD-01, LIVD-02, LIVD-03, HIST-01
**Success Criteria** (what must be TRUE):

  1. 玩家命中陷阱及制造单发多种异常时，能看到符合逐目标与整发规则的 PK 变化。（BTTL-01）
  2. 真实关卡可出现配置特性、非递归复制品和一次分裂的两个子句；矛盾阶段继续使用独立内容与特性边界。（BTTL-02、BTTL-03）
  3. 开播观看数来自单次倍率，正常命中、陷阱、升档和未击破均产生相应直播变化；复读命中保持零收益。（LIVD-01、LIVD-02）
  4. 击破及神谕短时上涨随阶段停止，玩家观看、点赞、评论保持正式边界。（LIVD-03）
  5. 胜利后查看周目普通复读计数能读到实际成功生成数；失败重开与重复提交保持正确来源和累计值。（HIST-01）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [HR-03](<../docs/6. HitResolution/tasks/HR-03_trap-penalties.md>)、BT-05/06/11/12、[HR-12](<../docs/6. HitResolution/tasks/HR-12_live-data-broadcast.md>)、LD-02/03/04/06/08、[RP-10](<../docs/10. Repeat/tasks/RP-10_commit-and-rollback.md>)、RP-12。
**已有基础与日志**: AUDIT-EARLY；INT-01 与 CB 集成日志；普通复读、本场直播与特性已有逻辑。
**任务边界**: 现有结果分类尚未扣分，复读本场字典尚未成为周目记录。敌方四项零值的正式拥有者与增长规则缺证据，保持 TO VERIFY，配置确认后归属 LIVD-02/PRES-02 当前任务。

### Phase 3: 休息、继承与多关推进

**Goal**: 玩家能查看真实结算与收藏，带着已提交成果继续下一关，并在普通关结束后进入终局。
**Depends on**: Phase 1, Phase 2
**Requirements**: REST-01, REST-02, REST-03, PROG-01, PROG-02, PROG-03, PROG-04, CONT-01
**Success Criteria** (what must be TRUE):

  1. 两个胜利分支都能打开休息页面，读取本场实际数据与成果；奖励为空仍能继续。（REST-01）
  2. 玩家可查看完整经文与败者卡历史，看到对应倾向环境；重看结果和切换输入保持一次结算。（REST-02、REST-03）
  3. 玩家可以完成已配置的后续关，同关重复继续保持一次推进，末关继续开放神降临入口并清零连败。（PROG-01、CONT-01）
  4. 进入后续关时已获得普通词库与允许继承的特性真正参与生成，当前对手的矛盾内容仍正确。（PROG-02）
  5. 玩家失败重开、保存/重读和开始新周目时，各类已提交与未提交成果遵守对应保留及重置规则。（PROG-03、PROG-04）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [RS-02～11 目录](<../docs/18. Rest/tasks/>)、SC-06、LCARD-07、TT-10、AS-06/07/08、[LC-07](<../docs/2. LevelConfiguration/tasks/LC-07_inherited-content.md>)、[LC-09](<../docs/2. LevelConfiguration/tasks/LC-09_rest-next-or-final.md>)、BT-13、OP-08/09。
**已有基础与日志**: AUDIT-EARLY/LATE；RS-01、LC-06、OP/SC/LCARD 保存与回滚日志。
**任务边界**: 此阶段交付到真实终局入口；神降临运行由 Phase 4 交付。后续关最小可玩内容在本阶段提供，完整正式内容归 Phase 6。

### Phase 4: 神降临历史收束

**Goal**: 玩家完成普通关后，已提交话语历史形成可操作的终局演出，锁句收束后提供冻结结果与结局交接请求。
**Depends on**: Phase 2, Phase 3
**Requirements**: DESC-01, DESC-02, DESC-03, DESC-04, DESC-05
**Success Criteria** (what must be TRUE):

  1. 玩家进入终局后，最终倾向与成果保持固定；演出只使用已提交的三倾向普通历史及正确普通复读权重。（DESC-01）
  2. 经文句只获得一次加权，最高权重并列时可按既定历史顺序核对锁定句。（DESC-02）
  3. 玩家能看到新话停止、自动复读扩散、锁定句占可见弹幕至少 90% 后收束，旧句按原截止时间结束。（DESC-03）
  4. 终局输入强化锁定句表现，普通 PK/倾向结算停止，雷弹幕被排除，强调结束后仅产生一次包含冻结结果的结局交接请求。（DESC-04）
  5. 圣典空但历史存在能完成演出；有效历史空时按既有契约结束终局并提供空态交接数据。（DESC-05）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [DD-01～16 目录](<../docs/19. DivineDescent/tasks/>)、[TT-11](<../docs/17. ThreeTendencies/tasks/TT-11_freeze-final.md>)、TT-12、RP-12、AS-09、SC-07。
**已有基础与日志**: AUDIT-LATE；当前只有 TT-13 筛选 helper，DD 运行 NOT IMPLEMENTED。
**任务边界**: 基础权重、一次圣典加成、90% 门槛均已有正式来源。新话衰减曲线与演出参数按当前 DD 任务契约确定。本阶段验收结果与交接请求；DD-17 要求真实 Ending 入口，实际接收、SceneRouter 转场和空态展示在 Phase 5 联调完成。

### Phase 5: 结局与整局闭环

**Goal**: 玩家能从新游戏走到与整局结果一致的结局，空收藏和未击破路线均可完成。
**Depends on**: Phase 4
**Requirements**: ENDG-01, ENDG-02, ENDG-03, FULL-01
**Success Criteria** (what must be TRUE):

  1. 结局教名可对应九种配置组合，身份判词按四类规则与冻结结果一致。（ENDG-01）
  2. 结局经文章序与节号正确，缺章和零收藏仍产生完整教名与判词。（ENDG-02）
  3. 玩家看到组合完成的结局页面，显示与输入保持最终结果不变。（ENDG-03）
  4. 人工运行可从新游戏走到结局，覆盖成功神谕、未击破和失败重开后的继续路线。（FULL-01）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [EN-01～09 目录](<../docs/20. Ending/tasks/>)、[DD-17](<../docs/19. DivineDescent/tasks/DD-17_to-ending.md>)、SC-08、TT-12；复用既有 [INT-01 测试入口](../tests/integration/int_01_playable_battle_sandbox_test.gd)。
**已有基础与日志**: AUDIT-LATE/SHARED；EN 数据与页面当前 NOT IMPLEMENTED，整局运行 UNVERIFIED。
**任务边界**: 先以可替换资源完成结局规则与页面，正式内容/视听在 Phase 6 验收；当前没有整局完成证据。

### Phase 6: 正式内容、视听与手感

**Goal**: 玩家在完整流程中读到正式内容，看清玩法状态，并听到与各阶段一致的音乐及反馈。
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5
**Requirements**: CONT-02, PRES-01, PRES-02, PRES-03, PRES-04, AUDI-01, BALN-01
**Success Criteria** (what must be TRUE):

  1. 玩家用正式关卡与奖励内容走完流程，当前配置的攻击、回拉、寿命和密度有试玩记录及来源。（CONT-02、BALN-01）
  2. 身份、玩家和各关对手资产及字体在现行 HUD 布局正确显示。（PRES-01）
  3. 战斗中的倾向、强度、特性、复读、PK/Tier 和直播数字反馈可辨认，实际视觉与命中区域一致。（PRES-02）
  4. 玩家能读清正式神谕/收藏/休息界面与终局/结局表现，缺章及空態与规则结果一致。（PRES-03、PRES-04）
  5. 实际运行可听见阶段音乐及反馈，升档、失败、奖励与 0.5 秒静音过渡按当前时序工作。（AUDI-01）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [AU-02](../docs/Shared/Audio/tasks/AU-02_music-state-transitions.md)、[PA-03](../docs/Shared/PresentationAssets/tasks/PA-03_battle-ui-art-integration.md)、CS-10、[Original 美术汇总](../docs/Original/美术需求汇总.md) 与对应系统正式规格。
**已有基础与日志**: AUDIT-SHARED；PA-01～03/INT-02/03/AU-01 历史交付。
**任务边界**: PA-03 已接玩家立绘、直播背景、粉丝牌三张素材；四张已入库 PNG 中的房间背景尚未使用。继续利用资源入口补正式内容。没有已证实的独立后续素材卡/调参卡 ID；计划须写明当前任务契约并沿用系统日志。

### Phase 7: Windows 与 Android 可交付版本

**Goal**: 玩家能安装并运行 Windows 与 Android 构建，移动端可操作全部阶段并走完整局。
**Depends on**: Phase 5, Phase 6
**Requirements**: MOBI-01, MOBI-02, SHIP-01, SHIP-02
**Success Criteria** (what must be TRUE):

  1. 玩家在 Android 使用真实触摸完成准心、蓄力、普通/矛盾攻击与神谕选择，暂停及阶段切换后输入有效。（MOBI-01）
  2. 目标设备的布局、文字、候选与命中范围可读可用，按明确设备条件记录整局性能结果。（MOBI-02）
  3. Windows 构建能在编辑器外启动并走到结局，失败重开可用，资源与日志符合验收。（SHIP-01）
  4. Android 构建可安装启动并走完整局，音频/字体/保存与新周目符合设备验收。（SHIP-02）
**Plans**: TBD
**UI hint**: yes

**任务卡入口**: [CA-12](<../docs/5. CombatAttack/tasks/CA-12_touch-input.md>)；平台导出、安装及交付卡当前无已证实 ID，规划时先形成具体任务契约。
**已有基础与日志**: AUDIT-SHARED；Windows 历史 GUI 运行与当前鼠标输入基础；导出/设备验收 UNVERIFIED。
**任务边界**: 包格式、签名、设备和性能目标按当前交付任务确定；仓库外构建状态未知。公开发布继续遵守用户授权范围。

## Progress

**Execution Order**: 1 → 2 → 3 → 4 → 5 → 6 → 7。显式依赖控制规划与验收顺序；已有 API 按当前任务复用，阶段计划中可安排依赖已满足的独立卡。

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. 神谕攻击选择与真实奖励 | 0/TBD | Not started | - |
| 2. 普通战斗规则与直播成长 | 0/TBD | Not started | - |
| 3. 休息、继承与多关推进 | 0/TBD | Not started | - |
| 4. 神降临历史收束 | 0/TBD | Not started | - |
| 5. 结局与整局闭环 | 0/TBD | Not started | - |
| 6. 正式内容、视听与手感 | 0/TBD | Not started | - |
| 7. Windows 与 Android 可交付版本 | 0/TBD | Not started | - |

Phase 1 为 Ready to plan；其他阶段等待上游能力。现有完成卡与历史日志只作为基准，阶段完成后再按实际验收更新本表。

## Planning Contract

- PLAN 指向 [任务索引](onboarding/TASK-INVENTORY.json) 中真实卡、正式系统规格与最新日志；每张卡以最新源码核销缺口。
- FO-10/SC-02、TT-09/FO-09 复用现有交付；AS-07 只补实际保留矩阵缺口。
- 旧阻塞日志保持历史原文，收尾记在对应系统当次日志及正式现状。
- 素材、完整复制生成、后续内容与平台导出尚缺独立已证实卡 ID 的范围，在规划时形成具体当前任务契约。
- 集成以最小 runtime smoke 和人工 UAT 为主；复用 INT-01/现有纯逻辑入口，按当前任务预算验证。
- 本轮没有运行 Godot 或游戏测试；整局、当前 checkout 和导出/设备结果均待实际验证。

---
*Last updated: 2026-10-08 after existing-project onboarding*
