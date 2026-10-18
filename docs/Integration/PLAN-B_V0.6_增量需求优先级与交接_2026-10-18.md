# Plan B V0.6 · 最新增量需求执行优先级（2026-10-18）

## 唯一最新规则
本文件消除 PB-06～PB-10 在 2026-10-17 定版后与四张新增任务卡之间的文字冲突；原卡未涉及的 **完整四关正式流程、1920×1080 三列布局、左右主播演出、PK、矛盾击破蓄力射击和结算** 继续生效。

### P0 交互（依次以最新任务为准）
1. **PB-13 / PR #265：** 原先“选句→点击一名中立观众→将该观众转化”的单颗播种改为“选句→点击中央棋盘任意有效位置→按 strength 生成 2/4/8 颗我方/敌方棋子”。基础合法感染率为 50%/60%/70%；批次必须完整创建才算成功，失败不耗词、不耗次数/计时。每批累计成功感染5次可触发一次性 split/reflect 候选特性。旧的 `seed_unit(neutral_unit_id)` 不再用于玩家正式发表，现有真实碰撞/改口/人口PK延续。
2. **PB-12 / PR #266：** 原先“4张手牌、使用后即时抽取补位、玩家全局5秒冷却”改为“**3个固定卡位，数字键1～3，连续可发表；成功使用的那一槽独立等待5秒再抽一张新卡**”。另外两槽不受影响；玩家取消全局发言冷却，对手 AI 冷却独立。失败不消耗；暂停冻结倒计时，重开重抽。
3. **PB-11 / PR #267：** 同阵营棋子主动结群（不融合，不改棋子人数/PK）；同阵营、同词且空间相邻的棋子共享一只复读气泡，随团体人数放大，1～5根尾巴，完整显示文本；出生、感染、转化和改口即时复读，独立随机复读计时。运动真实碰撞与短暂弹开保留。
4. **PB-14 / PR #268：** 先测真实 Profiler、再优化高频全场搜索/重复快照拷贝/绘制插值；约96棋子为**测量基准而非最终人口上限**。人口上限在优化后用性能及实际画面可读性分档测定，不预先锁定最终值。

### 其他始终生效
- 逻辑画布 1920×1080：主播左右各448；中央 PK 72、棋盘828、底部话语180。PC 默认窗口化；棋子美术采用实际已交付资源。
- 普通 PK 只用话语投放、棋子传播；达到100%后进入原有六选一矛盾击破，**仍使用蓄力射击**。保留四关、Tier、气泡、直播数据/评论、漫画反馈、旧剧情演出、结算与结局。
- 由 A 拥有整批发表原子事务与 PK，B 拥有真实棋子及邻域/碰撞，C 拥有四关词库/AI，D 拥有三槽/棋盘/共享气泡显示，E 测实际性能并出包。对用户电脑仍禁止 GUI 操作时，仅运行非 GUI 构建验证并将需要人工画面验收的部分标为待验。

## 旧任务卡优先级规则与交接
- PB-06 正式流程卡：正式主线仍有效，`publish_word(...,neutral_unit_id)` 的旧目标参数以 PB-13 批次坐标接口替代；旧人物/矛盾击破不变。
- PB-07 棋盘卡：1024×828 的坐标与碰撞仍有效，新增出生容量和 PB-11/PB-14 共用邻域逻辑；总数96先作为测试数，优化后决定正式上限。
- PB-08 词库卡：四关词库和 AI 内容仍有效，旧“四句即时补牌”由 PB-12 三槽独立5秒补位替代；C 提供不重复的新词候选，A 保证一次成功消费。
- PB-09 UI 卡：旧“四句、数字键1～4、点击中立棋子”由三槽1～3、点击任意棋盘有效位置替代；PB-11共享气泡叠加，PB-14负责性能。
- PB-10 打包验收卡：沿用窗口/CSV导出/整链验收，实际包必须覆盖新三槽、批次、结群、共享气泡；优化后的真人性能验证后再确定人口上限。

## 合流工作流
1. A 当前 PB-06 未提交的代码保留并由 A 自己同步新规格；B/C/D/E 在各自原工作树继续，分别提交变更与log。
2. B 先交批次出生/合法容量，再接PB-11运动和PB-14低频决策；A 改发表事务，C 同步对手与三槽词池，D 同步三槽UI与批次视觉，E 在合流后测实际帧率并出包。
3. 游戏完整流程不断开：Boot→身份→房间→四关 Plan B 普通 PK→旧六选一蓄力矛盾击破→败者卡/结算→回房间或结局。

