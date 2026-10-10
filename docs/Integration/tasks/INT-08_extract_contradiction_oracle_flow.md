# INT-08 提取矛盾击破、终结神谕与战后结算流程

**状态：待开发 · Sandbox 架构重构第 2 张卡**  
**Owner：Lane A / Sandbox 集成**  
**前置：INT-07 合并并通过整局回归**  
**后续：INT-09 → INT-10**

## 开始前先阅读以下文档
- `AGENTS.md`、`known_traps.md`、`project.godot`
- `docs/Original/任务卡模板.md`
- `docs/Integration/README.md`、`docs/Integration/tasks/INT-04_test_only_full_run.md`、`docs/Integration/INT-04_2026-10-09_log.md`
- `docs/12. ContradictionBreak/README.md`、`docs/13. FinalOracle/README.md`、`docs/18. Rest/README.md`
- `docs/14. Assimilation/README.md`、`docs/15. Scripture/README.md`、`docs/16. LoserCard/README.md`
- `docs/Integration/tasks/INT-07_extract_divine_descent_flow.md` 及其最新完成日志
- `scenes/sandbox/sandbox.gd`、`systems/combat_attack/attack_charge_input.gd`、`tests/integration/int_01_playable_battle_sandbox_test.gd`

## 已经实现的功能
- PK 满值后 `Sandbox` 启动 `ContradictionBreakSystem` 的正式限时阶段；矛盾命中使用释放时冻结的真实目标事实。
- 真、假矛盾都创建有限复读；矛盾复读队列和场上可见实例结束后分别进入神谕或 Rest。
- `FinalOracleSession`、`FinalOracleSelectionTimer`、`FinalOracleConfirmationState` 和 `FinalOracleCandidateDisplay` 已支持候选显示、手动命中、超时选择及确认。
- 正式确认通过现有数据所有者提交普通历史、倾向、圣典、败者卡与吞并；未击破胜利进入对应 Rest 结果。

## 本次任务
将矛盾击破、终结神谕及战后成果提交提取为独立的 `ContradictionOracleFlow`，向 `Sandbox` 输出已就绪的 Rest 结果。

1. 核对 `Sandbox` 中矛盾攻击处理、结果锁定、矛盾复读展示等待、静音过渡、神谕候选选择及成果提交的完整调用顺序。
2. 建立 `ContradictionOracleFlow`，统一持有本阶段 `ContradictionBreakSystem`、`FinalOracleSession`、`FinalOracleSelectionTimer`、过渡 Timer 与相关流程状态。
3. 通过公开启动接口接收本关 `LevelProfile`、真实攻击组件、弹幕区域、复读队列与统计、普通命中历史、周目数据以及已有候选显示组件。
4. 对接原有矛盾射击快照、结果通知、真/假分支和等待条件，并提供可供表现系统订阅的阶段事实通知。
5. 复用现有 `FinalOracleConfirmationState` 与 `ScriptureData` 的确认接线，梳理一次确认到各数据所有者的写入条件与顺序；在实际提交入口核验成功条件、返回值及去重结果。
6. 为真击破确认与未击破胜利分别准备对应 `RestSession`，以 `rest_ready` 等明确结果通知交给 `Sandbox` 展示 `RestResultView`。
7. 在 `Sandbox` 保留 Rest 页面显示、继续下一关和末关进入神降临的顶层路由；将本阶段具体倒计时和候选状态读取转接到流程公开接口。
8. 同步调整 INT-01、INT-04 的矛盾/神谕断言及调试读取，覆盖阶段接口和真实结果对象。

## 验收条件
1. PK 满值后真实进入矛盾阶段，释放时只消耗一次正式发射机会，十秒窗口与已存在的真假判定规则正确运行。
2. 真击破等待矛盾复读离场后进入候选神谕，人工命中和超时选择均能完成一次确认，并生成正确的 Rest 结果。
3. 未击破的命中与超时路线按既有展示完成条件进入 Rest；普通历史与倾向在当前合法时点正式提交。
4. 同关重复结果通知、重复神谕确认、失败重开与下一关切换均得到原有去重、回滚及成果保留结果。
5. 本场神谕、圣典、败者卡和吞并成果的写入结果与整局测试一致；增加一个覆盖确认中途写入失败边界的定向回归。
6. INT-01 相关场景测试与 INT-04 两条路线通过，现有 Rest 历史查看与继续按钮可用。

## Godot 开发环境
- Godot 版本：4.7.2
- 脚本语言：GDScript
- 项目根目录：仓库根目录
- 目标平台：Windows / Android；本卡在 Windows 上完成真实运行验收
- Godot 工程操作 MCP：Godot-MCP-Native
- Godot 官方文档 MCP：godot_mcp

## 执行要求
1. 从合并 INT-07 的最新 `main` 创建独立 branch，核对现有信号绑定、同步回调、`call_deferred()` 与实际运行顺序。
2. 以原有业务对象作为唯一事实来源，通过明确公开接口完成模块组合和结果交接。
3. 逐一验证真击破、未击破、神谕超时、重复确认及重开路径，记录真实 Godot 运行结果。
4. 更新 `docs/Integration/README.md` 的阶段与成果交接说明，新增 `docs/Integration/Sandbox重构_INT-08_YYYY-MM-DD_log.md`。
5. 完成本卡后提交独立 PR，附对应 Godot 运行与回归证据。

## 最终汇报
汇报矛盾/神谕流程组件、Rest 结果交接接口、奖励提交与去重的实测情况、INT-01/INT-04 回归结果，以及 INT-09 需要复用的阶段启动入口。