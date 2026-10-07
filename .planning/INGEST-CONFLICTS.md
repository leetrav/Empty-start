## Conflict Detection Report

### BLOCKERS (0)

无。28 份分类均为 high；没有 ADR、LOCKED 或 UNKNOWN。分类 cross_refs 共 0 条；三色 DFS 完成，无循环，未超过深度 50。

### WARNINGS (0)

无。同系统的程序与美术条款为不同交付范围；系统案对应程序/美术段落与两份汇总在去除排版及优先级列后逐条一致，没有竞争验收版本。

### INFO (8)

[INFO] Auto-resolved: 现行静态 Scene 布局覆盖 Original 区域尺寸
  Found: Original 的特殊道具框 448×224、直播数据区 448×296；历史 BG-14 曾运行时改区域。
  Note: Shared 与 BarrageGeneration 正式规格采用左右 128/432/520、中央 72/760/248；StageLayoutProfile 保存规格，Sandbox Scene 保存 Rect，HUD 运行时整体缩放。以 precedence 10 规格覆盖 precedence 30 原稿，历史要求保留追溯。
  source: docs/Original/系统案_协作交付版_文本导出.md#各数值表; docs/Shared/README.md; docs/3. BarrageGeneration/README.md; .planning/onboarding/AUDIT-SHARED.md; data/stage_layout/stage_layout_profile.tres; scenes/sandbox/sandbox.tscn

[INFO] Auto-resolved: 准心当前采用共用 32 设计像素直径
  Found: Original 准心视觉 96、PC 判定 144、手机判定 180。
  Note: precedence 10 CombatAttack 规格与当前代码统一绘制/判定直径 32；原稿值作为历史记录。Android 触摸及尺寸适配仍未完成，当前规则不会推出移动端已验收。
  source: docs/Original/系统案_协作交付版_文本导出.md#各数值表; docs/5. CombatAttack/README.md; systems/combat_attack/aim_reticle.gd; .planning/onboarding/AUDIT-SHARED.md

[INFO] Auto-resolved: 击破后共用静音过渡为 0.5 秒
  Found: Original 13 系统音乐需求写共用一次 1 秒静音过渡。
  Note: precedence 10 ContradictionBreak 规格及当前 Sandbox 使用 0.5 秒可暂停过渡；等待实际矛盾复读队列与可见复读结束后开放神谕。
  source: docs/Original/系统案_协作交付版_文本导出.md#13.终结神谕系统; docs/12. ContradictionBreak/README.md; scenes/sandbox/sandbox.gd; .planning/onboarding/AUDIT-LATE.md

[INFO] Auto-resolved: 矛盾生成使用独立 Paradox 配置
  Found: Original 程序汇总及系统案的生成条款使用当前档位措辞。
  Note: precedence 10 BG-12/CB-03 明确独立数量×2、频率×3、速度×2.5、10 秒寿命，不沿用普通 Tier 倍率。以正式接口解释当前要求；原稿 Paradox 数值表本身已有同组倍率。
  source: docs/Original/程序需求汇总.md#3.弹幕生成系统; docs/Original/程序需求汇总.md#12.矛盾击破系统; docs/Original/系统案_协作交付版_文本导出.md#各数值表; docs/3. BarrageGeneration/README.md; docs/12. ContradictionBreak/README.md

[INFO] Auto-resolved: neutral 后续正式规则补充原稿三类别描述
  Found: Original 只列正统、异端、荒谬普通话语。
  Note: precedence 10 LC/BG/HR/RP/FO/TT/DD 规格已建立 neutral 普通类别；有 PK、普通历史、复读，倾向增量 0，神谕与终局三倾向候选过滤 neutral。Tier 0～5 neutral 权重倍率为 1.00/0.99/0.70/0.40/0.15/0.00，只影响新生成。玩家三项倾向保持原有三种。
  source: docs/Original/程序需求汇总.md#3.弹幕生成系统; docs/2. LevelConfiguration/README.md; docs/3. BarrageGeneration/README.md; docs/6. HitResolution/README.md; docs/10. Repeat/README.md; docs/13. FinalOracle/README.md; docs/17. ThreeTendencies/README.md; docs/19. DivineDescent/README.md

[INFO] Auto-resolved: 现行试玩配置与正式平衡需求分开追踪
  Found: Original 蓄力 0.8 秒、飞行 0.15～0.25 秒、回拉基数 0.005、普通按强度寿命 8/7/6 秒、复读基础 3 秒。
  Note: 当前任务授权试玩配置采用 0.20/0.10/0.15 秒攻击阶段、回拉基数 0.001、普通基础寿命 10 秒、复读 6 秒；这些值为临时默认。依据 AGENTS precedence 0 使用配置描述现状；正式平衡、按类型寿命、事件表现参数继续 TO VERIFY / 待配置，不把试玩默认冻结成最终数值。
  source: AGENTS.md; docs/Original/系统案_协作交付版_文本导出.md#各数值表; docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md; data/sandbox/attack_timing.tres; data/sandbox/playable_battle_config.tres; .planning/onboarding/AUDIT-EARLY.md

[INFO] Auto-resolved: 旧状态与重复任务交付按当前工程及审计核销
  Found: ID/BG/CA/CS/HR/TT/FO 的部分 README 与旧阻塞日志仍记录技术场、矛盾等待或跨关提交未接；FO-13 假设已有 FinalOracleScreen。
  Note: AGENTS precedence 0 规定工程事实优先。当前已接真实 CB、神谕/休息数据入口及普通历史/倾向最终提交；神谕玩家选择、奖励、休息 UI、关卡推进、终局继续缺失。FO-10/SC-02、TT-09/FO-09 等重叠行为复用现有实现；155 张匹配日志只代表历史证据。当前不存在 FinalOracleScreen，FO-13 直接复用真实 BattleArea。SYNTHESIS 保存现状，原正式文档/日志未被本次修改。
  source: AGENTS.md; docs/1. Identify/README.md; docs/3. BarrageGeneration/README.md; docs/5. CombatAttack/README.md; docs/6. HitResolution/README.md; docs/8. CombatStage/README.md; docs/13. FinalOracle/README.md; docs/17. ThreeTendencies/README.md; docs/13. FinalOracle/tasks/FO-13_battle-area-attack-selection.md; scenes/sandbox/sandbox.gd; .planning/onboarding/AUDIT-EARLY.md; .planning/onboarding/AUDIT-LATE.md; .planning/onboarding/TASK-INVENTORY.json

[INFO] Auto-resolved: 原始文档覆盖与重复条款明确溯源
  Found: 系统案目录列至 20，但实际正文结束于 14；程序、美术汇总实际覆盖 19 个系统（编号 11 留空）。
  Note: 原稿对应的程序/美术条款逐条一致，按 19 个程序范围与 19 个美术范围分组，已匹配的原稿保留双来源；各数值表及原稿音效/音乐/Juice 另成两项，共 40 项。原稿 15～20 正文 absent，不从目录生成内容；后段需求依据实际汇总与正式 SPEC。
  source: docs/Original/系统案_协作交付版_文本导出.md; docs/Original/程序需求汇总.md; docs/Original/美术需求汇总.md; .planning/onboarding/AUDIT-SHARED.md
