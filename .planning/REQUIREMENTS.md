# Requirements: Empty-start

**Defined:** 2026-10-08
**Core Value:** 核心玩法实际运行，玩家从新游戏走完整局到结局，并保有可继续集成和测试的稳定版本。

## Evidence Boundary

本文件定义 **40 条剩余 v1 验收需求**，复用已有基础后完成玩家流程。全部处于 Pending；只有对应实现、实际验证与任务交付完成后才能勾选。既有能力与历史运行见 PROJECT 和三份 onboarding 审计，当前 checkout 运行 **UNVERIFIED**。

[原始需求索引](intel/requirements.md) 的 **40 个分组**为另一套来源 ID，覆盖 19 个程序系统、19 个美术系统与数值/视听各一组。下方保存完整分组覆盖；本文件聚合剩余工作，卡级条款回读正式规格与 [222 张任务卡索引](onboarding/TASK-INVENTORY.json)。155 张日志匹配代表历史证据。

## v1 Requirements

### 神谕攻击选择与真实奖励

- [ ] **ORAC-01**: 玩家能在保留原 HUD 的中央主游戏区，用现有准心、蓄力与发射选择 1～3 条固定真实正文候选；同发覆盖多句时取中心最近的一句。
  来源：FO-13；FO-01～06 为既有候选基础。

- [ ] **ORAC-02**: 候选可操作后开始 10 秒倒计时，全局暂停冻结；手动或超时自动选择走同一个确认入口，本场只确认一次。
  来源：FO-07/08/09、FO-13。

- [ ] **ORAC-03**: 真实神谕确认后，玩家获得符合配置资格的吞并词库、继承特性与败者卡；同关重复确认保持已发成果，未击破关卡没有这些新奖励。
  来源：FO-11、AS-02～06、LCARD-02～06；奖励配置待补。

- [ ] **ORAC-04**: 神谕确认后保留正确来源的固定节号经文，提交本场普通历史与倾向，神谕额外倾向为零，并只生成一次成功休息结果。
  来源：FO-12；复用 FO-10/SC-02、TT-09/FO-09、HR-15/TT-03。

- [ ] **FANS-01**: 每场 PK 胜利只结算一次新增粉丝；矛盾未击破也结算，确认或重看结果保持已结算粉丝。
  来源：LD-07；真实最终结果节点、RS-08；增量配置 TO VERIFY。

### 普通战斗规则与直播成长

- [ ] **BTTL-01**: 命中正式陷阱时按配置扣除 PK 并跳过普通收益；同发反弹、遮挡、落空按既定优先级合计最多结算一次异常惩罚。
  来源：HR-03、BT-11；HitResolution 与 Original 数值来源。

- [ ] **BTTL-02**: 关卡配置的普通特性能分配到真实实例；复制品实际生成、保留来源且禁止继续复制，矛盾阶段排除普通陷阱特性。
  来源：BG/BT 正式规格、BT-05/12；BT-05 已交付仅标记，完整复制生成须落实当前任务契约。

- [ ] **BTTL-03**: 触发分裂时母体结束且仅生成两个独立原句子话语，子句使用配置的倾向和强度并继承母体截止时间，同一母体只触发一次。
  来源：BT-06；复用 BarrageGeneration 正式生成入口。

- [ ] **LIVD-01**: 开播观看人数按当前粉丝数与本次只抽取一次的配置倍率计算为非负整数，重开按本关开播规则重新初始化。
  来源：LD-02/08；起始粉丝、倍率范围 TO VERIFY。

- [ ] **LIVD-02**: 真实普通命中、陷阱命中、Tier 变化与未击破结果按配置影响观看和点赞；复读命中维持零收益，评论按实际生成计数。
  来源：HR-12、LD-03/04/05；增长参数 TO VERIFY。

- [ ] **LIVD-03**: 击破与神谕阶段触发配置的短时直播上涨，阶段结束停止对应增量；四项显示保持既定非负和累积边界。
  来源：LD-06、LD-01/09。

