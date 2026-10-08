# RS-12 新周目开局直接进入主角房间

## 开始前阅读
- AGENTS.md、known_traps.md、project.godot
- docs/System_Collaboration.md
- docs/18. Rest/README.md
- docs/18. Rest/tasks/RS-07_tendency-environment.md
- docs/18. Rest/tasks/RS-09_next-level.md
- docs/18. Rest/tasks/RS-11_input-switch.md 及相关最新完成日志
- docs/1. Identify/tasks/ID-08_twelve-identity-card-selection.md
- docs/1. Identify/tasks/ID-09_three-step-opening-flow.md
- core/autoload/scene_router.gd、core/rest/rest_session.gd
- ui/rest/rest_room_environment.tscn / .gd、ui/rest/rest_result_view.tscn / .gd
- scenes/sandbox/sandbox.gd、ui/identity_setup/identity_setup.gd

## 已有功能
- RS-07 已实现复用同一房间背景 res://assets/environment/bg_player_room_1.png，RestRoomEnvironment.apply_tendency() 能在正统、异端、荒谬间切换装饰和光照。
- 当前房间环境仅组合在战斗结束的 RestResultView Overlay 内。RestResultView.show_result() 需要 RestSession 已打开的有效战斗结果，RestSession.open_result() 只接受 pk_win_unbroken 或 breakthrough_oracle_complete 与有效 level_id。
- SceneRouter.goto_game() 当前进入 scenes/sandbox/sandbox.tscn；Sandbox._ready() 随即 restart_current_attempt()，开始第一场普通弹幕和攻击。
- 已有 RS-09 负责战后休息继续到下一普通关；RS-10 负责最后普通关进入神降临。这些已有进度和结算规则继续沿用。

## 本次任务
新增**新周目首次进入的「开局房间」入口**。ID-09 完成主播名、12 身份之一和粉丝团名字的最终确认及存档后，玩家先进入休息时刻的主角房间，在房间界面中再主动进入第一场直播。

### 开局房间展示
- 使用现有 RestRoomEnvironment 场景及唯一共享的主角房间背景，使用已保存的 SaveData.tendency_state.get_primary_tendency_id() 取得开局倾向，以 RS-07 既有规则展示对应装饰与光照。三项累计值为零时，既有 TendencyState 已使用开局身份倾向作为主导参照。
- 房间展示为真实游戏场景或可操作页面，与战后结算页使用同一房间视觉底层及必要可复用控件。
- 开局第一次进入房间时不应该显示战斗胜利、矛盾未击破、获得奖励、圣典 / 败者卡本场结算等文案。只显示适合开局的房间与可用操作；房间内的其他 UI 内容可先以符合现有 Theme 的最小占位实现，后续按策划另行打磨。
- 保留一条明确、可交互的「开始直播」入口，使玩家能够从房间主动开始第一场普通战斗；开始后沿用目前 Sandbox 第一关初始化及关卡配置。
- 进入房间后正常展示主播名与粉丝团名时，读取现有 SaveData 的已确认字段，不新增第二份存档数据。

### 开局与战后房间的区别
- **新周目开局房间**：身份刚完成；没有任何战斗结果；当前普通关还没有开始。展示房间，等待玩家操作。
- **战后休息时刻**：真实战斗结束后，由 RestSession.open_result() 获得冻结结果并进入 RestResultView；继续沿用当前结果、历史查看和 RS-09/RS-10 路由。
- 设计与实现中明确区分两个入口，复用共享 RoomEnvironment。开局时不要为了让旧 show_result() 通过而制造虚假的 level_id、胜利状态或奖励快照，也不把开局房间写成普通关卡已完成。
- 最小复用已有 RoomEnvironment、UI Theme、运行态和 SceneRouter；根据实际 scene tree 与运行边界决定采用单独 Rest 起始页面或与 Sandbox 协作的明确开局态。引入新入口时保证接口名称和 owner 清晰，不增加不必要的全局 manager。
- 若必须修改 scenes/sandbox/sandbox.gd（Lane A 共享入口），先由该 Owner 接入或协作，防止覆盖正常战斗、神谕、战后休息、末关进入神降临的现有行为。

### 进入第一场直播
- 仅在玩家从开局房间主动请求开始直播后，执行一次第一关的标准初始化 / 正常战斗开始；请求成功后隐藏或退出房间 UI，并切换输入状态至战斗模式。
- 重复点击「开始直播」不能启动两份关卡、重置已存在周目资料或重复创建当前尝试。
- 开局房间内战斗攻击/瞄准输入不可生效；房间退出后继续沿用 Sandbox 的攻击、Tier、弹幕、PK 规则。
- 原有战后 RS-09 进入下一关和 RS-10 转入神降临保持当前运行行为。

### 验收条件
1. 新周目在 ID-09 第三页确认保存后显示主角房间，不自动生成第一场弹幕、不启动攻击或敌方 PK 回拉。
2. 房间复用 bg_player_room_1.png 和 RS-07 同一套视觉部件；从四个正统、异端、荒谬身份中各选一个进入时，读取对应开局倾向并展现房间差异。
3. 无 RestSession 成果时可正常进入开局房间；本次没有任何伪造的完成关卡、获奖、胜利或新增历史记录。
4. 点击「开始直播」一次进入真实第一普通关，房间 UI 正确退出，恢复已有战斗输入、弹幕生成和 HUD。
5. 再次重复开始请求不会多次初始化；当前 SaveData 的主播名、身份 ID、粉丝团名、开局倾向保持正确。
6. 真实战斗成功/失败后仍沿用现有 Rest 结果、历史查看与普通关继续流程；开局入口不干扰 RS-09 / RS-10。
7. Godot 4.7.2 实际运行验收：主菜单 → ID-09 三页面 → 房间 → 开播 → 第一关，并核实房间与战斗输入切换、日志无新增错误。

## 技术与交付
- Godot 4.7.2 / GDScript / Windows / Android。涉及 Godot API 查询 godot_mcp，场景及节点优先通过 Godot-MCP-Native 检查。
- 本卡建立 Rest 的「开局入口」，不改写 RestSession 的战后冻结结果定义；仅对实际需要的 UI 组合、SceneRouter 入口及关卡启动最小接线。
- 先核实 main 最新状态与并发分工：RestRoomEnvironment / RestResultView 由 Rest UI owner 协调，Sandbox 与 SceneRouter 共享部分由相应 Owner 接入；不要在不同 Agent 工作区同时覆盖同一文件。
- 任务完成同步 docs/18. Rest/README.md 并新建 docs/18. Rest/休息时刻系统_RS-12_YYYY-MM-DD_log.md，记录开局入口、RoomEnvironment 复用、开始直播接线、真实运行结果和未确认内容。
