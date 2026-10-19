# INT-19 · 修复Plan B失败后重开卡死

优先级：**P0｜测试/玩法阻断**。负责人：Lane A（流程）+ B（Simulation）+ D（失败演出）+ E。本任务卡为分析及待修复规格，**不是代码已经修好**。
目标：以最新可运行Plan B候选（优先核对PR #270 → #287及其最新后继）和真实Commit SHA执行。2026-10-19。

## 开始前先阅读以下文档
- AGENTS.md、known_traps.md、project.godot、docs/Original/任务卡模板.md
- docs/Integration/README.md和最新INT-18完成日志
- scenes/sandbox/sandbox.gd/.tscn、core/combat/battle_attempt_flow.gd
- systems/plan_b/battle/plan_b_battle_host.gd、systems/plan_b/simulation/plan_b_unit_simulation.gd
- ui/plan_b/plan_b_battle_ui.gd、ui/plan_b/plan_b_streamer_panel.gd

## 已经实现的功能
失败入口涉及Host.end_battle、BattleAttemptFlow._on_attempt_failed、Sandbox播放CRT shutdown失败演出、FailureOverlay。重新开始经过Sandbox.restart_current_attempt → BattleAttemptFlow._start_attempt(true) → attempt_started → Host.start_battle/Simulation重生，当前所有模块并非通过一个单对象重建。

## 原因分析与证据等级
**已证实存在多Owner的失败→重开清理链，但尚未通过同机栈/日志确认唯一卡死点。** 待排查假设包括SceneTree仍暂停、FailureOverlay拦截、旧失败动画/延迟信号侵入新场、Host并未RUNNING、Simulation未重新激活、旧Area2D残留/重入、性能骤降。Simulator.clear_population会移除旧节点并queue_free、同时可立即造新棋子，需用真实时序验证信号边界；这些目前都不能冒充已证实原因。

## 本次任务
1. 根据已定位的失败→重开调用链，**直接修可能导致重入/未复位的关键状态**。需要定位阻断点时只跑一次最短复现，查看必要的Host/Flow/Simulation/FailureOverlay/SceneTree状态与报错，不建立全链路打点或报告。
2. 找到实际阻断点后用最小修正统一失败中止和重新开始顺序；重开只触发一次，先清理旧棋子/碰撞队列/卡槽/对手导演/团体复读/残留效果，再根据同一关卡与正式数据创建新尝试，最后恢复可点可发言的HUD。
3. 处理旧CRT shutdown/Tween/Timer/deferred callback跨尝试侵入；必要时按当前attempt身份拒绝过期回调。新场已开始时旧失败UI不得重新弹出。核对Simulation旧Area2D的remove_child/queue_free与接触信号是否造成重建时重复事件。
4. 正确处理暂停和用户连续按重开、失败动画未结束时重开、F3强制失败后重开；重复输入要幂等或明确拒绝。维持未提交倾向回滚，已保存周目数据、教学进度及已获奖励按现有规则保存。
5. 改完只确认一次正常失败→重开，棋子继续移动、PK初始化、三卡能正常发表；有新错误才定向排查。

## 本卡验收标准
- 实际窗口从失败页面重开后，PK恢复初始值、30名中立及当前对手开局数正确、3卡重抽且能够发表2/4/8；Host/Simulation处于RUNNING，画面移动。
- 一次失败→重开后不会假死、旧动画遮挡或重复结算；快速交付修复代码与必要日志，不要求连续3次重开压力测试。
- 保持原暂停、F3、矛盾和结算接口可用；出现明确回归再修，不额外安排边界场景枚举。

## Godot 开发环境
Godot 4.7.2 / GDScript；项目根Empty-start；Windows PC、1920×1080逻辑布局优先；Godot-MCP-Native用于真实场景，godot_mcp用于官方API确认。

## 执行要求（按仓库任务卡14项）
### 1. 先检查当前项目状态：核对branch、当前最新可玩候选、工作区、版本和Scene Tree。
### 2. 严格控制任务范围：本卡仅修直接问题。
### 3. 保持最小必要复杂度：优先复用接口、信号与现有状态。
### 4. 组合优于继承：使用既有Scene/Control/Resource公开方法。
### 5. 保持场景边界：Sandbox协调、Host持有PK、Simulation持有棋子、Flow持有流程。
### 6. 区分场景逻辑数据：配置与运行态分开，参数只由既有权威入口读取。
### 7. 新增实现前检查：先查仓库、Godot原生与现有插件再追加最小实现。
### 8. Godot API不允许猜：查询godot_mcp。
### 9. Godot-MCP-Native检查真实工程：核对Scene Tree、信号、运行窗口及日志。
### 10. 自动化与额外保障：复用现有入口做短时定向回归，视觉与操作真人验收。
### 11. 避免脆弱Godot依赖：稳定ID、信号和公开接口。
### 12. 修改现有场景尊重结构：检查owner、实例、UID、已有连接。
### 13. 验证实际Godot行为：解析、场景加载和真实游戏功能验证。
### 14. 完成前检查：排查重复实现、生命周期、性能、边界和其它流程回归。

## 最终汇报
每独立子任务commit，按AGENTS.md在所属系统目录写2026-10-19本卡完成日志，列出根因证据、修改文件、运行版本/真实截图/最小回归、遗留风险及交接。