- [ ] **HIST-01**: 玩家每关 PK 胜利后，实际生成的普通复读按原句一次提交到周目；失败重开撤回本次未提交计数，矛盾复读保持独立。
  来源：RP-10/12；复用本场 RepeatGenerationStats 与最终结果节点。

### 休息、继承与多关推进

- [ ] **REST-01**: 休息页面展示真实本场直播结果、新经文、新败者卡与吞并成果；未击破显示对应说明，无新奖励显示空态并保留继续入口。
  来源：RS-02/03/04、LD-10、AS-08。

- [ ] **REST-02**: 玩家在休息阶段可查看完整圣典与败者卡历史，圣典保留缺章和固定节号，环境读取当前三项倾向的正式结果。
  来源：RS-05/06/07、SC-06、LCARD-07、TT-10。

- [ ] **REST-03**: 重复打开休息只读取既有快照与成果；阶段切换正确停止战斗输入，并开放当前休息操作。
  来源：RS-08/11；复用 RS-01 首次快照基础。

- [ ] **PROG-01**: 玩家从两个胜利分支的休息继续下一名主播；同关只推进一次，最后普通关结束后开放神降临入口，并在完成节点清零连败。
  来源：RS-09/10、LC-06/09、OP-09。

- [ ] **PROG-02**: 进入后续关卡时，已取得且允许继承的普通词库按登记权重参与生成，继承特性按明确规则装到实例；当前对手矛盾词库保持独立。
  来源：LC-07、AS-06、BT-13；稳定 pool_id、权重与继承许可待配置。

- [ ] **PROG-03**: 玩家当前关失败重开时保留此前提交的吞并、圣典、败者卡、粉丝与历史，撤回本次未提交成果并重置本场战斗数据。
  来源：OP-07/08、AS-07、HR-15、RP-10、SC-05、LD-08。

- [ ] **PROG-04**: 已提交周目成果在既定保存/读取入口中保留；开始新周目按现有规则清空周目结果并初始化身份与关卡。
  来源：SaveData/SaveManager、AS/SC/LCARD 保存任务、ID-06/07、LCARD-06；实际组合 TO VERIFY。

- [ ] **CONT-01**: 当前关卡目录中的后续普通关有可生成的话语、类别配置与真假矛盾，玩家继续后能够实际开战并走到本关结果。
  来源：LC-01～06、BG/CB；level_002 当前空内容，内容补齐尚无独立已证实任务卡 ID。

### 神降临历史收束

- [ ] **DESC-01**: 进入神降临时冻结最终三项倾向与整局成果，候选仅取已提交的三倾向普通原句历史，并用普通命中数加实际普通复读数形成最低为一的基础权重。
  来源：TT-11/12、RP-12、DD-01/02/03/06；复用 TT-13 neutral 筛选。

- [ ] **DESC-02**: 圣典句按候选池最大基础权重获得一次加成，同句多章只加一次；最高权重并列按首次已提交命中顺序及稳定原句 ID 锁句。
  来源：SC-07、DD-07/09/10。

- [ ] **DESC-03**: 终局新话率逐渐降到零，自动复读按权重扩散并动态加权；锁句后只生成目标原句，非空可见弹幕中其占比达到 90% 后收束，旧句截止时间保持原值。
  来源：DD-05/08/11/12/13/16。

- [ ] **DESC-04**: 神降临停用普通战斗结算，禁止雷弹幕，继承特性仅作表现；锁句后的输入只强化画面与声音，最终强调后仅产生一次包含冻结结果的结局交接请求。
  来源：DD-04/14/16/17、AS-09、TT-12。Phase 4 交付数据与请求；DD-17 的真实页面接收及转场由 Phase 5 的 ENDG-03/FULL-01 完成。

