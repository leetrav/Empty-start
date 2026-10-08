# 2026 TapTap 聚光灯 GameJam · 剩余开发计划与 Lane 交接

> **性质**：跨会话 / 跨 Agent 的开发交接文件，用来防止排班、依赖和项目决策丢失。不是替代 GDD、任务卡、系统 README、`AGENTS.md` 或运行代码的第二套权威来源。
>
> **记录时间**：2026-10-08 15:45（UTC+8）。
> **记录时 main**：`bf435882e43cce708e5c9b2d2e5651cbb8a8a4c4`（#55 RS-04 已合并）。
> **仓库**：`w7775p/Empty-start`；Godot 4.7.2 / GDScript，目标 Windows / Android。
> **重要**：下方「当前状态」是时间点快照。新会话开始必须先查 GitHub **最新 main、Open PR 和正在运行的 Codex Lane**，再决定 review、merge 或派新任务。不要把本文写下的“尚未完成”当成永久事实。

## 最新决策：基础系统冲刺与 TEST_ONLY（2026-10-08）

**项目负责人明确授权**：正式策划内容尚未到位的所有缺口，暂用清晰标记的 `TEST_ONLY` 测试配置、临时素材或临时文本完成可运行的功能与联调。其目的是**今天尽量完成基础系统、明天集中全流程集成联调与表现打磨**；真实功能、数据边界、存档、开关和正确结果不得因为缺内容而省略。

执行边界：

1. **只补缺口**：已有批准的正式数据（如身份 12 卡正式文本和 ID）必须照源使用；只有缺少的关卡/词库/主播/真假矛盾/败者卡/教名/判词/结局主图/音效、数值等才使用占位。临时内容要能被正式资产和导表替换。
2. **可验证**：`TEST_ONLY` 必须带稳定测试 ID、来源和可复现配置，优先放在 `tests/fixtures/`、`data/test_only/` 或明确的临时资源位置；Godot 运行与必要 E2E 可以在测试环境显式注入，不能把它当正式平衡、美术或发版数据。
3. **不暗中污染生产**：正式 `.tres` 仍保持配置事实，不能将未经策划批准的文本/权重/素材当作正式值默默写入。测试运行启用占位时要有明确入口或标识；演示包的临时占位需标注。
4. **基础系统优先**：A 验证普通战斗→矛盾阶段与路由，B 收尾 Rest 输入边界，C 从 DD-10 顺序完成终局玩法至 DD-17，D 完成 EN-09 零收藏结局，E 完成 BT-13 继承特性；完成一张、测试并形成独立日志/非 Draft PR、审查合并后才接下一张。
5. **联调日重点**：从真实身份页开始跑普通 PK→矛盾→神谕→奖励→Rest→下一主播→神降临→Ending，覆盖未击破、空收藏与失败重开；Windows / Android 输入、UI 遮挡、布局、音效和渲染表现逐项打磨。正式内容仍平行制作，但不阻塞基础验收。
6. **Owner 与集成**：Lane A 独占 Sandbox 跨系统接线，B Rest，C DivineDescent，D Ending，E 继承/特性。不同 Lane 不共享未提交工作树，不私自覆盖交叉改动。

> 本节是后续策划缺口处理的最新决定，优先于本文件旧快照中“等待策划才动工”的安排；不修改任何已批准玩法规则或任务卡既定测试预算。

## 0. 最重要的项目目标与工作原则

**核心优先级：先让玩家从身份选择开始，真实完成普通战斗、矛盾、神谕、奖励、休息、下一主播、神降临、结局，随后补内容和表现。**

