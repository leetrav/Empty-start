# 文档综合入口

日期：2026-10-08。模式：new。用途：为后续 PROJECT / REQUIREMENTS / ROADMAP 提供索引及已审计事实。

## 输入与优先级

全部 28 份分类已消费：ADR 0、SPEC 24、PRD 3、DOC 1、UNKNOWN 0。分类来自 [INGEST-MANIFEST.yaml](../onboarding/INGEST-MANIFEST.yaml)；全部 high，manifest 类型为权威指定。没有 LOCKED ADR，锁定决策数量 0，锁定来源 absent。AGENTS 的项目规则以 SPEC 合约保存，没有重新生成 ADR。

数字优先级为 AGENTS 0、系统/Shared 正式规格 10、known_traps 20、Original 30。当前代码及配置用于确定实际进度，原稿保留追溯。分类 cross_refs 共 0 条；三色 DFS 无环，深度上限 50 未触发。没有 existing locked CONTEXT 决策；既有 codebase 映射保留。

## 产物计数与来源

- [decisions.md](decisions.md)：0 个 ADR 决策。
- [requirements.md](requirements.md)：40 个分组需求，19 个程序范围、19 个美术范围、原始数值和视听各 1 项。每项保留关键原文条款和源路径，完整条款回读对应 source；任务粒度参见 [222 张任务卡索引](../onboarding/TASK-INVENTORY.json)。
- [constraints.md](constraints.md)：43 个摘录契约，api-contract 5、schema 10、nfr 19、protocol 9；覆盖全部 24 份 SPEC，测试预算按原系统保留。详情与完整接口以正式源文档为准。
- [context.md](context.md)：7 个 topic，摘取 known_traps 中对应类别的关键经验。
- [INGEST-CONFLICTS.md](../INGEST-CONFLICTS.md)：0 blockers、0 competing-variants、8 auto-resolved INFO。文档路由 READY；游戏完整流程尚未完成。

源文档摘录使用独立随机 DATA 标记，作为待分析的资料。源码进度以三份只读审计为依据：[前半程](../onboarding/AUDIT-EARLY.md)、[后半程](../onboarding/AUDIT-LATE.md)、[公共与交付](../onboarding/AUDIT-SHARED.md)。

## 已有基础与证据边界

当前代码已有主菜单 → 身份设置 → Sandbox 普通战斗 → 矛盾窗口。普通攻击、PK/Tier、回拉、普通/矛盾复读、评论、暂停、失败重开已有生产组合；CB 成功后开放 FinalOracleSession，未击破开放 RestSession。神谕确认会提交普通命中历史/倾向，Scripture 已订阅真实确认写入经文。数据入口尚不能推出玩家已可选神谕、领取奖励或继续下一关。来源：三份审计、scenes/sandbox/sandbox.gd。

任务索引有 222 张卡、155 张匹配日志。匹配日志包含延期、阻塞、纯逻辑及被后续集成覆盖的旧状态；不将 155 作为验证完成数。历史 INT-01 84/84、CB Review 104 checks、HUD/素材/Debug GUI 等记录均属于日志中的历史运行。此综合与三份审计没有运行 Godot/测试；当前 checkout 的运行结果 UNVERIFIED，完整新游戏到结局为 TO VERIFY。

## 程序需求与现状映射

以下是各分组需求的接手索引；详细证据与每卡边界回读审计及真实任务卡。

