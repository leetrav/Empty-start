# INT-10 精简 Sandbox 根场景与联调测试接口

**状态：待开发 · Sandbox 架构重构第 4 张卡**  
**Owner：Lane A / Sandbox 集成**  
**前置：INT-09 合并并通过整局回归**  
**后续：战斗打磨、主播气泡对话、程序美术与 UI 接线任务**

## 开始前先阅读以下文档
- `AGENTS.md`、`known_traps.md`、`project.godot`
- `docs/Original/任务卡模板.md`
- `docs/Integration/README.md`、`docs/Integration/INT-04_2026-10-09_log.md`
- `docs/开发计划_2026-10-09_任务卡依赖整合.md`
- `docs/Integration/tasks/INT-07_extract_divine_descent_flow.md`、`INT-08_extract_contradiction_oracle_flow.md`、`INT-09_extract_battle_attempt_flow.md` 及最新日志
- `scenes/sandbox/sandbox.gd`、`scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`
- `tests/integration/int_01_playable_battle_sandbox_test.gd`、`tests/integration/int_04_full_run.gd`、`ui/debug/debug_panel.gd`

## 已经实现的功能
- INT-07、INT-08、INT-09 将分别提供神降临、矛盾神谕和普通战斗的独立流程接口。
- `SandboxBattleHud` 已提供主播、PK/Tier、攻击状态与失败页面的显示方法。
- `RestResultView` 已提供战后展示、历史查看和继续请求；`SceneRouter` 已提供正式顶层入口。
- DebugPanel 使用 Sandbox 的 `get_debug_snapshot()`、`debug_*()` 和 `restart_current_attempt()`。
- INT-01 与 INT-04 已有可复用的真实 Godot 场景及 TEST_ONLY 集成测试。

## 本次任务
将 `Sandbox` 整理为顶层场景组合与流程交接入口，并把现有集成测试调整到稳定的业务公开接口。

1. 核对三组已提取流程的实际方法、signal、场景生命周期和数据所有权，绘制当前运行流程交接关系并更新 Integration 文档。
2. 在 `Sandbox` 集中完成现有组件创建与绑定、关卡运行入口、普通战斗 → 矛盾/神谕 → Rest → 下一关/神降临 → Ending 的顶层切换。
3. 让各流程分别管理自身阶段状态，由 `Sandbox` 根据公开结果确定当前顶层阶段及可用输入。
4. 将 RestResultView、BattleHud、LiveDataHud、PauseMenu、DebugPanel 的真实事件接入对应流程接口，保留现有界面与操作行为。
5. 为 DebugPanel 保留 `get_debug_snapshot()`、`debug_*()` 和 `restart_current_attempt()` 入口，以转发方式读取和操作真实状态所有者。
6. 更新 INT-01、INT-04 和相关测试对 `_hit_resolution`、`_repeat_queue`、`_contradiction_break`、`_final_oracle_session`、`_divine_descent_spread` 等内部字段的读取，统一经对应流程公开方法获得状态。
7. 保持 `sandbox.tscn` 当前对外节点路径与 TEST_ONLY 场景继承入口可用；核对 `BattleHud`、`BarrageArea`、`AttackChargeInput`、`AimReticle`、`OracleCandidateDisplay` 的节点引用及信号连接。
8. 按现有 `AGENTS.md` 协作方式明确后续修改归属：BG/RP 处理生成与复读，CS/流程模块处理阶段事实，SD 处理气泡，PA/UI 处理演出和展示，Sandbox 处理总场景接线。
9. 更新现行任务依赖文档中与 Sandbox 接线有关的 Owner 和前置关系，使 CS-14、CS-22、SD-06、PA-17～19、INT-06 等卡片能够对接实际公开接口。

## 验收条件
1. `Sandbox` 作为顶层场景启动后可以连接三个流程，普通战斗、矛盾/神谕、Rest、神降临和 Ending 的真实切换顺序正确。
2. DebugPanel 的当前关、PK、Tier、重开、生成与倾向调试操作可用，读取到的数值与实际系统一致。
3. INT-01 真正战斗场景验收、INT-04 两条整局路线以及 Rest/Ending 相关回归测试通过；重复确认、重复 Continue、重开、暂停和存档读回结果正确。
4. TEST_ONLY 派生场景、现有 `%` 唯一节点引用、窗口缩放下的输入及 HUD 显示保持可用。
5. 现有 `Sandbox` 跨系统协调函数归口到三个流程；战斗系统及表现组件拥有明确的修改入口与交接文档。
6. 正式 Windows Godot 4.7.2 场景启动与图形模式整局联调完成，提供原始测试输出、关键画面和对应提交记录。

## Godot 开发环境
- Godot 版本：4.7.2
- 脚本语言：GDScript
- 项目根目录：仓库根目录
- 目标平台：Windows / Android；本卡在 Windows 上完成真实运行验收
- Godot 工程操作 MCP：Godot-MCP-Native
- Godot 官方文档 MCP：godot_mcp

## 执行要求
1. 从合并 INT-09 的最新 `main` 创建独立 branch，按当前工程确认根场景与三个流程的真实接口。
2. 基于原有 Node、Scene、Resource 和信号连接整理总场景，使跨系统流程及运行数据的来源清晰可追踪。
3. 对修改的脚本执行相关解析检查，对真实场景与 UI 执行 Windows Godot 运行验证，使用已有 INT-01/INT-04 测试证明回归。
4. 更新 `docs/Integration/README.md`、`docs/System_Collaboration.md` 及现行任务依赖文档，新增 `docs/Integration/Sandbox重构_INT-10_YYYY-MM-DD_log.md`。
5. 完成本卡后提交独立 PR，提供模块负责人、公开接口、回归结果和新需求派工入口。

## 最终汇报
汇报最终 Sandbox 根场景职责、三个流程的接口和所有权、调试与自动化测试更新、Godot 真实联调结果，以及后续打磨任务各自的程序修改位置。