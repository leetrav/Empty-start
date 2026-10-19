# DBG-02 · 恢复F3调试面板与Plan B真实控制

优先级：**P0｜测试/玩法阻断**。负责人：Lane A + DebugPanel UI Owner + E。本任务卡为分析及待修复规格，**不是代码已经修好**。
目标：以最新可运行Plan B候选（优先核对PR #270 → #287及其最新后继）和真实Commit SHA执行。2026-10-19。

## 开始前先阅读以下文档
- AGENTS.md、known_traps.md、project.godot、docs/Original/任务卡模板.md
- docs/Shared/Debug/README.md、DBG-01原卡和完成日志
- ui/debug/debug_panel.gd/.tscn、scenes/sandbox/sandbox.gd/.tscn
- core/combat/hit_resolution.gd、systems/plan_b/battle/plan_b_battle_host.gd

## 已经实现的功能
已有F3 CanvasLayer开关与旧战斗调试按钮、Sandbox.get_debug_snapshot和旧BarrageArea操作。正式PlanB仅隐藏面板而未完成绑定，PK归PlanBBattleHost所有。

## 原因分析与证据等级
**已从代码确认**：Sandbox._ready()中use_plan_b_campaign分支执行_debug_panel.hide()，只有非PlanB分支才bind_sandbox(self)。另外Sandbox.debug_set_player_pk调用HitResolution.set_player_pk_for_debug，但外部PK getter模式下apply_player_pk_delta只返回Host当前PK，不会写回Host。清普通弹幕/生成普通弹幕/启停旧BarrageArea不是PlanB棋子战斗操作。

## 本次任务
1. 正式PlanB加载成功后对DebugPanel绑定当前Sandbox，无论初始隐藏与否；初始化/关卡切换/失败后显示正确连接状态，F3及关闭按钮始终有效。
2. DebugPanel按当前玩法切换调试内容：读取Host真实PK、Tier、B模拟人口P/O/N、当前3张卡槽及冷却、AI发表状态。恢复真正可用的PK设置入口，必须由Host（唯一普通PK Owner）提交并广播正式PK/Tier/结束信号；允许设置10、50、90、0、100用于合法流程验证。
3. 为当前PlanB提供最少但可操作的调试按钮：对手发表开关、当前局重开、关键人口/卡槽/对手状态观察；旧普通弹幕生成/清屏功能只在旧战斗或矛盾阶段可用，在PlanB正常PK时根据真实能力切换或禁用说明。
4. LiveData与当前尝试倾向的调试值继续进入其原有权威数据源；每次操作读取返回状态后提示成功/失败，不能固定显示成功。F3开启不能吞掉正常卡片操作之外的输入或让游戏进入异常暂停。
5. 做一次真实Godot定向回归，不要求新增复杂测试框架。

## 本卡验收标准
- 正式PlanB中F3能打开关闭；PK预设真实改变Host数值及UI，0/100分别进入正式失败/矛盾阶段；可查询正确的人口/卡位/对手状态。
- 不再显示“按钮成功”但后台无变化；在失败、重开之后再次打开仍可用；旧战斗原有操作不回归。
- 附运行SHA与真实界面截图、各按钮对应结果记录。

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
