# ID-09 新周目开局三步流程：取名 → 身份选择 → 粉丝团取名

## 开始前阅读
- AGENTS.md、known_traps.md、project.godot
- docs/System_Collaboration.md
- docs/Original/任务卡模板.md
- docs/1. Identify/README.md
- docs/1. Identify/tasks/ID-02_player-name-confirmation.md
- docs/1. Identify/tasks/ID-03_identity-confirm-lock.md
- docs/1. Identify/tasks/ID-04_identity-save-data.md
- docs/1. Identify/tasks/ID-05_identity-setup-ui.md
- docs/1. Identify/tasks/ID-06_identity-flow-wiring.md
- docs/1. Identify/tasks/ID-07_custom-fan-group-name.md
- docs/1. Identify/tasks/ID-08_twelve-identity-card-selection.md 及最新完成日志
- docs/18. Rest/README.md 与 RS-12 开局房间入口任务卡
- 当前代码中的 ui/main_menu/、ui/identity_setup/、core/autoload/scene_router.gd、core/autoload/save_manager.gd、core/save/save_data.gd、core/rest/、ui/rest/

## 已有功能
- 主菜单 Start 已调用 SaveManager.new_game()，再通过 SceneRouter.goto_identity_setup() 打开身份页。
- 当前身份页把「主播名 / 身份选项 / 粉丝团名」放在同一个页面，并在确认后经 SceneRouter.goto_game() 直接进入 Sandbox 普通战斗。
- IdentityNameRules 已分别提供主播名和粉丝团名的输入确认与默认值规则。
- IdentityConfirmationState 实现本周目身份首次确认锁定；SaveManager.set_identity_data()、SaveData 的 streamer_name / identity_id / fan_group_name 保存三项结果；TendencyState.initialize_from_identity_option() 使用所选身份的底层倾向。
- ID-08 已登记 12 张正式身份卡片的 4 列 × 3 行固定混排及三倾向映射；本卡接入该步骤，不重新实现身份列表与映射。
- 当前 RestResultView 属于战后结果视图，RestSession.open_result() 只接受真实关卡结束结果；新周目直接进房间由 RS-12 另行实现。

## 本次任务
将「单页输入两个名字及选身份」重组为**依次前进的三个独立全屏步骤**。功能可复用同一顶层场景中的三个子界面，或采用与项目已有结构一致的顶层场景切换；玩家感知必须是依次跳转的三个界面。

### 页面一：你叫什么？
- 新周目从主菜单 Start 进入本页，主问题文案为「你叫什么？」。
- 仅提供主播名输入与继续操作。沿用 IdentityNameRules.confirm_streamer_name() 与当前空白默认名规则。
- 确认名字后进入第二页「身份选择」。暂存此周目已确认的主播名，在后续步骤可回看；无需因单一中间步骤新增持久存档结构。
- 在界面文案、装饰与轻量动画上延续《邪恶冥刻》式旧纸牌、仪式氛围；设计仍允许后续美术打磨，优先由 Godot Theme / StyleBox 实现可用原型。

### 页面二：你是谁？（十二身份）
- 单独展示 ID-08 的全部 12 张正式身份卡片，4×3 固定混排、标题与完整描述、统一选中/悬停反馈。
- 此页**只负责身份选择**，不出现主播名或粉丝团名输入框，也不显示正统/异端/荒谬类别或类别专属标记。
- 用户选中一张身份卡片并点击确认后，进入第三页「粉丝团取名」；保留该卡片的具体 identity_id 及对应倾向，以供最终一次提交。
- 未选择任何卡片时给出明确提示，允许更换当前选择；沿用 ID-08 既有的稳定身份 ID 和 heresy → heretical 映射。
- 提供按自然步骤返回上一页的能力；返回与再进入本页时保留已输入主播名和临时选中卡片。