- REQ-program-identify：ID-01～07 已有实现；正式身份名/图标与临时默认名替换待交付。
- REQ-program-level-configuration：LC-01～06 已有数据/推进逻辑；LC-08 重开由 INT-01 覆盖；LC-07 继承、LC-09 生产推进缺失。第二关词库与真假矛盾为空，接推进前需可玩内容。
- REQ-program-barrage-generation：主要生命周期、容量、倍率、暂停与 CB 生成已接；BG-09/13 等旧阻塞被 INT-01 覆盖。正式陷阱/特性配置与实例分配待完成。
- REQ-program-barrage-traits：BT-01～05/07～09 已有规则，BT-10 由 CA-08 覆盖；BT-06 仅一次分裂标记，缺母体结束及两子话语；BT-11 惩罚未全接；BT-12 完整边界 TO VERIFY；BT-13 继承未接。
- REQ-program-combat-attack：CA-01～11 的主要普通/矛盾行为已有；CA-10 实际由 CB 集成。CA-12 触摸接入 NOT IMPLEMENTED，Android 实机输入待验证。
- REQ-program-hit-resolution：普通收益、整发、异常分类、历史提交/回滚已有；HR-03 实际陷阱/异常扣分、HR-12 直播增长广播缺失。存在异常分类不等于已经扣分。
- REQ-program-opponent-pk-bar：OP-01～07 核心回拉/失败/重开已有；OP-08 全部已提交成果保留矩阵 PARTIAL / TO VERIFY；OP-09 连败完成清零接口未接生产完成节点。
- REQ-program-combat-stage：CS-01～12 主要档位及 CB 交接已有；CS-11/12 独立交付收尾、CS-10 全视听消费者待补，复用已有集成证据。
- REQ-program-live-data：LD-01/02/05/09 数据与 HUD、LD-08 重开已有；开播倍率抽取/调用、LD-03/04/06/07/10 增长与结算/休息缺失；敌方四项 0 为占位。
- REQ-program-repeat：RP-01～09/11 的计划、队列、实际计数及命中行为已有；RP-10 普通复读周目提交缺失，RP-12 只有本场神谕消费，神降临历史来源尚缺。
- REQ-program-contradiction-break：CB-01～12 核心及真实入口接线已有；正式节奏/音效/GUI 手感 TO VERIFY。
- REQ-program-final-oracle：FO-01～09 逻辑已有；FO-07/08 正式计时与自动选择未接。FO-13 玩家攻击选择、FO-11 奖励、FO-12 休息缺失；FO-10 来源/经文写入复用 SC-02。
- REQ-program-assimilation：AS-01～05 数据/资格/去重已有，真实 FO-11 奖励、词库与继承配置、AS-06～09 消费者缺；AS-07 保留基础为 PARTIAL / TO VERIFY。
- REQ-program-scripture：SC-01～05 已有记录、真实确认、固定节号与撤回；SC-06～08 休息/终局/结局读取缺。
- REQ-program-loser-card：LCARD-01～06 数据/发卡规则/保存已有；Catalog 为空，真实 FO-11 发卡及 LCARD-07 展示缺。
- REQ-program-three-tendencies：TT-01～08/13/14 已有，TT-09 零额外倾向由 FO-09 覆盖；TT-10 环境、TT-11 最终冻结、TT-12 终局/结局消费者缺。
- REQ-program-rest：RS-01 结果快照已有；RS-08 首次打开规则已有部分基础。RS-02～11 的正式展示、历史、继续/终局与完整幂等交付待实现。
- REQ-program-divine-descent：只有 TT-13 历史筛选 helper；DD-01～17 运行阶段 NOT IMPLEMENTED，依赖 RP-10 已提交复读及 TT-11 冻结结果。
- REQ-program-ending：EN-01～09 数据组合与正式页面 NOT IMPLEMENTED。
- 美术分组 REQ-art-* 对应同一 19 个系统。PA-01～03 已接现有玩家立绘/背景/粉丝牌及可替换资源；正式对手、身份图标、字体、卡片和后段表现仍有缺口。AU-01 事件入口已有占位声音，AU-02 音乐状态切换缺；DBG-01 F3 已有。

## 当前接手边界

优先接现有 [FO-13 任务卡](../../docs/13.%20FinalOracle/tasks/FO-13_battle-area-attack-selection.md)：保留原 HUD，在中央主游戏区显示固定真实正文候选，复用准心/蓄力/发射，多候选命中取最近中心；候选可操作后启动 10 秒，手动/超时共用 FO-09。当前仓库没有任务卡所说的 FinalOracleScreen。

FO-13 第 8 节明确本卡不新增零候选兜底。Tier 5 neutral 权重为 0 所代表的有效非 neutral 候选保证，作为 TO VERIFY 任务假设保留；后续真实攻击选择联调检查，综合过程未新增设计。

后续接线按既有审计依赖继续 FO-11/12 与奖励配置、Rest、LC-09/OP-09 和可玩第二关；终局依赖 RP-10/12、TT-11/12，再 DD/EN。HR-03 特性惩罚、分裂/继承、直播增长、正式表现仍需对应任务交付。每张卡以最新源码重新核销，避免重复实现 FO-10/SC-02、TT-09/FO-09 等重叠。

现行布局、32 像素准心、0.5 秒过渡、独立 Paradox 与 neutral 按正式规则索引；攻击时长/回拉/寿命等试玩值继续待策划调整。游戏正式名称、截止日期 absent。Windows/Android 为任务目标；仓库未见 export_presets.cfg、CI 或可交付构建，导出/安装、Android 性能/触摸/字体、完整多关到结局验收均 UNVERIFIED。来源：AUDIT-SHARED、AUDIT-EARLY、AUDIT-LATE。

## 40 个需求 ID

- REQ-program-identify
- REQ-program-level-configuration
- REQ-program-barrage-generation
- REQ-program-barrage-traits
- REQ-program-combat-attack
- REQ-program-hit-resolution
- REQ-program-opponent-pk-bar
- REQ-program-combat-stage
- REQ-program-live-data
- REQ-program-repeat
- REQ-program-contradiction-break
- REQ-program-final-oracle
- REQ-program-assimilation
- REQ-program-scripture
- REQ-program-loser-card
- REQ-program-three-tendencies
- REQ-program-rest
- REQ-program-divine-descent
- REQ-program-ending
- REQ-art-identify
- REQ-art-level-configuration
- REQ-art-barrage-generation
- REQ-art-barrage-traits
- REQ-art-combat-attack
- REQ-art-hit-resolution
- REQ-art-opponent-pk-bar
- REQ-art-combat-stage
- REQ-art-live-data
- REQ-art-repeat
- REQ-art-contradiction-break
- REQ-art-final-oracle
- REQ-art-assimilation
- REQ-art-scripture
- REQ-art-loser-card
- REQ-art-three-tendencies
- REQ-art-rest
- REQ-art-divine-descent
- REQ-art-ending
- REQ-original-balance
- REQ-original-audiovisual