- [ ] **DESC-05**: 圣典为空时仍以已提交普通历史运行终局；有效历史也为空时按既有契约结束终局并提供空态交接数据，结局展示由 ENDG-02/03 接收。
  来源：DD-15、SC-07；neutral 排除后空候选按该正式契约处理。

### 结局与整局闭环

- [ ] **ENDG-01**: 结局按冻结的主导/次要倾向映射三种纯与六种混合教名，并按开局身份与最终倾向生成一致、偏移、并列或无行为判词。
  来源：EN-01/02/03/05/06；教名与判词从配置读取。

- [ ] **ENDG-02**: 结局按原章序展示完整圣典及缺章，沿用固定节号；圣典、败者卡或吞并全空时仍展示教名与判词并完成。
  来源：EN-04/07/09、SC-08。

- [ ] **ENDG-03**: 结局页面组合教派主图、教名、玩家来源信息、经文和判词，并只读取固定终局结果，显示过程保持最终倾向不变。
  来源：EN-01/02/08、TT-12、ID-06/07；正式美术资产归 PRES-04。

- [ ] **FULL-01**: 玩家能从主菜单新游戏经身份、普通战斗、矛盾结果、休息、多关与神降临到结局；击破和未击破路线都可完成，失败重开后仍能继续完整流程。
  来源：AGENTS 项目目标、INT-01/CB 既有集成入口、LC/RS/EN 当前任务及 DD-17 真实结局交接。

### 正式内容、视听与手感

- [ ] **CONT-02**: 正式关卡、主播、普通话语及 neutral 内容、真假矛盾与线索替换示例配置，奖励词库、继承许可和败者卡资料齐备，并按当前关卡目录完成整局。
  来源：Original 程序/美术汇总、LC/BG/CB/AS/LCARD 正式规格；正式内容数量由当前任务确定。

- [ ] **PRES-01**: 身份名称/图标、玩家与对手立绘/头像/背景/粉丝牌、字体及直播指标素材在实际页面正确读取，保留现有共享 Resource 与 Theme 可替换入口。
  来源：PA-01～03、ID/LC/LD 正式规格、对应 Original 美术范围。

- [ ] **PRES-02**: 玩家能用正式颜色、标记与反馈区分话语倾向/强度、复读/矛盾/特性、PK/Tier/准心/蓄力及直播数字变化，并在现行布局中读清状态。
  来源：Original 美术 3～10/12、CS-10、LD-09、PA-03、INT-02/03。

- [ ] **PRES-03**: 神谕、吞并、经文、败者卡与休息倾向环境使用正式页面素材和展示样式，真实收藏、缺章及空态清晰可读。
  来源：Original 美术 13～18、SC-06、LCARD-07、RS、TT-10。

- [ ] **PRES-04**: 神降临扩散/锁句/收束与结局主图、九种教名样式、经文和判词使用正式表现资源，动画保持实际规则时序。
  来源：Original 美术 19/20、DD-14/17、EN-02/08。

- [ ] **AUDI-01**: 菜单、普通战斗分层、矛盾、神谕、休息、终局与结局切换对应音乐和反馈；升档/失败/奖励音效及共用 0.5 秒静音过渡可实际听见，暂停恢复保持阶段一致。
  来源：AU-01/02、CS-10、CB 正式规格、Original 视听条款；正式素材待提供。

- [ ] **BALN-01**: 玩家能用明确标注来源的可调配置完成整局；攻击时长、回拉、按类型寿命、生成密度和容量经实际试玩记录当前取值及未定项，停止把临时默认描述为最终平衡。
  来源：Original 数值表、当前试玩配置、相关任务卡；正式数值 TO VERIFY。

### Windows 与 Android 可交付版本

- [ ] **MOBI-01**: Android 玩家能用触摸移动准心、开始/取消/释放蓄力，并完成普通攻击、矛盾击破和神谕攻击选择；阶段与暂停切换正确处理输入。
  来源：CA-12、FO-13、RS-11；当前源码只有直接鼠标输入。