1. **一次一张任务卡**：每个 Lane 当前只执行一张明确的卡；做完真实 Godot 验证、系统 README / `日期_log.md`、commit、push、建 **非 Draft PR** 后停止，等 ChatGPT Review 与项目负责人授权合并。
2. **用户决定合并**：Agent 不得自行 merge、也不得未经指令一次推进后续多张任务。Review 和「能合并」不等于已经合并。
3. **main 是代码事实**：先从最新 `origin/main` 建独立 branch/worktree，读 `AGENTS.md`、`known_traps.md`、`docs/System_Collaboration.md`、任务卡、相关系统 README 和前一份日志；以真实场景/Resource/API/运行结果检验文档，避免重复造已存在的功能。
4. **工作量克制**：高内聚、组合优于继承、中文简注，不为任务之外的“通用性”建额外 Manager/Autoload/复杂测试框架/hash/gate。单元测试数量严格跟任务卡走；UI 和集成需真实 Godot smoke，不能只凭 `--check-only` 声称可玩。
5. **文件 Owner 优先**：跨系统接线涉及 `scenes/sandbox/sandbox.gd` 时统一交 Lane A；其它 Lane 提供公开方法 / signal / Resource，尽可能不碰 Sandbox。没有人工同意不要改动别人的未提交工作树。
6. **程序缺口与资源缺口分开**：缺正式策划、美术、数值时，可以使用明确标记的测试 fixture 验证程序，但不得误报为正式交付，也不能把临时验收数据无标记写进生产平衡配置。

## 1. 2026-10-08 15:45 状态快照

最近已合并：#51（BT-10）、#52（LD-06）、#53（TT-09）、#54（EN-08）、#55（RS-04）。main 基线为 `bf435882`。

