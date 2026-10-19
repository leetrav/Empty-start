# PB-21 · 修正首关不合理难度和PK增长节奏

优先级：**P0｜测试/玩法阻断**。负责人：C（参数配置）+ A（确保复用现有Host函数），E仅作一次关键功能确认。本任务卡为分析及待修复规格，**不是代码已经修好**。
目标：以最新可运行Plan B候选（优先核对PR #270 → #287及其最新后继）和真实Commit SHA执行。2026-10-19。

## 开始前先阅读以下文档
- AGENTS.md、known_traps.md、project.godot、docs/Original/任务卡模板.md
- docs/Integration/tasks/PB-05_planb_e_qa-balancing.md及最近日志
- systems/plan_b/battle/plan_b_battle_host.gd、systems/plan_b/opponent/fermi_opponent_director.gd
- systems/plan_b/simulation/plan_b_unit_simulation.gd、data/plan_b/{opponent_config,population_config,word_pool,strength_success_rates,battle_type_matchups}.csv
- tests/plan_b/results/candidate_summary.csv（只作为旧模型参考）

## 已经实现的功能
当前首关PlanB：PK从50%开始，Host的pk_rate_pp_per_second=0.85，按(P-O)/(P+O+N)变化；三卡独立5秒，S1/2/3生成2/4/8，感染率50/60/70%。首关敌方首发/后续约11.5秒、领先2人可能触发最多2次的临时分裂反击。旧模型为model_only旧参数，不能代表最新实机胜率。

## 原因分析与证据等级
**原 PK 函数已经设计并实现，不需要重新做数值模型。** `docs/Integration/PLAN-B_V0.4_复读感染战斗_开发规则与数值试算.md` 明确公式 `ΔPK = k × (P-O)/(P+O+N) × delta`，`PlanBBattleHost.update_pk()` 现已实现同一公式；其中 `k=0.85` 是早期原型试算系数。当前问题优先判定**旧试算数值沿用或现有配置未正确接入**，而不是推翻函数。

## 本次任务
1. **直接复用现有 PK 函数。** 比对正式设计文档、Host `update_pk()` 与当前参数来源，确认 `k` 的实际赋值及是否被默认0.85覆盖；沿原有函数和现有配置入口完成必要参数接入，不新造PK算法、曲线或平衡测试框架。
2. 对照当前第一关已确定的30名中立、2名敌方、三张5秒刷新卡和2/4/8投放规则，直接修明显的数值错配。只有在代码已证明功能异常时，才同步修复发表/感染/人数统计问题。
3. 若目前只有0.85试算值，则在原配置来源中**直接更改必要的PK速率系数**并留下简短计算依据。对手冷却和反击参数只在明显造成无法推进时一起微调，优先完成可玩的版本，不扩大为全关卡平衡研究。
4. 改完即可交付，**只做一次最小验收**：在现有正式场景确认 PK 可随人数优势向正确方向变化、玩家能正常发表，且到达满值可进入矛盾阶段。真实手感留给人工试玩后再调。

## 本卡验收标准
- 已有 `PlanBBattleHost.update_pk()` 沿用，运行数值来源明确，无第二套PK公式。
- 修正后的第一关可以通过正常选卡/投放取得PK优势并向胜利推进；不再把早期试算系数当成最终定值。
- 完成Godot脚本/场景最小检查和**一次定向功能验收**，立即提交代码PR和简短日志；不要求胜率模拟、连续多局、CSV统计或长视频。

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