- [ ] **MOBI-02**: 目标 Android 设备上 HUD、候选、收藏、结局与中文/Emoji 字体可读，视觉与触摸命中相符，整局性能达到当前任务明确的设备验收条件。
  来源：CA-12、LD-09、INT-02/03、Shared 表现规格；目标设备与性能门槛 TO VERIFY。

- [ ] **SHIP-01**: Windows 导出配置和可交付构建存在，玩家在编辑器外启动构建后能完成开局、战斗、失败重开与结局，运行日志无本任务新增错误。
  来源：AGENTS、AUDIT-SHARED；仓库未见 export_presets.cfg 或构建，正式导出任务卡 ID 待建立。

- [ ] **SHIP-02**: Android 导出配置与可安装构建存在，在目标设备安装启动并完成触摸整局，字体/资源/音频可用，保存与新周目边界经设备验收。
  来源：Windows/Android 任务目标、CA-12、AUDIT-SHARED；正式平台交付卡 ID 待建立。

## Baseline Reconciliation

| 范围 | 当前事实 | 剩余交付处理 |
|------|----------|--------------|
| FO-10 / SC-02 | 来源解析、真实确认、经文首次写入与去重已存在 | ORAC-04 复用接线，补成功结果生命周期与玩家验收 |
| TT-09 / FO-09 | 神谕零额外倾向已存在；普通本场提交已接 | ORAC-04 复用，验收选择只提交既有普通收益 |
| AS-07 / OP-08 | 重开保留同一 SaveData，已验证过先前击败 ID | PROG-03/04 补真实词库/特性/圣典/卡片全部保留矩阵 |
| RS-08 / RS-01 | 首次打开冻结快照、拒绝覆盖已有 | REST-03 补实际 UI 重看与奖励一次提交验收 |
| 旧阻塞任务 | LC-08、BG-09/13、HR-10/11、OP-06/07、LD-08、RP-07 后续已集成 | 保留旧日志，当前卡按最新代码核销，避免重复实现 |
| CS-11/12、CA-10、HR-13、BT-10/12 等 | 部分缺独立日志，行为已有集成证据 | 核对剩余验收与交付记录，缺日志单独记录 |

## Original Source Coverage

全部 28 份分类已由 [SYNTHESIS](intel/SYNTHESIS.md) 消费，文档路由 [冲突报告](INGEST-CONFLICTS.md) 为 0 BLOCKERS / 0 WARNINGS / 8 INFO。Original 15～20 系统案正文缺失，后段使用真实程序/美术汇总与正式 SPEC。

下表覆盖每个来源分组。已有基础保持原验收边界，剩余需求只承担实际缺口；完整条款与细项仍由原稿、系统文档和任务索引保存。表内缩写如 PROG-01/02 指两个独立既有需求 ID。

