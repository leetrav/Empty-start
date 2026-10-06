# known_traps

> 职责：Godot、资源、状态边界和回归问题的编号化排错记录。

## 一、Godot / 生命周期

<table fit-page-width="true" header-row="true">
<tr>
<td>ID</td>
<td>陷阱</td>
<td>正确做法</td>
</tr>
<tr>
<td>KT-01</td>
<td>Autoload 名称与 `class_name` 冲突，或新增 Autoload 后实际未注册。</td>
<td>Autoload 不声明同名 `class_name`；修改后核对 `project.godot` 的 `[autoload]`。</td>
</tr>
<tr>
<td>KT-02</td>
<td>`PackedScene.instantiate()` 后立即调用依赖 `@onready` 的方法，节点尚未进入树。</td>
<td>先 `add_child()` 并等待初始化，或让 setup 不依赖 `@onready`。</td>
</tr>
<tr>
<td>KT-03</td>
<td>依赖 `_exit_tree()` 自动完成任务、派遣、占用等关键清理。</td>
<td>生命周期拥有者提供显式结束方法；场景销毁只做最终清理。</td>
</tr>
<tr>
<td>KT-04</td>
<td>场景化 / UI 重构后遗漏 Button 或 Signal 连接。</td>
<td>修改 `.tscn` 后逐项核对交互节点引用和信号连接。</td>
</tr>
<tr>
<td>KT-05</td>
<td>`_input()` 对未处理事件也调用 `set_input_as_handled()`，导致其他 UI 失效。</td>
<td>只消费明确处理的事件。</td>
</tr>
</table>
## 二、状态与系统边界
<table fit-page-width="true" header-row="true">
<tr>
<td>ID</td>
<td>陷阱</td>
<td>正确做法</td>
</tr>
<tr>
<td>KT-06</td>
<td>同一事实被多个对象保存，例如 Task 与 Dispatch 各维护一份可修改派遣成员。</td>
<td>指定唯一拥有者；其他位置只引用或保存明确不可变历史快照。</td>
</tr>
<tr>
<td>KT-07</td>
<td>UI 或其他 System 直接修改不属于自己的运行状态。</td>
<td>通过状态拥有者公开 API 修改；UI 只提交请求。</td>
</tr>
<tr>
<td>KT-08</td>
<td>用 Signal 发送隐式业务命令，调用链无法追踪。</td>
<td>命令走 API；Signal 只通知已经发生的事实。</td>
</tr>
<tr>
<td>KT-09</td>
<td>把当前值、占用、关系进度等运行事实写回静态 `.tres` Resource。</td>
<td>静态 Resource 运行时只读；变化写入对应运行系统。</td>
</tr>
<tr>
<td>KT-10</td>
<td>为了方便维护“虚拟计数”“is_busy”“is_dispatchable”等第二副本。</td>
<td>能派生的值即时计算，不增加第二真相源。</td>
</tr>
</table>
## 三、数据 / ID / 测试资产
<table fit-page-width="true" header-row="true">
<tr>
<td>ID</td>
<td>陷阱</td>
<td>正确做法</td>
</tr>
<tr>
<td>KT-11</td>
<td>修改源字段后只更新链路的一部分，造成 Excel / Python / JSON / Godot 字段漂移。</td>
<td>字段变化必须验证完整生产链和消费端。</td>
</tr>
<tr>
<td>KT-12</td>
<td>跨资产 ID 不一致，或使用显示名称代替稳定 ID。</td>
<td>ID 全局稳定；修改后全局搜索所有引用。</td>
</tr>
<tr>
<td>KT-13</td>
<td>JSON 数字 / Variant 类型直接进入强类型 GDScript，出现 float/int 或无类型 Array 错误。</td>
<td>Importer 边界显式转换并构造目标类型。</td>
</tr>
<tr>
<td>KT-14</td>
<td>直接修改上游生成出的 JSON / 运行资产，导致下次导出覆盖。</td>
<td>回到真正源数据修改，再重新生成。</td>
</tr>
<tr>
<td>KT-15</td>
<td>TEST_ONLY 的临时字段或 fixture 被顺手做成正式 Schema。</td>
<td>测试资产使用 `test_` 和独立目录；正式 Schema 只能由真实策划验证后冻结。</td>
</tr>
<tr>
<td>KT-16</td>
<td>测试判定包含随机，导致测试不稳定且无法判断回归原因。</td>
<td>首轮 fixture 使用确定性条件；需要随机时固定 seed 或注入 RNG。</td>
</tr>
<tr>
<td>KT-17</td>
<td>派遣前预览和最终结算分别随机，玩家看到的依据与结果来源不一致。</td>
<td>一次生成并保存随机结果，后续全部读取同一事实。</td>
</tr>
</table>
## 四、Resource / Scene 文件
<table fit-page-width="true" header-row="true">
<tr>
<td>ID</td>
<td>陷阱</td>
<td>正确做法</td>
</tr>
<tr>
<td>KT-18</td>
<td>手写 `.tres` 时 `[resource]` 先于其引用的 `[sub_resource]`，产生前向引用解析错误。</td>
<td>顺序保持 `[gd_resource] → [ext_resource] → [sub_resource] → [resource]`。</td>
</tr>
<tr>
<td>KT-19</td>
<td>复制 / 手写 `.tscn` 节点后 `parent` 路径仍指向旧节点。</td>
<td>修改场景文本后核对实际父子树。</td>
</tr>
<tr>
<td>KT-20</td>
<td>Resource 被共享加载后又当作某一实例的可变状态使用，导致多个对象互相污染。</td>
<td>静态 Resource 保持只读；确需独立可变副本时先确认所有权和复制语义。</td>
</tr>
</table>
## 五、代码修改与验证
<table fit-page-width="true" header-row="true">
<tr>
<td>ID</td>
<td>陷阱</td>
<td>正确做法</td>
</tr>
<tr>
<td>KT-21</td>
<td>批量重命名残留旧引用，或 replace-all 二次污染已替换名称。</td>
<td>重命名后立即全局搜索旧名；避免目标字符串互为子串的盲目 replace-all。</td>
</tr>
<tr>
<td>KT-22</td>
<td>新增方法与父类 / 现有方法同名，产生覆盖或签名冲突。</td>
<td>新增公开方法前搜索现有类和 Godot 基类方法。</td>
</tr>
<tr>
<td>KT-23</td>
<td>只运行 `--headless --quit` 就认为所有脚本编译通过。</td>
<td>新增 / 修改 `.gd` 对相关脚本执行单文件 `--check-only --script`，并运行对应测试。</td>
</tr>
<tr>
<td>KT-24</td>
<td>未经确认 push，或提交混入无关文件。</td>
<td>push 必须用户明确授权；提交前检查 `git diff` 和 scope。</td>
</tr>
<tr>
<td>KT-25</td>
<td>使用 `--script` 直接运行验证脚本时，项目 Autoload 不会自动作为全局标识符注入；项目中预载资源的无关 Autoload 也可能在该运行方式下报加载错误。</td>
<td>依赖 Autoload 的测试使用真实场景启动，或在脚本中显式加载并实例化目标脚本。纯逻辑测试不需要的 Autoload 可临时从 `project.godot` 移除，验证后立即恢复配置。</td>
</tr>
<tr>
<td>KT-26</td>
<td>headless --script 验证脚本以 record 作为局部变量名时，只加载脚本而未输出用例结果，退出码仍为 0。</td>
<td>运行时记录使用 runtime_record、barrage_record 等明确变量名；测试检查预期输出和用例结果，不能只看进程退出码。</td>
</tr>
<tr>
<td>KT-27</td>
<td>新 worktree 首次直接启动 headless 场景时，Global Script Class Cache 尚未生成，出现多个 `Could not find type` / Autoload 脚本解析错误。</td>
<td>先使用 `--headless --path 项目路径 --import` 完成项目导入，再启动场景；确认 `.godot/global_script_class_cache.cfg` 已包含新增 `class_name`。</td>
</tr>
<tr>
<td>KT-28</td>
<td>同时启动多个启用 Godot-MCP-Native 的编辑器时，后启动的实例可能因默认端口 9080 已被占用而无法连接 MCP；仅因 Codex 工具列表未显示 Godot 工具就判断项目 MCP 未启动，也会漏掉正在运行的服务。</td>
<td>先请求 `http://127.0.0.1:9080/cli/v1/doctor` 检查 `editor_connected` 与 `project_path`，目标编辑器已连接时复用它的本地 MCP 接口；确需启动第二个编辑器时配置独立端口，纯脚本校验仍可使用 Godot CLI。</td>
</tr>
<tr>
<td>KT-29</td>
<td>直接运行场景时在 `_enter_tree()` 创建 SaveData，随后 Autoload 的 `_ready()` 又将数据初始化为 null，导致场景读取 live_session 报 Nil；仅在已初始化存档的测试场景中无法暴露该问题。</td>
<td>等待场景 `_ready()` 再创建需要的内存周目；已经就绪的子 HUD 通过公开绑定方法接收当前 Resource，同时验证直接启动正式场景。</td>
</tr>
<tr>
<td>KT-30</td>
<td>headless 的物理窗口与逻辑视口大小不同，直接将弹幕画布坐标传给 `Input.parse_input_event()` 会被再次缩放，准心偏离目标后产生 MISS。</td>
<td>先将画布目标通过 Canvas 变换和 `Viewport.get_final_transform()` 转成窗口坐标，再注入事件并刷新输入缓冲；准心从接收到的事件位置转换回画布坐标。INT-01 曾实测到 1/18 的窗口缩放。</td>
</tr>
<tr>
<td>KT-31</td>
<td>命中移除或生成位置不足时释放普通容量，每次都重启正在运行的生成 Timer，会让频繁命中持续推迟下一批。</td>
<td>释放容量时仅恢复已经停止的 Timer；运行中的剩余周期保持原值。Tier 频率改变继续显式更新时间间隔。INT-01 已用真实 Timer 验证非满容量移除后剩余时间保持。</td>
</tr>
<tr>
<td>KT-32</td>
<td>外部修改嵌套 PackedScene 后，只关闭再打开父场景可能仍复用旧子场景缓存。INT-02 中 LiveDataHud 新标题和卡片排版已写盘，编辑器仍显示旧卡片。</td>
<td>核对实际子节点与 Inspector；重新加载相关子场景，或重启本任务拥有的编辑器后再次打开父场景。验收截图必须来自重新加载后的真实节点树。</td>
</tr>
</table>
## 六、自查入口
遇到问题优先按类别检查：
- UI 不响应 / 空引用：KT-02、KT-04、KT-05。
- 状态不同步 / 重复：KT-06～KT-10。
- 数据加载 / ID 问题：KT-11～KT-17。
- `.tres / .tscn` 解析问题：KT-18～KT-20。
- 重构后编译或引用异常：KT-21～KT-23。
- 新 worktree 首次 headless 启动出现全局类缺失：KT-27。
- Godot MCP 连接 / 端口占用：KT-28。

## 附录 A：Godot 生命周期提醒

- Autoload 名称不得与 `class_name` 冲突。
- 新增 Autoload 后核对 `project.godot`。
- `PackedScene.instantiate()` 后，节点未进入树时不得假设 `@onready` 已初始化。
- 关键 Task / Dispatch 清理必须显式完成，不依赖 `_exit_tree()` 等销毁副作用。
- UI 只提交请求和显示事实，不直接写业务状态。
