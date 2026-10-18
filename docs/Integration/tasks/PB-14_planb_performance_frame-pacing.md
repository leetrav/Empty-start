# PB-14 · Plan B · 棋子运动性能与渲染帧平滑优化

状态：**P0 增量开发卡，直接优化正在运行的 Plan B 正式战斗；与 PB-11 结群和复读气泡同步落地**。
职责：**Lane B**（棋子模拟、目标决策、邻域查询）；**Lane D**（棋子绘制、插值、静态/动态 UI 更新）；**Lane E**（同机前后性能记录、真 Godot 画面验收）；**Lane A**（必要公开接口/场景合流）。各修改独立 commit，主线按现有 Agent 工作流合并。

## 开始前先阅读以下文档
- `AGENTS.md`、`project.godot`、`known_traps.md`、`docs/Original/任务卡模板.md`
- `docs/Integration/tasks/PB-02_planb_b_unit-contact.md`、`docs/Integration/tasks/PB-07_planb_b_board-geometry-simulation.md`（原有 B 任务）
- [PB-11 · 结群/复读气泡](https://github.com/w7775p/Empty-start/pull/267)（开发基线/同步需求，重点避免重复实现邻居查找）
- `docs/Integration/tasks/PB-09_planb_d_fixed-layout-streamer-hud.md`
- 当前有效 PB-13 批量投放及 PB-12 三卡独立刷新功能、真实已合并场景与工作树代码
- `systems/plan_b/simulation/plan_b_unit_simulation.gd`、`systems/plan_b/simulation/plan_b_unit.gd`
- `ui/plan_b/plan_b_unit_field.gd`、`ui/plan_b/plan_b_battle_ui.gd`、实际正式游戏装配场景

## 已经实现的功能
- B 的棋子模拟由 `_physics_process(delta)` 驱动，默认按 Godot 物理步进更新真实移动、Area2D 接触、感染、寿命及中立补充。
- 旧代码 `_advance_units()` 每物理步刷新所有棋子状态，`_get_steering()` 对阵营棋子遍历全场寻找目标，计算量随人数近似平方增长；96 人全阵营时单物理步最多约 96×95 次目标比较。
- D 的 `plan_b_battle_ui.gd` 在 `_process` 中逐渲染帧调用 `_refresh_sources()` 和 `_refresh_view()`，包括对全棋子快照和话语字典的重复读取/复制；`plan_b_unit_field.gd` 每帧 `queue_redraw()`，手绘棋子的显示位置直接来自快照。
- 前述是 **GitHub main 中已检查的潜在热点**，不代表已取得真实性能耗时，也不等于 PB-11/PB-13 最新工作树完全相同。开工时对当前真实可玩工程先查代码和 Profiler 再落实。

## 本次任务

### 一、同环境真实基线（E+B+D，P0）
1. 在当前真实 Godot 场景和用户实际出包路径上取得**优化前**记录：固定窗口/分辨率、硬件、构建方式、物理 TPS、同屏人口和游戏阶段；至少包含普通约 80～100 棋子的高密度对战，并进行 5 秒预热后记录约 20～30 秒。
2. 使用 Godot **Debugger > Profiler** 查看脚本与物理耗时，使用 **Visual Profiler** 观察 CPU/GPU 绘制耗时，记 FPS、平均/较差帧时间、Physics Time、Idle/脚本时间，挑出最慢函数。保留一张 Profiler 截图或简短文字表。
3. 特别判断“显示 FPS 降低”和“FPS 正常但棋子位置跳动”是否同时存在；以同一场景、同一机器的可比数据核实优化收益。

### 二、B · 分离高频运动与低频目标决策（P0）
1. 保留游戏当前物理步进（通常 60Hz）的 **实际位置积分、碰撞接触信号、感染/克制判定、碰撞反冲及边缘处理**。正常物理循环继续每步运行。
2. 将高成本的“搜敌人/找中立/寻同盟/判定目标及转向”等邻域决策从每一步全场扫描，改成**可调频率的目标决策更新**，以 **10Hz（0.1秒）** 为首测值；两次决策间继续沿当前速度/方向运动。通过接触、转化、失去目标等实际事件及时使决策状态失效，在下一次允许更新时重新选择。
3. PB-11 的同盟吸引、团体接敌、团体成员连通判定复用同一个邻近信息来源；团体成员拓扑初测约 **5Hz（0.2秒）**，成员位置/物理接触仍保持完整物理频率。不同单元错峰刷新时相对稳定，不让寻敌/结群每 0.1s 突然整体同步抽动。
4. 基于真实 Profiler 收益，对候选查询加入**简单的网格/邻域分桶**或等价局部搜索，限定到附近几个桶查询；该实现同时服务追击、威胁、同盟搜索和团体邻接，保留真实碰撞与阵营快照为原有事实来源。网格划分与最大侦测半径协调，避免漏掉边界目标。
5. 运动用 `delta` 保持一致的速度，接触后的真实反弹短时惯性沿用 PB-11 方案，核验改变目标更新频率后仍能贴碰、感染、改口、逃避并自然结群，避免慢半拍的目标切换破坏战局节奏。

### 三、D · 减少重复复制与不必要的 UI 运算（P0）
1. 区分**每帧必须更新的可视位置**与**只在变化时更新的内容**。棋盘位置及活动气泡仍按渲染帧顺滑展示；PK/人数/阶段/卡片状态/词库文本仅在对应信号、数值变化或合理轻量节流时修改控件。
2. 当前全量 `get_unit_snapshots()`、`set_unit_snapshots()`、`set_word_texts()` 及其 `duplicate(true)` 调用路径按照实测优化：词库文本由内容变更时同步；棋子渲染保持最少必要的**位置/阵营/话语/ID**数据，可复用已缓存快照或仅更新变化状态，减少每帧完整深拷贝/字典分配和不断重建同一表。
3. 对需要动态绘制的棋子和复读气泡继续按画面需要 `queue_redraw()`；将静态网格/底图等不随棋子变化的内容放到独立绘制层、背景缓存或现有等效组件，避免每帧重新计算静态纹理与布局。
4. PB-11 气泡的**团体连通、尾巴代表选择、文本测量/换行/字号适配**只在团体成员、话语、人数或布局条件变化时计算；帧间仅更新气泡位置、可见性、简单插值/绘制。
5. 复用现有 Godot UI/signal 结构，跟 A/C 的三卡及剧情表现接口对齐。改变显示更新策略后，UI显示仍能跟上正常战斗和每卡独立5秒填充；不会因节流而漏掉即时状态。

### 四、D+B · 解决画面运动跳帧（P0）
1. 查明棋子最终渲染路径：独立 Node2D/Sprite2D 可用 Godot 原生**物理插值**；当前通过 `Control._draw()` 用快照手工绘制的位置，需要按实际场景做**上一物理步位置 → 当前物理步位置**的渲染插值。
2. 对手工绘制路径，按 Unit ID 维护相邻**物理 tick**的 `prev_position/current_position`，渲染端用 `Engine.get_physics_interpolation_fraction()` 计算显示位置。出生、复活、瞬移、离场、切关时重置对应历史坐标；命中/点击/碰撞仍使用**真实当前物理坐标**而不是插值的视觉位置。
3. 保持物理更新和渲染更新的职责分离：低频寻目标并不等于低频移动，更不等于只每0.1秒更新画面；同一个单位既能连续滑动，又会在真正碰撞后出现可读的短促反弹。
4. 若当前 Godot 项目已开启原生物理插值，确认是否与手工插值重复应用。根据真实节点类型选择**一种**有效渲染平滑策略，并验证窗口化/高刷新率/普通60Hz下外观。

### 五、性能取舍与快速合流（P0）
1. 优先落实**决策节流、重复快照消除、渲染插值**三项小改动；根据 Profiling 判断是否继续做邻域分桶和静态层拆分。每个子任务 commit，并记录“前/后关键指标与效果”。
2. 让 B/D 使用各自现有所有权的模块分别开发；与 PB-11 的邻域查询/团体识别作为同一实现协同提交，由 A 在最新正式场景里做最少必要接线，E 验证同一真实游戏流程。
3. 直接出一份能在当前 PC 工程运行的更新内容和真实 Godot 画面供人工验收，维持原有三栏 UI、两阵营/中立棋子、对手反击、三卡独立刷新、2/4/8强度投放、PK及矛盾击破功能。

## 本卡验收标准（真人与 Profiler 双验收）
- [ ] 在**同设备、同版本、同人口/分辨率、同游戏状态**获得优化前后数据，并附 FPS、Physics / 脚本 / 渲染耗时和主要热点对比。理想结果是约96棋子普通PC场景接近或达到**60 FPS、16.7ms/帧**；若机器受限，用实际对比数据说明最大热点是否下降、帧时间是否更稳定，不能将“已经改代码”等同“性能通过”。
- [ ] 棋子实际物理移动与碰撞仍按当前物理步进运行；寻目标/团体判断可降低刷新频率，但感染结算、反弹、改口、PK及对手行为结果稳定。
- [ ] 结群后的约80～100棋子运行时，能够观察连续的运动而不是每次决策都瞬移；特别验证**60Hz物理、实际渲染波动**时不会因插值历史错误出现出生飞线、边缘拉扯或传送拖影。
- [ ] 词条和静态 UI 的计算/复制频率确实降低；已有玩家三卡独立5秒填充、PK变化、碰撞反馈、团体共享气泡实时更新。
- [ ] 完整一局可正常开始、3张卡可连续发表、2/4/8棋子生成、主动结群、对敌碰撞/感染、PK进入矛盾击破及结算，无新增解析/场景/资源错误。
- [ ] 提交 **实际 Godot 运行截图/短录像 + Profiler 对比 + 修改日志**，供人工作最终运动流畅度/手感验收。

## Godot 开发环境
- **Godot 4.7.2**、GDScript，工程根 `Empty-start/project.godot`（开工时核对实际运行版本）。
- Windows PC、逻辑分辨率1920×1080，中间棋盘1024×828；移动端后续复查。
- 工程操作 MCP：**Godot-MCP-Native**；官方文档 MCP：**godot_mcp**。

## 官方文档依据
- [Godot Debugger / Visual Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html)（区分脚本/物理和渲染）
- [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)
- [Godot Physics interpolation introduction](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)（physics tick与显示帧不同；`Engine.get_physics_interpolation_fraction()`）
- [Godot Physics interpolation quick start](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html)

## 执行要求（依仓库14项模板）
### 1. 先检查当前项目状态
核对工作树、分支/PR、`project.godot`、现有场景及节点、真实运动脚本/绘制脚本和 Profiler/日志，再以实际工程代码确认优化边界。
### 2. 严格控制任务范围
围绕 Plan B 运动决定频率、邻域查询、渲染插值、UI重复刷新、与 PB-11 团体气泡直接相关的性能展开增量修改。
### 3. 保持最小必要复杂度
先以少量计时、快照缓存及数据变化时刷新解决问题；局部网格只有在实际热点仍明显时才扩展。
### 4. 组合优于继承
复用原有 `PlanBUnitSimulation`、单位/场景/Control与官方现成功能组件，按现有结构组合缓存和渲染逻辑。
### 5. 保持场景边界
B唯一负责单位运动与碰撞事实；D唯一负责 UI与插值绘制；A负责稳定装配/信号接线；E检查真实可玩表现。
### 6. 区分场景、逻辑和数据
真实位置/阵营/话语仍由模拟模块产生，绘制位置是基于物理快照派生的显示数据；配置值保持可调。
### 7. 新增实现前按顺序检查
检查工程已有邻域优化、信号、快照、缓冲、Godot官方物理插值及CanvasItem层级能力，然后追加最小实现。
### 8. Godot API 不允许猜
针对引擎真实版本使用 `godot_mcp` 查询 `Engine.get_physics_interpolation_fraction`、`CanvasItem.queue_redraw`、原生插值/重置等 API 和行为，核对后实现。
### 9. 使用 Godot-MCP-Native 检查真实工程
查看真实场景/脚本实例及渲染节点、物理帧配置，运行真实战斗并获取必要的 Godot/Profiler 截图。
### 10. 自动化与额外保障机制
采用项目现有测试入口做固定随机种子、碰撞/感染/帧更新、出生/离场/重开最小回归；实际画面和硬件性能以实机验证。
### 11. 避免脆弱的 Godot 依赖
B与D通过稳定 Unit ID、物理快照、事件/公开方法交接；保持现有 Node/Resource/Signal 链路清晰。
### 12. 修改现有场景时尊重现有结构
以真实节点owner、UID和当前UI组件为准，只针对必需的背景/动态绘制层与快照通路调整。
### 13. 验证实际 Godot 行为
完成解析/场景加载/真实96单位运动、目标追击、真实碰撞、团体气泡、UI刷新、暂停、重开和正式一局的最小运行核验。
### 14. 完成前检查
整理冗余数据复制/重复扫描、交互位置一致性、计时/显示状态、Profiler可比性和最新PR合流关系，避免增加多套相互竞争的单位状态来源。

## 完成日志
每个独立子任务单独commit，完成后写 `docs/Integration/复读感染_PB-14_2026-10-18_log.md`，包含变更文件、优化前后测量、关键配置、实机截图/录像、当前可玩包和与PB-11的接线情况。