### Lane B 当前已实现的批次接口（PB-13）
- `PlanBUnitSimulation.set_play_area(scene_area: Rect2)` 接收棋盘 scene-global 矩形并转换为模拟节点本地边界；模拟器根按正式场景保持无旋转、单位缩放。单位快照中的 `position` 与 `collision_radius` 使用 scene-global 坐标。
- `spawn_word_batch(scene_position, team, word_definition, word_order, requested_count) -> Dictionary` 由玩家和对手共用。仅接受 strength 1/2/3 对应 2/4/8 的完整数量、有效阵营/词/棋盘落点及足够容量；成功结果含 `ok`, `reason`, `word_order`, `team`, `word_id`, `word_definition`, `spawn_position`, `spawn_target_positions`, `unit_ids`, `count`。失败返回 `ok=false` 和明确 `reason`，人口、单位 ID 与批次事实均不改变。
- `word_batch_spawned(batch: Dictionary)` 每个完整成功批次只发一次，字段沿用上项批次快照；`unit_spawned(unit_id)` 仍按真实单位各发一次。D 用批次事实表现喷涌，继续以 B 的单位快照渲染运行位置。
- 合法感染常量为 strength 1/2/3 = 50%/60%/70%。玩家批次以 `word_order` 累计成功感染；达到5次最多发放一次 split/reflect，并通过 `word_batch_trait_awarded(word_order, unit_id, trait_name)` 通知表现层。

## Lane D 当前 UI 交接接口

- `PlanBBattleUI.publish_requested(slot_id, word_id, spawn_position)`：D 以槽位 ID、词条 ID 和中央棋盘全局坐标提交发表；A 回调 `resolve_publish_request(slot_id, word_id, spawn_position, result)`。D 读取 `get_player_slot_states()`，槽位可用状态与倒计时由 A 唯一管理。
- `PlanBUnitField.board_position_clicked(spawn_position)`：中央棋盘内任意有效位置发出坐标，单位位置不作为点击合法性的条件。
- D 消费 B 的 `word_batch_spawned(batch)`、`word_groups_changed(groups)` 与 `unit_physics_positions_updated(unit_ids, previous_positions, current_positions)`；`group_id/team/word_id/member_ids/center_position/member_positions/word_snapshot` 由 B 提供。
- D 使用物理 tick 的位置对和引擎插值绘制平滑位置；接触、发表落点和模拟结果仍读取真实位置。

### Lane B 当前已实现的 PB-11 团体与运动接口

- `PlanBUnitSimulation.get_word_groups() -> Array[Dictionary]` 返回按稳定 `group_id` 排序的同阵营、同当前 `word_id` 空间连通组；字段含 `group_id/team/word_id/word_order/member_ids/word_snapshot/member_positions/center_position`，均为 scene-global 坐标。
- `word_groups_changed(groups)` 在团体成员、阵营、话语关系或清场事实改变时发出完整组快照；实时位置由按需读取接口提供。`unit_physics_positions_updated(unit_ids, previous_positions, current_positions)` 提供物理 tick 插值点。
- B 负责邻域判定与团体拓扑，默认72px加入、90px离开、中心半径上限180px，刷新间隔0.2秒；同阵营改口和敌我碰撞裁决保持原规则，结群不改变人数/寿命/PK。
- Lane D 负责共享气泡绘制，不在 UI 重算连通关系。

### Lane B 当前已实现的 PB-14 决策与位置事实

- `target_decision_refresh_seconds` 默认0.1秒；按稳定 `unit_id` 分成6个时间相位，错峰刷新目标方向和团体靠拢决策，邻域查询复用同一空间网格。
- 每个物理步仍推进移动、Area2D 接触、感染/改口、反冲和边缘反射；新事实会失效附近决策缓存，下一决策时隙再重算目标。
- `unit_physics_positions_updated(unit_ids, previous_positions, current_positions)` 每个物理步发一次；三个同长数组按升序 Unit ID 对齐，坐标为 scene-global，新生位置以前后相同坐标初始化。
- B 的 PB-14 probe / decision smoke 覆盖错峰频率、位置事件频率及坐标连续性；正式优化后前后性能与人口容量分档仍由 E 按真实 Sandbox profiler 记录。