| 来源分组 ID | 已有基础/缺口 | 剩余验收归属 |
|-------------|---------------|--------------|
| REQ-program-identify | ID-01～07 开局/存读已有 | PRES-01、PROG-04、FULL-01 |
| REQ-program-level-configuration | LC-01～06 与同关重开已有 | PROG-01/02、CONT-01/02 |
| REQ-program-barrage-generation | 普通/复读/CB 生成与暂停已有 | BTTL-02/03、PROG-02、CONT-01/02、BALN-01 |
| REQ-program-barrage-traits | 结果、兼容与复制品标记已有 | BTTL-01/02/03、PROG-02 |
| REQ-program-combat-attack | 普通/矛盾鼠标攻击已有 | ORAC-01/02、MOBI-01/02 |
| REQ-program-hit-resolution | 普通整发、历史/提交回滚已有 | BTTL-01、LIVD-02、PROG-03 |
| REQ-program-opponent-pk-bar | 回拉、失败锁与重开已有 | PROG-01/03/04、FULL-01 |
| REQ-program-combat-stage | Tier 与真实 CB 交接已有 | LIVD-02、PRES-02、AUDI-01、FULL-01 |
| REQ-program-live-data | 本场数据/HUD/评论与重开已有 | FANS-01、LIVD-01/02/03、REST-01、PRES-02 |
| REQ-program-repeat | 计划/队列与本场统计已有 | HIST-01、DESC-01、PRES-02 |
| REQ-program-contradiction-break | CB-01～12 真实入口已有 | ORAC-01～04、LIVD-03、FULL-01、AUDI-01 |
| REQ-program-final-oracle | FO-01～09 逻辑与 SC-02 接线已有 | ORAC-01～04、PRES-03 |
| REQ-program-assimilation | AS-01～05 数据已有，AS-07 基础部分已有 | ORAC-03、PROG-02/03/04、REST-01、DESC-04 |
| REQ-program-scripture | SC-01～05 记录/真实确认已有 | ORAC-04、REST-02、PROG-03/04、DESC-02、ENDG-02 |
| REQ-program-loser-card | LCARD-01～06 数据与保存已有，资料空 | ORAC-03、REST-02、PROG-03/04、CONT-02 |
| REQ-program-three-tendencies | TT-01～09/13/14 当前能力已有 | ORAC-04、REST-02、DESC-01/04、ENDG-01/03 |
| REQ-program-rest | RS-01 会话快照已有 | REST-01/02/03、PROG-01 |
| REQ-program-divine-descent | TT-13 筛选 helper 已有，DD 运行缺失 | DESC-01～05 |
| REQ-program-ending | 正式规格/任务卡已有，EN 运行缺失 | ENDG-01/02/03、FULL-01 |
| REQ-art-identify | 三身份正式图标/名称仍缺 | PRES-01 |
| REQ-art-level-configuration | 玩家素材入口已有，对手资料缺 | CONT-02、PRES-01 |
| REQ-art-barrage-generation | 基础话语视图已有 | PRES-02 |
| REQ-art-barrage-traits | 标记/结果已有，正式表现待补 | PRES-02 |
| REQ-art-combat-attack | 32 设计像素准心与基础演出已有 | PRES-02、MOBI-02 |
| REQ-art-hit-resolution | 基本战斗反馈已有 | PRES-02 |
| REQ-art-opponent-pk-bar | PK/失败重开入口已有 | PRES-02 |
| REQ-art-combat-stage | Tier 广播/升档音效入口已有 | PRES-02、AUDI-01 |
| REQ-art-live-data | 富文本 HUD 已有，ICON/动画待补 | PRES-01/02、MOBI-02 |
| REQ-art-repeat | 延迟生成已有，正式节奏待验收 | PRES-02、AUDI-01 |
| REQ-art-contradiction-break | 真实阶段已有，正式手感/音效待验收 | PRES-02、AUDI-01 |
| REQ-art-final-oracle | 尚无玩家神谕展示 | PRES-03 |
| REQ-art-assimilation | 数据已有，正式吸收展示待补 | PRES-03、AUDI-01 |
| REQ-art-scripture | 数据已有，正式书页展示待补 | PRES-03/04 |
| REQ-art-loser-card | 卡片资料/展示待补 | CONT-02、PRES-03 |
| REQ-art-three-tendencies | 倾向数据已有，环境/终局表现待补 | PRES-03/04 |
| REQ-art-rest | 结果快照已有，正式页面待补 | PRES-03 |
| REQ-art-divine-descent | DD 演出尚未实现 | PRES-04、AUDI-01 |
| REQ-art-ending | EN 页面/主图尚未实现 | PRES-04 |
| REQ-original-balance | 现有试玩值有来源，最终取值待确认 | BTTL-01、BALN-01 |
| REQ-original-audiovisual | AU-01 占位音效/事件入口已有 | AUDI-01、PRES-02/03/04 |

## v2 Requirements