### 页面三：粉丝团叫什么？
- 单独提供粉丝团名输入及最终确认。主问题可采用「粉丝团叫什么？」作为暂定界面文案。
- 沿用 IdentityNameRules.confirm_fan_group_name() 与空白使用现有默认粉丝团名的规则。
- 确认后，使用现有 SaveManager / IdentityConfirmationState 完成三项资料的一次性正式提交：streamer_name、identity_id、fan_group_name；同时初始化 TendencyState 的开局倾向，并保存本周目。
- 本步骤确认成功后，**首先进入休息时刻的主角房间**，调用 RS-12 提供的开局房间入口；不能沿用旧流程直接进入普通战斗。
- 若提交 / 存档 / 进入房间失败，提供明确反馈和重试入口；重复点击不能多次完成身份确认、丢失输入内容或生成多个新周目。
- 最终确认前可返回修改上一步；最终成功确认后本周目身份保持锁定，符合现有 IdentityConfirmationState 规则。

### 流程与状态边界
```text
MainMenu.Start（新建 SaveData）
  → ① 你叫什么？ / 主播名输入
  → ② 你是谁？ / 12 身份卡片选择
  → ③ 粉丝团叫什么？ / 粉丝团名输入
  → 正式确认、保存三个字段及开局倾向
  → 休息时刻：主角房间（依赖 RS-12）
  → 由房间中现有/后续确认的进入直播操作开始第一场正常战斗
```
- 每一步分离显示；逻辑中间状态归开局页面管理，正式确认仍复用已有存档所有者，防止中间数据被误判为已完成周目。
- 游戏阶段切换由 SceneRouter / 当前实际入口所有者完成；按现有 Godot 结构最小改动，避免为三个页面创建三套重复的保存/确认机制。
- 若 RS-12 尚未完成，ID-09 可以先实现步骤切换和最终提交准备，最后的房间跳转在 RS-12 完成后联调。**不能用战斗页或伪造的战后 RestSession 充当房间入口。**
- 保持已有身份卡设计：12 个显示选项、内部 3 种倾向；身份逻辑不添加第四种倾向。
- PC / Android 项目基准为 1920×1080、16:9；三个步骤均保证基本操作、焦点、可读性。正式风格与转场动画可后续细化，本卡完成可运行流程。

## 验收
1. 从主菜单新周目开始，首次看到「你叫什么？」及主播名输入，而非旧的三项混合页面。
2. 确认主播名后仅进入 12 身份卡片页；选择身份后仅进入粉丝团取名页，三个页面独立可辨识。
3. 返回上一步及再前进时能保留已输入/选中的临时信息；改选身份最终保存最新身份 ID。
4. 空白主播名、空白粉丝团名沿用原有集中默认值，填写的文字正常保留。
5. 最终确认后 SaveData 保存正确的主播名、独立身份 ID、粉丝团名，TendencyState 保存正确的三倾向之一；读档仍是相同结果。
6. 最终确认成功后看见主角房间及对应开局倾向的房间表现，由 RS-12 负责接入；此时第一场 PK 没有自动开始。
7. 页面前进/回退、点击、键盘焦点、最终重试行为可用；连续确认不会重复初始化周目或触发多次房间切换。
8. 在 Godot 4.7.2 真实运行新周目完整流程并检查 Output/Debugger；有独立子测试价值的纯规则沿用已有测试。

## 技术与执行
- 引擎 Godot 4.7.2，GDScript；Windows / Android。Godot-MCP-Native 用于场景与 UI 实际检查；godot_mcp 用于核实存在疑问的 API。
- 开工先确认 main 当前代码、已合并 PR 与 ID-08 的实现程度；检查 AGENTS.md 和 known_traps.md。
- 优先复用现有身份 Resource / 名称规则 / 保存 API 与 Godot UI 组件。职责集中，真实有独立变化原因时才拆分子页面。UI 不直接修改 17 的累计规则。
- 本任务可以独立分支开发，涉及 SceneRouter 等共享入口时与 Lane A / RS-12 的实际修改 Owner 协调，合并前以最新 main 复审。遵守项目一张卡一个 Agent、完成写中文日志的约定。
- 完成后更新 docs/1. Identify/README.md 现状与接口说明，新增 docs/1. Identify/身份系统_ID-09_YYYY-MM-DD_log.md，记录修改位置、实际运行步骤、最终保存的字段与倾向、房间跳转结果和未验证项。