| Lane | 目前派出的工作 | 分支 | 时间点状态 |
| --- | --- | --- | --- |
| A | **RS-09** Rest 继续进入下一普通关；**Sandbox Owner** | `codex/lane-a-rs09` | Windows 上已见本地分支，尚无 Open PR |
| B | **RS-05** 休息时刻历史圣典查看 | `codex/lane-b-rs05` | [PR #56](https://github.com/w7775p/Empty-start/pull/56) 已开，待 Review |
| C | **DD-01** 进入神降临、固定整局结果快照 | `codex/lane-c-dd01` | [PR #57](https://github.com/w7775p/Empty-start/pull/57) 已开，待 Review |
| D | **TT-10** 给 Rest 提供已提交倾向的环境结果 | `codex/lane-d-tt10` | [PR #58](https://github.com/w7775p/Empty-start/pull/58) 已开，待 Review |
| E | **FO-11 测试占位配置前置** | `codex/lane-e-fo11-test-fixtures` | Windows 上已见本地分支，尚无 Open PR |

**Owner 调整决策**：此前 Sandbox 集成 Owner 是 **Lane B**；本轮项目负责人明确同意新排班，**从现在起 Lane A 是 Sandbox 跨系统集成 Owner，Lane B 专注 Rest UI**。这是一次正式的职责转移，不要按旧窗口的分工再把 Sandbox 给 B。

**PR 注意**：#56～58 目前只是 Open PR，不能仅因为分支/PR 已存在就写成 main 已完成。下一会话首先 review 最新 PR，并核实实际 Godot 验证日志，再由用户决定是否合并。

## 2. 完整游戏的五个里程碑

| 里程碑 | 验收目标 | 核心链路 |
| --- | --- | --- |
| **M1 普通关卡闭环（P0）** | 真实打完第 1 名主播；未击破与击破成功各有正确结算；成功奖励写入；Rest 能进入第 2 关、不可重复领取 | E 测试配置 → A FO-11 → FO-12 → RS-09；B 补 Rest UI |
| **M2 神降临入口与冻结（P0）** | 普通关全完成后进入 19；最终倾向、已提交圣典、普通历史和吞并等在终局开始时固定，后续操作不改写 | C DD-01 → D TT-11/TT-12 → A RS-10 |
| **M3 神降临完整玩法（P0）** | 扩散、动态权重、锁句、只生成目标句、90% 可见占比收束及终局演出真实运行 | C DD-07～DD-16；DD-17 的输出交 A 对接 |
| **M4 完整结局（P0）** | 终局结束进入正式 Ending 页面；空经文/败者卡/吞并也能结束；开局到结局 E2E 不靠 Debug 跳阶段 | D EN-01、EN-09；C DD-17；A 场景路由与集成 |
| **M5 内容、表现、Android（并行准备）** | 正式关卡/词库/身份/结局文字/主图/音频/数值，触控与 Android 构建、Windows/Android 实机验收 | 策划/美术与各 Lane 并行；平台联调在 PC 闭环后优先 |

M5 的正式数据、美术、音频不能等 M4 才开始准备；仅其最终验收安排在核心流程稳定后。

## 3. Lane 职责、逐卡后续链路

下列箭头表示**计划上的依赖顺序**，不是授权 Agent 在本次 PR 后自动执行全部任务。每一步须确认上游 merged 且接口确实可用，再派发下一张。

### A：Sandbox / 跨系统场景集成 Owner

- **本轮：RS-09**。从 Rest 的「继续」调用既有 `LevelRunState.complete_level(level_id)`，有下一普通关时切换正确关卡、重新进入战斗；保留 SaveData 中真正提交的成果，清理前一关临时 UI / 战斗状态。**按卡恰好 1 个关键单测 + 真实 Sandbox 切关 smoke。**
- **后续计划**：E 的 FO-11 测试配置 PR 合入 → **FO-11** 正式奖励接线/复验 → **FO-12** 神谕成功进入 Rest → **RS-10** 最后一普通关进入 DivineDescent → **DD-17/EN-01** 的 SceneRouter 场景切换联调 → 整局 E2E。
- **约束**：A 拥有 `scenes/sandbox/sandbox.gd`，但不拥有 Rest 内部 UI、DD 核心规则、最终判词配置。不能在 RS-09 偷做 RS-10；第 2 关内容仍为示例时，临时 smoke 可注入 TEST_ONLY 内容，不得宣称正式多主播内容已配置完毕。
- **FO-11** 已有部分生产接线：`_on_oracle_confirmation_committed()` 已调用 LoserCard 与 Assimilation 的真正击败入口；缺正式卡片/继承配置。A 接手时先检查新 main，复用原有接口与去重，不要重写确认器。

### B：Rest 页面与交互 Owner

- **本轮：RS-05**，允许从 Rest 打开已保存的历史圣典，显示真实经文、原章号/固定节号/缺章，能回 Rest 继续。优先复用 `ScriptureData.get_chapter_slots()` 与现有 `EndingScriptureDisplayData` / 经文行组件，不能把 `pending_entry` 当正式经文。
- **后续链**：**RS-06** 历史败者卡查看 → **RS-07** 根据 D 提供的倾向状态显示 Rest 环境 → **RS-08** 重开同一结算无额外副作用 → **RS-11** 菜单输入与战斗输入边界 → **LD-10** 本场直播数据/粉丝变化显示；**SC-06** 可先核对现有 Rest/Scripture API 是否已满足，再做定向验证和补日志。
- **约束**：B 维护 Rest 页面/交互，不抢改 A 的 Sandbox；由 A 按最少变更做需要 Sandbox 的调用接线。

### C：DivineDescent 19 核心玩法 Owner

- **本轮：DD-01**。创建进入神降临时的稳定快照接收能力，复用 DD-02、DD-03/AS-09、SC-07、RP-12 等已有读取；未合 RS-10 时，使用真实 Godot Resource smoke 验证入口，不假称已在完整主流程中。
- **后续链**：**DD-07** 圣典句加权（同句一次）→ **DD-08** 加权随机自动复读/生成后更新权重 → **DD-09/10** 新话归零锁最高权重句与稳定并列规则 → **DD-11** 锁定句专属后续生成 → **DD-12** 统计可见占比 → **DD-13** 达 90% 收束 → **DD-14** 锁句后玩家输入只影响表现 → **DD-15** 无普通历史空态 → **DD-16** 终局继承特性边界 → **DD-17** 全屏强调后输出结局转场事实。
- **验收分段**：DD-08 做自动扩散真实 smoke，DD-10 做锁句测试，DD-13 做收束运行验收；之后才做终局到 Ending 的完整联调。
- **约束**：19 持有神降临当次使用的冻结快照；17 拥有倾向事实计算；20 消费同一份结果。不要三个模块各自产生会变化的最终倾向。

### D：ThreeTendencies 17 / Ending 20 Owner

- **本轮：TT-10**。只向 Rest 提供已提交倾向结果的可读、只读状态，不泄漏精确累计数字；环境素材未定时不能猜正式表现。
- **后续链**：C 的 DD-01 接口明确后 **TT-11** 冻结最终倾向 → **TT-12** 统一供 19/20 使用 → **EN-01** Ending 接收终局固定结果 → **EN-09** 零收藏仍可完成结局。Ending 的 EN-02～08 已有数据和页面底座，优先接真实结果，不重建现有页面。
- **约束**：不得修改 B 正在写的 Rest 页面，也不要改 A 的 Sandbox。终局固定数据必须基于已经提交的历史，不能用尚未确认的本场增量。

### E：奖励配置、吞并继承、弹幕特性与战斗边界验收 Owner

- **本轮：FO-11 配置前置**。这是项目负责人已批准的 TEST_ONLY 占位配置任务，**不是 FO-11 正式完成**；详见第 4 节。
- **后续链**：A 完成正式 FO-11 接线之后，推进 **AS-06** 吞并词库/权重/特性在后续关卡的消费 → **AS-07** 重开保留已提交吞并成果 → **BT-13** 继承特性接线；复核 **BT-11、BT-12、CA-10、HR-13、CS-11、CS-12** 已存在的真实代码，必要时只补缺口与 smoke/log，不重复发明已实现部分；**CA-12** Android 触控可在 PC 核心循环稳定后启动。
- **约束**：不抢 A 的 Sandbox 文件，既有 `LoserCardData` / `AssimilationData` 奖励规则优先复用。兼容规则归 4，PK 和倾向结算归 6/17。

## 4. FO-11 TEST_ONLY 测试配置决策（已获授权）

**用户决策**：正式配置还没填写，先生成能够联调的占位测试数据，不需要为了等策划数值阻塞整个普通关卡闭环。

### E 本轮需要实际交付

1. 至少一个与现有 `level_001` / `streamer_sample` 对应的 **测试败者卡资料**（正式 `data/loser_card/loser_card_catalog.tres` 当前为空）。
2. 一个稳定的 **可继承词库 ID**、测试继承权重、明确 `can_inherit`、普通池而非矛盾池标记；配置结构应可由未来正式策划数据直接替换，不要把单句 `LevelSpeech.appearance_weight` 冒充池继承权重。
3. 一个**工程里确实存在、通过特性兼容性约束**的测试 trait ID，及明确的可继承资格。不要凭空创造不存在的陷阱类型。
4. 在 Godot 4.7.2 的真实公开 API smoke 中验证首次真正击败可获得、重复确认不重复获得、未击破不获得、可按稳定关卡/主播来源读取。
5. 测试 fixture 与正式内容**明确区隔并标记 TEST_ONLY**，写明替换成正式数据的位置和方式。可以通过注入供 A 验收，不得默默将未经确认的数值/美术当作正式内容。

### FO-11 程序消费与验收仍归 A

A 在 E PR 合并后，把真实配置交给已有 `grant_on_true_defeat()` / `register_defeated_streamer()` / `register_inherited_word_pool()` / `register_inherited_trait()` 等正确公开接口，在 `FinalOracleConfirmationState.confirmation_committed` 的合法真实确认后统一提交并重验。首次真实确认有效、重复确认不重复发奖、仅 PK 胜利未击破不发上述真正击败奖励。然后才进入 FO-12。

正式卡片/词库/特性、继承比例与平衡仍等待策划数据；TEST_ONLY 测试通过不等于这些正式内容已经完成。

## 5. 剩余任务卡与依赖（基线盘点）

记录时以 `docs/**/tasks/*.md` 和同系统正式 `*_log.md` 匹配，**223 张卡 / 185 张有对应完成日志 / 38 张尚无完成日志**。日志匹配不等于源码/真实验收完成，未有日志也不表示完全没代码；本轮 #56～58 处于 PR 尚未合并状态。

| 系统 | 原盘点尚无完成日志的卡 |
| --- | --- |
| 13 FinalOracle | FO-11、FO-12 |
| 14 Assimilation | AS-06、AS-07 |
| 15 Scripture | SC-06 |
| 17 ThreeTendencies | TT-10、TT-11、TT-12 |
| 18 Rest | RS-05～RS-11 |
| 19 DivineDescent | DD-01、DD-07～DD-17 |
| 20 Ending | EN-01、EN-09 |
| 4 BarrageTraits | BT-11、BT-12、BT-13 |
| 5 CombatAttack | CA-10、CA-12 |
| 6 HitResolution | HR-13 |
| 8 CombatStage | CS-11、CS-12 |
| 9 LiveDataPresentation | LD-10 |

**已有实现、优先验收而不是重写**：CA-10 的矛盾击中接线、HR-13 的普通与矛盾专属处理边界、CS-11/12 的 PK 满值清理与切换、BT-11 的部分特性结果交接、SC-06 的 Rest 读取 API、AS-07 的已提交成果保留。是否完全符合卡片，仍须逐卡做真实 smoke 后判断。

## 6. 当前外部内容/配置缺口

- `data/level_configuration/level_catalog.tres` 当前只列两关示例；`level_002.tres` 的普通词库和真假矛盾尚未齐备。正式多主播内容需要策划填写，否则 RS-09 只能证明切关 API 而不能证明第二关完整可玩。
- 败者卡正式目录为空；可继承池 ID/权重/资格/trait 白名单缺失，是 FO-11 正式完成及 AS-06/BT-13 的配置前提。
- `playable_battle_config.tres` 中胜利粉丝增量、击破/神谕短时直播上涨仍缺正式策划值（默认 0 的字段不代表有可感知表现）。
- 教名九组、结局判词四类与结局主图正式 `.tres` 资源目前空白；Ending 页面可以独立加载，不等于玩家已经可以正式跑到结局。
- BGM 正式音乐内容/事件与 UI 美术字体需按交付进度验收；Godot 端实现音频切换能力不等于已有正式音乐。
- Android 的攻击触摸映射（CA-12）和实机操作/分辨率验证尚待完成。
- Google Sheets 策划数据导表工具与正式表格到 Godot Resource 的交付链，需要单独核对，不可把存在 `.gd` 配置类视为数据已填完。

## 7. 新会话如何安全接手（建议照顺序操作）

1. 读本文件与 `AGENTS.md`、`known_traps.md`、相关任务卡和最新完成日志。
2. **先查 GitHub main 和 Open PR**：尤其 #56 / #57 / #58 是否已 Review/merged，A/E 是否已推新 PR。刷新表格中的状态，不盲目继续“派卡”。
3. 查 Windows Codex 各线程、队列、本地 worktree/branch；区分 `queued`、`active`、`notLoaded`、已提交、已推送、PR 创建与合并，不能互相替代。不要重复派同一张卡。
4. 对每张新 PR：按实际 diff、接口边界、文档日志、Godot 4.7.2 的验证结果 Review；如不满足验收，修正 PR。**只有用户要求合并时才 merge**。
5. 合并后更新最新 main；在相应 Lane 仅派下一张依赖已解除的卡，等实际线程消费指令/工作树变化再标为已开始。
6. 每完成 M1/M2/M3/M4 的节点做真实运行验收，最终 Windows/Android E2E；保持缺策划资源与程序故障分账。

### 参考入口

- [任务协作架构](./System_Collaboration.md)
- [原始程序需求](./Original/程序需求汇总.md)
- [Rest 任务拆分](./18.%20Rest/README.md)
- [FinalOracle 任务拆分](./13.%20FinalOracle/README.md)
- [FO-11 前置接线说明](./13.%20FinalOracle/FO11_真正击败前置接线_2026-10-08_note.md)
- [DivineDescent 任务拆分](./19.%20DivineDescent/README.md)
- [Ending 任务拆分](./20.%20Ending/README.md)

---

**给下一位 ChatGPT / Codex 的最后提醒**：这份文档保存“为什么这样排班、依赖怎么接、哪些测试配置暂时允许使用”。不要拿它取代最新代码、实际运行或用户后来的指令。**优先闭环、一次一卡、Owner 不冲突、Agent 不自合并。**
