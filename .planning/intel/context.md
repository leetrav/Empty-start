## 一、Godot / 生命周期
- source: known_traps.md

  ~~~~text
  DATA_498VFY14_START
  KT-01：Autoload 名称与 `class_name` 冲突，或新增 Autoload 后实际未注册。
  Autoload 不声明同名 `class_name`；修改后核对 `project.godot` 的 `[autoload]`。

  KT-02：`PackedScene.instantiate()` 后立即调用依赖 `@onready` 的方法，节点尚未进入树。
  先 `add_child()` 并等待初始化，或让 setup 不依赖 `@onready`。

  KT-05：`_input()` 对未处理事件也调用 `set_input_as_handled()`，导致其他 UI 失效。
  只消费明确处理的事件。
  DATA_498VFY14_END
  ~~~~

## 二、状态与系统边界
- source: known_traps.md

  ~~~~text
  DATA_RTL0AB0A_START
  KT-06：同一事实被多个对象保存，例如 Task 与 Dispatch 各维护一份可修改派遣成员。
  指定唯一拥有者；其他位置只引用或保存明确不可变历史快照。

  KT-07：UI 或其他 System 直接修改不属于自己的运行状态。
  通过状态拥有者公开 API 修改；UI 只提交请求。

  KT-08：用 Signal 发送隐式业务命令，调用链无法追踪。
  命令走 API；Signal 只通知已经发生的事实。

  KT-09：把当前值、占用、关系进度等运行事实写回静态 `.tres` Resource。
  静态 Resource 运行时只读；变化写入对应运行系统。
  DATA_RTL0AB0A_END
  ~~~~

## 三、数据 / ID / 测试资产
- source: known_traps.md

  ~~~~text
  DATA_1T0EA5XM_START
  KT-12：跨资产 ID 不一致，或使用显示名称代替稳定 ID。
  ID 全局稳定；修改后全局搜索所有引用。

  KT-15：TEST_ONLY 的临时字段或 fixture 被顺手做成正式 Schema。
  测试资产使用 `test_` 和独立目录；正式 Schema 只能由真实策划验证后冻结。

  KT-17：派遣前预览和最终结算分别随机，玩家看到的依据与结果来源不一致。
  一次生成并保存随机结果，后续全部读取同一事实。
  DATA_1T0EA5XM_END
  ~~~~

## 四、Resource / Scene 文件
- source: known_traps.md

  ~~~~text
  DATA_NAUL2AMB_START
  KT-18：手写 `.tres` 时 `[resource]` 先于其引用的 `[sub_resource]`，产生前向引用解析错误。
  顺序保持 `[gd_resource] → [ext_resource] → [sub_resource] → [resource]`。

  KT-20：Resource 被共享加载后又当作某一实例的可变状态使用，导致多个对象互相污染。
  静态 Resource 保持只读；确需独立可变副本时先确认所有权和复制语义。
  DATA_NAUL2AMB_END
  ~~~~

## 五、代码修改与验证
- source: known_traps.md

  ~~~~text
  DATA_Q51NLYYX_START
  KT-23：只运行 `--headless --quit` 就认为所有脚本编译通过。
  新增 / 修改 `.gd` 对相关脚本执行单文件 `--check-only --script`，并运行对应测试。

  KT-25：使用 `--script` 直接运行验证脚本时，项目 Autoload 不会自动作为全局标识符注入；项目中预载资源的无关 Autoload 也可能在该运行方式下报加载错误。
  依赖 Autoload 的测试使用真实场景启动，或在脚本中显式加载并实例化目标脚本。纯逻辑测试不需要的 Autoload 可临时从 `project.godot` 移除，验证后立即恢复配置。

  KT-27：新 worktree 首次直接启动 headless 场景时，Global Script Class Cache 尚未生成，出现多个 `Could not find type` / Autoload 脚本解析错误。
  先使用 `--headless --path 项目路径 --import` 完成项目导入，再启动场景；确认 `.godot/global_script_class_cache.cfg` 已包含新增 `class_name`。

  KT-29：直接运行场景时在 `_enter_tree()` 创建 SaveData，随后 Autoload 的 `_ready()` 又将数据初始化为 null，导致场景读取 live_session 报 Nil；仅在已初始化存档的测试场景中无法暴露该问题。
  等待场景 `_ready()` 再创建需要的内存周目；已经就绪的子 HUD 通过公开绑定方法接收当前 Resource，同时验证直接启动正式场景。

  KT-30：headless 的物理窗口与逻辑视口大小不同，直接将弹幕画布坐标传给 `Input.parse_input_event()` 会被再次缩放，准心偏离目标后产生 MISS。
  先将画布目标通过 Canvas 变换和 `Viewport.get_final_transform()` 转成窗口坐标，再注入事件并刷新输入缓冲；准心从接收到的事件位置转换回画布坐标。INT-01 曾实测到 1/18 的窗口缩放。

  KT-31：命中移除或生成位置不足时释放普通容量，每次都重启正在运行的生成 Timer，会让频繁命中持续推迟下一批。
  释放容量时仅恢复已经停止的 Timer；运行中的剩余周期保持原值。Tier 频率改变继续显式更新时间间隔。INT-01 已用真实 Timer 验证非满容量移除后剩余时间保持。

  KT-32：外部修改嵌套 PackedScene 后，只关闭再打开父场景可能仍复用旧子场景缓存。INT-02 中 LiveDataHud 新标题和卡片排版已写盘，编辑器仍显示旧卡片。
  核对实际子节点与 Inspector；重新加载相关子场景，或重启本任务拥有的编辑器后再次打开父场景。验收截图必须来自重新加载后的真实节点树。
  DATA_Q51NLYYX_END
  ~~~~

## 六、自查入口
- source: known_traps.md

  ~~~~text
  DATA_P8SIMQGV_START
  遇到问题优先按类别检查：
  - UI 不响应 / 空引用：KT-02、KT-04、KT-05。
  - 状态不同步 / 重复：KT-06～KT-10。
  - 数据加载 / ID 问题：KT-11～KT-17。
  - `.tres / .tscn` 解析问题：KT-18～KT-20。
  - 重构后编译或引用异常：KT-21～KT-23。
  - 新 worktree 首次 headless 启动出现全局类缺失：KT-27。
  - Godot MCP 连接 / 端口占用：KT-28。
  DATA_P8SIMQGV_END
  ~~~~

## 附录 A：Godot 生命周期提醒
- source: known_traps.md

  ~~~~text
  DATA_VI3PS2G0_START
  - Autoload 名称不得与 `class_name` 冲突。
  - 新增 Autoload 后核对 `project.godot`。
  - `PackedScene.instantiate()` 后，节点未进入树时不得假设 `@onready` 已初始化。
  - 关键 Task / Dispatch 清理必须显式完成，不依赖 `_exit_tree()` 等销毁副作用。
  - UI 只提交请求和显示事实，不直接写业务状态。
  DATA_VI3PS2G0_END
  ~~~~
