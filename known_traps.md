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
<td>使用 `--script` 直接运行验证脚本时，项目 Autoload 不会自动作为全局标识符注入，直接引用 Autoload 名称会编译失败。</td>
<td>依赖 Autoload 的测试使用真实场景启动，或在脚本中显式加载并实例化目标脚本，同时单独核对项目配置。</td>
</tr>
</table>
## 六、自查入口
遇到问题优先按类别检查：
- UI 不响应 / 空引用：KT-02、KT-04、KT-05。
- 状态不同步 / 重复：KT-06～KT-10。
- 数据加载 / ID 问题：KT-11～KT-17。
- `.tres / .tscn` 解析问题：KT-18～KT-20。
- 重构后编译或引用异常：KT-21～KT-23。

## 附录 A：Godot 生命周期提醒

- Autoload 名称不得与 `class_name` 冲突。
- 新增 Autoload 后核对 `project.godot`。
- `PackedScene.instantiate()` 后，节点未进入树时不得假设 `@onready` 已初始化。
- 关键 Task / Dispatch 清理必须显式完成，不依赖 `_exit_tree()` 等销毁副作用。
- UI 只提交请求和显示事实，不直接写业务状态。