尚无已确定的 v2 范围。新内容按任务实际决定后登记；本轮没有从 v1 自动删减来源需求。

## Out of Scope

| 范围 | 原因 |
|------|------|
| 本次 onboarding 执行玩法代码、创建产品素材或发布构建 | 本轮授权范围为接手与规划骨架 |
| 重写既有候选、经文、收藏或普通结算数据规则 | 当前实现有可复用证据，按实际缺口交付 |
| 原始文档迁移或覆盖 | AGENTS 要求 Original 留存，规则变更记录于正式系统目录 |
| 无明确风险的广泛测试设施与架构扩展 | 遵循项目任务预算与最小可玩目标 |

## Assumptions To Verify

- FO-13 当前没有 FinalOracleScreen，交互基于 BattleArea；有效非 neutral 候选保证按任务第 8 节待真实联调检查，本轮未新增零候选规则。
- 起始粉丝、开播随机倍率范围、观看/点赞/阶段增量及新增粉丝规则待配置；敌方数据归属/增长缺证据，规划时按当前任务契约处理。
- 继承 pool_id、appearance_weight、can_inherit 与特性许可需要正式来源，现有 special_trait_ids 只描述本关使用特性。
- BT-05 当前卡仅交付复制品状态；完整复制生成、后续关/正式素材/调参与平台导出范围尚缺独立已证实任务卡 ID。
- Shared Debug 日志提及另外两张卡，索引只确认 DBG-01；原卡缺失保留为待补来源。
- 正式名称、截止日期、敌方公式、额外关卡数量和设备性能指标缺来源，维持待定。

## Traceability

每条剩余 v1 需求恰好映射一个阶段；以下状态表示本次 GSD 交付，已有系统实现见基准。

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORAC-01 | Phase 1 | Pending |
| ORAC-02 | Phase 1 | Pending |
| ORAC-03 | Phase 1 | Pending |
| ORAC-04 | Phase 1 | Pending |
| FANS-01 | Phase 1 | Pending |
| BTTL-01 | Phase 2 | Pending |
| BTTL-02 | Phase 2 | Pending |
| BTTL-03 | Phase 2 | Pending |
| LIVD-01 | Phase 2 | Pending |
| LIVD-02 | Phase 2 | Pending |
| LIVD-03 | Phase 2 | Pending |
| HIST-01 | Phase 2 | Pending |
| REST-01 | Phase 3 | Pending |
| REST-02 | Phase 3 | Pending |
| REST-03 | Phase 3 | Pending |
| PROG-01 | Phase 3 | Pending |
| PROG-02 | Phase 3 | Pending |
| PROG-03 | Phase 3 | Pending |
| PROG-04 | Phase 3 | Pending |
| CONT-01 | Phase 3 | Pending |
| DESC-01 | Phase 4 | Pending |
| DESC-02 | Phase 4 | Pending |
| DESC-03 | Phase 4 | Pending |
| DESC-04 | Phase 4 | Pending |
| DESC-05 | Phase 4 | Pending |
| ENDG-01 | Phase 5 | Pending |
| ENDG-02 | Phase 5 | Pending |
| ENDG-03 | Phase 5 | Pending |
| FULL-01 | Phase 5 | Pending |
| CONT-02 | Phase 6 | Pending |
| PRES-01 | Phase 6 | Pending |
| PRES-02 | Phase 6 | Pending |
| PRES-03 | Phase 6 | Pending |
| PRES-04 | Phase 6 | Pending |
| AUDI-01 | Phase 6 | Pending |
| BALN-01 | Phase 6 | Pending |
| MOBI-01 | Phase 7 | Pending |
| MOBI-02 | Phase 7 | Pending |
| SHIP-01 | Phase 7 | Pending |
| SHIP-02 | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0
- Duplicate phase assignments: 0
- Original groups covered: 40/40

---
*Requirements defined: 2026-10-08*
*Last updated: 2026-10-08 after existing-project onboarding*
