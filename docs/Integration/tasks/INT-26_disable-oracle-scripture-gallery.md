# INT-26 · 屏蔽终结神谕、圣典与图鉴

**状态：P0，待开发。Owner：总控指定一名集成人，统一负责本卡所有运行代码文件。**  
**本卡覆盖 INT-25 中“图鉴／圣典可打开”及“存档后仍可查看图鉴／圣典”的要求；INT-25 的开播、战斗、结算、继续／下播闭环和底部话语卡放大仍然有效。**

## 开始前先阅读以下文档

- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/Original/任务卡模板.md`。
- `docs/13. FinalOracle/README.md`、`docs/15. Scripture/README.md`、`docs/18. Rest/README.md`、`docs/Integration/README.md`。
- `docs/Integration/tasks/INT-25_gameplay-loop-integration-smoke.md`。
- `scenes/sandbox/sandbox.gd`、`core/contradiction_oracle/contradiction_oracle_flow.gd`、`ui/final_oracle/`、`ui/rest/rest_opening_room.gd` / `.tscn`、`ui/rest/rest_result_view.gd` / `.tscn`。
- `tests/integration/rest_pause_overlay_smoke.gd`，以及当前仓库中覆盖神谕阶段、击破成功和 Rest 交接的现有集成测试。

## 已经实现的功能

- 休息室电脑菜单目前包含“继续直播”“查看图鉴”“查看圣典”，分别接入开播、败者卡历史页和圣典历史页。
- 结算页面也有圣典历史和败者卡历史入口，能够打开各自的历史子页。
- 当前成功击破矛盾后会进入 `ContradictionOracleFlow` 的神谕候选阶段，展示候选并允许手动／超时选择；确认链会继续触发圣典写入、败者卡和相关吞并奖励提交，再进入休息时刻。
- Plan B 底部三张话语卡、剪刀石头布克制、棋子生成／感染、PK、矛盾击破和费米教学属于当前核心玩法，继续保留。

## 本次任务

1. **屏蔽休息室入口**：正式电脑菜单只保留“继续直播”。从 `ui/rest/rest_opening_room.tscn` 移除图鉴、圣典按钮及对应历史页实例；同步清理 `rest_opening_room.gd` 中失效的节点引用、信号连接和打开／返回回调。保留电脑交互、开播状态和 `start_live()` 路由。
2. **屏蔽结算页入口**：从 `ui/rest/rest_result_view.tscn` 移除圣典、败者卡历史按钮及对应历史页实例；同步清理 `rest_result_view.gd` 中相关引用、信号连接、空态与历史页开关逻辑。保留结果展示、继续／下播路由及其他仍在使用的结算内容。
3. **跳过击破后的终结神谕阶段**：保留 `ContradictionOracleFlow` 中的矛盾判定、结果锁定、矛盾复读与现有过渡；成功击破并完成当前过渡后，直接调用现有 `RestSession.open_result()`／`RestResultView.show_result()` 流程。神谕候选展示、选择计时、候选攻击目标和确认回调均不再进入运行流程。成功击破与未击破都必须正常进入结算，且每场只结算一次。
4. **切断被裁剪功能的新增成果链**：不再通过神谕确认回调写入新圣典、发放败者卡或登记仅依赖该确认的吞并奖励。已存在于存档中的数据保留，`SaveData` 格式保持不变；普通命中历史按现有 HR-15 规则提交一次，PK 结果、关卡进度、重开和继续／下播流程保持正常。若某项独立进度当前只依赖神谕确认才能提交，先确认其真实归属，再做满足现有规则的最小接线，避免成功击破后流程卡死或重复提交。
5. **更新现有测试与文档**：调整直接断言神谕阶段或历史页可打开的现有集成测试，使其验证入口不可达、成功击破直接进入结算、普通命中历史仅提交一次、核心玩法仍可运行。更新受影响系统 README 和 `docs/Integration/INT-26_2026-10-21_log.md`；不新建测试框架。
6. **明确功能边界**：本卡中的“神谕”指矛盾击破后的 `FinalOracle` 候选选择阶段。保留 Plan B 的三张核心话语卡及其发表、克制、感染和战斗逻辑。

## 本任务所属分支和文件归属

- 从开工时最新 `main` HEAD 建立独立 D 盘工作树，功能 PR 的 base 为 `main`。
- 运行代码文件由同一集成人独占修改：`scenes/sandbox/sandbox.gd`、`core/contradiction_oracle/contradiction_oracle_flow.gd`、`ui/rest/rest_opening_room.gd` / `.tscn`、`ui/rest/rest_result_view.gd` / `.tscn`。开工前检查这些文件的现有 PR 与 Owner，确认没有并发覆盖。
- 直接测试文件由本卡 Owner 同步修改；只更新受本次裁剪影响的断言。
- 保留 `core/final_oracle/`、`core/scripture/`、败者卡资源与已存档数据，当前任务只切断正式运行入口和调用链；不做大规模删除或无关重构。

## Godot 开发环境

Godot 4.7.2、GDScript；Windows PC；目标分辨率 1920×1080；Godot-MCP-Native、godot_mcp。工作树、缓存、测试输出、日志和截图全部放在 D 盘。

## 最小执行流程

核对最新 main 与文件 Owner → 追踪神谕成功／未击破两条真实调用链 → 移除休息室与结算页入口 → 成功击破后直接进入现有结算 → 更新相关集成测试与系统文档 → Godot 运行验证 → commit、短日志和功能 PR。只做本卡直接相关的行为验证，不重跑完整四关。

## 验收标准与最终汇报

- 电脑菜单只显示“继续直播”；结算页面没有圣典、图鉴入口，历史子页无法通过其他 UI 路径打开。
- 成功击破矛盾后不显示神谕候选、不启动神谕选择计时，直接进入结算；未击破路线仍正常结算。
- 成功与未击破两条路径均能继续直播／暂时下播；关卡进度正确，普通命中历史仅提交一次，无重复发奖、黑屏、卡死或失效节点引用。
- Plan B 三张话语卡、剪刀石头布、棋子感染、PK、矛盾击破与教学保持可玩。
- PR 附两张真实 Godot 运行截图：电脑菜单仅显示“继续直播”；成功击破后直接进入结算。注明分辨率与截图对应 commit SHA；另附一次针对性成功击破流程验证结果。
- 最终汇报列出实际修改文件、已屏蔽入口、成功击破的新路由、验证结果及尚存限制。
