# PTF-05 · Lane E · Android 触控安全区适配、败者卡资料和独立结局漫画资源

## 开始前先阅读以下文档
- `AGENTS.md`
- `known_traps.md`
- `project.godot`
- `docs/Original/任务卡模板.md`
- 试玩报告：`https://github.com/w7775p/Empty-start/issues/255`
- `project.godot`
- `export_presets.cfg`
- `docs/Original/程序需求汇总.md`
- `docs/16. LoserCard/README.md`
- `docs/20. Ending/README.md`
- `docs/Integration/INT-18E_asset_gaps_2026-10-16.md`
- `data/source_tables/14_败者卡.csv`
- `data/source_tables/16_结局配置.csv`
- `data/ending/ending_comic.tres`
- `tools/build_internal_playtest.ps1`

## 已经实现的功能
- 当前 release Android ARM64 debug APK 构建通过，未经过真机触摸适配验收；移动端分辨率和准心会被触点遮挡。
- 14 表四张败者卡全部禁用、描述/卡面未交付；独立通关漫画 Resource 为空，终局只显示已有 Ending UI。

## 本次任务
1. 根据 PTF Issue #255 手机触控反馈，核对 `project.godot`、Android viewport/safe area、屏幕纵横比、触点在实际操作时的位置、准心偏移与进度环可见性。提供 Godot 16:9、19.5:9、20:9 三种真实屏比例预览/触摸模拟录像。
2. 实现最短可用的手指与瞄准点分离方案（移动端触点控制偏置瞄准/独立蓄力可视反馈）；确保不同 DPI/设备尺寸下准心与外环进度能在手指遮挡时被玩家清楚看到。与 C 的 AttackChargeInput 业务 API 对接、与 D 的 HUD 公开接口对接，根场景输入由 A 做最终绑定。
3. 查明失焦、旋转、触控/鼠标事件重复、取消蓄力与多指时的实际输入行为；在 Android 真实设备可用时跑长按、拖动、释放和 ESC/系统返回；缺实体设备时注明尚未验收。
4. 给出四张败者卡的资源交付最小清单：已有角色立绘能否作为临时可见卡面、名称与是否需要人类正式批准的文案。为结算系统提供一个真实可读可发放的本地V0演示数据和可审卡界面，不将未批准的占位强行启用为正式剧情。
5. 审核结局资源：`data/ending/ending_comic.tres` 当前为空；以现有正式美术/文本检查能否拼成最小独立结束演出，给出时序预览和缺少的正式剧情页/三主图/教名/判词清单。根 SceneRouter 接入由 A 完成；开场 P5/P6 仍属于开场。
6. 数据/Android 构建属于 E 独占；具体触摸 UI 组件以新独立可注入场景交 D/A，避免并行编辑 Sandbox。每子任务 commit、PR，Android 设备/模拟器画面和日志供真人验收。

### 本次验收标准
- 手机版触摸不遮住核心准心/蓄力反馈，16:9 至 20:9 可读且触控点与攻击判定对应。
- 败者卡与独立终局演出分别存在可真人审核的V0预览与明确正式素材缺口，不把空内容当作完成。
- 下一轮 release 的构建产物由真实修复后的精确 Git SHA 出包。

### 真实试玩优先级与并行交接
- Release `playtest-2026-10-16` 的玩家反馈为本次真实验收基线；必须验证实际截图/触控/手动输入。自动 E2E 仍作为回归辅助。
- 当前独立工作树：`D:\Godot\lane-r26-e-import-audit-20261016`；初始 main SHA `9da23042fd8c9db7d2e5496746f448335996d7f7`，启动前检查当前分支、未提交内容与已有 Agent 工作。各子任务 commit，并按 `系统名_任务卡_2026-10-16_log.md` 写完成日志。
- 继续使用已有 Codex Desktop IPC 会话，完全权限 `danger-full-access`、审批 `never`；不使用 Codex CLI 派工。
- Lane A 独占 `scenes/sandbox/sandbox.gd`、SaveData、顶层 SceneRouter/暂停接线。Lane B 专有 ContradictionOracle/DivineDescent/Repeat。Lane C 专有普通 BarrageArea、Motion/Attack/Traits。Lane D 专有 HUD/气泡/立绘。Lane E 专有 Data Resource/Android 适配资源及打包。通过 API/信号交接，支持任一小补丁先完成先 Review。
- 对存在美术/设计主观取舍的条目，先产出至少两种真实 Godot 可视预览供项目负责人选择；得到批准后再固化正式剧情/音乐/视觉参数。
- 每个可独立验收的修复单独 commit；完成后开 PR、附带复现和截图视频，等待真实人类视觉/操作验收。


## Godot 开发环境
Godot 版本：4.7.2
脚本语言：GDScript（导表保留现有 Python）
项目根目录：`D:\Godot\lane-r26-e-import-audit-20261016`
目标平台：Windows x64 / Android ARM64；1920×1080、移动端 16:9 至 20:9
Godot 工程操作 MCP：Godot-MCP-Native
Godot 官方文档 MCP：godot_mcp

## 执行要求

### 1. 先检查当前项目状态
开始实现前确认：
- 当前分支、未提交修改和已有实现；
- project.godot 中的 Godot 版本、autoload、插件、Input Map、渲染器及相关项目配置；
- 与任务相关的现有 .tscn、.gd、.tres、.res 和其他资源；
- 当前场景树、节点职责、信号连接和资源依赖；
- 当前项目已经采用的实现模式和目录结构。

基于仓库现状继续开发。
禁止根据任务描述自行假设节点路径、资源路径、autoload、接口、字段名、信号名或场景结构。
涉及实际 Godot 编辑器状态时，优先使用 Godot-MCP-Native 检查真实场景树、节点属性、信号、脚本、资源、运行状态和日志。

### 2. 严格控制任务范围
只实现本任务成立所必需的内容。
不要顺手重构无关系统、扩展未来功能或建立当前任务尚未需要的基础设施。
发现相关问题但本任务无需解决时，在最终汇报中记录。

### 3. 保持最小必要复杂度
优先保持高内聚和清晰的依赖方向。
架构复杂度必须由当前真实需求证明。
仅当代码或场景存在以下情况之一时考虑拆分：
- 独立变化原因；
- 独立生命周期；
- 独立状态；
- 独立操作流程；
- 明确复用需求；
- 可以独立理解、测试或替换。

不要为了满足“模块化、组件化、单一职责”等原则机械拆分 .gd、.tscn、类、接口或目录。
避免无实际需求的抽象层。
一个直接实现如果已经清晰、稳定、易修改，应保留直接实现。

### 4. 组合优于继承
Godot 中默认优先通过以下方式组合行为：
- 子节点；
- 子场景 / PackedScene；
- 独立功能场景；
- Resource；
- signal；
- 公开方法；
- 可注入的数据或依赖。

角色、UI、交互物、技能、效果等复杂对象，优先由多个具有明确职责的节点或场景组合完成。

例如：

```
Player
├── MovementComponent
├── HealthComponent
├── Hurtbox
├── AnimationController
└── WeaponHolder
```

优先让 Player 负责组合和协调这些能力，避免建立：

```
Entity
└── LivingEntity
    └── Character
        └── CombatCharacter
            └── PlayerCharacter
```

这样的深层业务继承链。

继承仅在存在稳定且明确的 is-a 关系，并且子类确实共享父类的核心生命周期、状态和行为时使用。
继承 Godot 原生 Node 类型属于正常使用，例如：
- extends CharacterBody3D
- extends Control
- extends Resource

场景继承也可以使用，但必须存在真实的共同基础和变化关系。
不要为了复用几段代码建立父类。
能通过场景组合、子节点、Resource 或独立对象表达的功能，优先使用组合。

### 5. 保持场景边界
一个 Scene 应表达一个能够独立理解的游戏对象、UI 模块或功能单元。
父场景主要负责：
- 模块组合；
- 生命周期；
- 页面或状态切换；
- 跨模块协调。

子模块负责自己的内部状态和行为。
跨模块通信优先使用：
- signal；
- 稳定公开方法；
- 稳定 ID；
- Resource / 数据对象。

避免：
- 父级长期依赖子模块内部 NodePath；
- 一个模块直接修改兄弟模块内部状态；
- 外部代码依赖子场景内部节点布局；
- 万能 Controller 持续吸收所有业务逻辑。

小型、局部、没有独立状态或变化原因的节点可以继续留在当前场景中。

### 6. 区分场景、逻辑和数据
根据当前需求选择 Godot 自身的数据结构：
- Node / Scene：生命周期、场景树行为、运行时对象；
- Resource：静态配置、可编辑数据、可复用定义；
- 普通脚本对象 / RefCounted：无需进入场景树的纯逻辑；
- Autoload：真正跨场景且生命周期贯穿整个程序的全局服务。

不要因为访问方便就新增 Autoload。
不要把纯数据长期塞进 Node。
不要为了“解耦”把简单数据再包一层无意义 Manager。

### 7. 新增实现前按顺序检查
新增代码、节点、Resource、系统或工具前依次检查：
- 仓库中是否已经存在可复用实现、场景、Resource 或模式；
- Godot 原生 Node、Resource、API 或编辑器能力是否已经提供；
- 已安装 addon / plugin 是否已经提供；
- 标准库或当前语言能力是否已经提供；
- 以上都无法满足后，再新增满足当前需求的最小实现。

优先使用 Godot 原生能力。

### 8. Godot API 不允许猜
对 Node、类、方法、属性、signal、枚举、生命周期或版本差异存在疑问时，使用 godot_mcp 查询当前 Godot 版本对应的官方文档。

优先使用：
- lookup_class
- lookup_method
- lookup_property
- lookup_signal
- lookup_enum
- show_inheritance
- search_symbols

需要设计依据、示例或较完整说明时再使用：
- search_docs
- find_examples
- related_docs
- read_page

确认 API 后再实现。
不得凭记忆猜测 Godot API、属性名、信号名或不同版本行为。

### 9. 使用 Godot-MCP-Native 检查真实工程
涉及以下内容时，优先使用 Godot-MCP-Native：
- 查看真实 Scene Tree；
- 查看节点属性；
- 查看或修改 signal 连接；
- 创建、移动、删除或调整节点；
- 查看 Inspector 中的真实资源属性；
- 创建或修改场景；
- 检查脚本和符号引用；
- 验证 GDScript；
- 查看 Godot Editor / Runtime 日志；
- 运行或停止项目；
- 查看运行时 Scene Tree；
- 检查运行时节点状态；
- 验证资源、autoload、Input Map 或项目设置；
- 必要时获取编辑器截图检查实际画面。

涉及 Scene Tree、节点 owner、场景实例、信号或 Inspector Resource 的修改时，应尽量通过 Godot 编辑器或 Godot MCP 完成并检查最终状态。
纯脚本逻辑可以直接编辑源码，但完成后仍需通过 Godot 验证解析和运行结果。
如果 MCP 当前不可用，如实说明，并使用仓库和 Godot CLI 能够完成的验证方式。

### 10. 自动化与额外保障机制
自动化应服务于重复、稳定、规则明确且适合机器验证的流程。

适合自动化的典型内容包括：
- 脚本解析；
- Resource / Scene 加载验证；
- 数据规则检查；
- 回归测试；
- 导入、构建和导出；
- 可稳定复现的运行时状态检查；
- 明确输入与预期输出的功能验证。

当任务涉及以下内容时，优先保留人工或半自动验收：
- 操作手感；
- 动画节奏；
- UI 可读性；
- 画面表现；
- 音效听感；
- 镜头体验；
- 关卡体验；
- 设计判断；
- 规则仍在变化的玩法；
- 不可逆操作的最终确认。

不要为了追求“全自动”编写复杂测试工具、编辑器插件或测试框架。

默认不新增以下机制：
- hash / hash chain；
- frozen contract；
- baseline；
- gate；
- 自定义一致性协议；
- 为未来场景准备的额外保护机制。

只有存在具体、可复现的失败场景，并且能够说明现有的 Git、版本号、Resource UID、主键、事务、唯一约束、类型系统、Godot 自身资源机制和普通测试为什么不足时，才允许增加这些机制。

Gate 只在存在明确边界时使用，例如：
- 不可逆操作；
- 跨系统副作用；
- 安全或权限边界；
- 正式发布；
- 正式导出；
- 会覆盖或迁移用户存档、资源或项目数据的操作。

不得为了“更稳妥”增加没有实际失败依据的流程和机制。

### 11. 避免脆弱的 Godot 依赖
新增实现时检查是否出现：
- 大量硬编码 NodePath；
- 通过 get_parent().get_parent() 等方式寻找业务依赖；
- 依赖场景树固定层级才能运行；
- 通过节点名称承担业务身份；
- 跨场景保存运行时 Node 引用；
- 大量全局 singleton 相互调用；
- UI 直接承担核心业务规则；
- Resource 同时承担静态定义和运行时实例状态；
- 通过深层继承共享少量逻辑。

如果当前任务可以通过清晰的场景组合、公开接口、signal 或 Resource 解决，优先采用这些方式。

### 12. 修改现有场景时尊重现有结构
修改 .tscn 或 .tres 前先确认：
- 当前是否为实例场景；
- 是否存在场景继承；
- 节点 owner 是否正确；
- Resource 是内嵌还是外部资源；
- 修改是否会影响所有实例；
- signal 当前由场景连接还是代码连接。

不要为了完成一个局部任务把现有场景重新生成。
不要无原因改变节点名称、节点层级、Resource UID 或场景路径。

### 13. 验证实际 Godot 行为
完成代码后至少执行与任务直接相关的验证：
- GDScript / C# 能被 Godot 正常解析；
- 修改后的 Scene / Resource 能正常加载；
- 项目能够进入本任务相关场景；
- Godot Output / Debugger 没有新增相关错误；
- 按任务验收条件验证实际行为。

涉及 UI、动画、视觉、输入、物理、音频、镜头或操作手感时，需要实际运行场景验证。
Headless 测试只能证明其覆盖到的逻辑。
如果仓库已有统一验证脚本、测试入口或 CI，继续使用现有入口，不额外建立一套重复验证系统。

### 14. 完成前检查
完成任务前检查：
- 修改范围是否只覆盖当前任务；
- 是否重复实现仓库已有能力；
- 是否存在 Godot 原生能力可以替代新增代码；
- 是否出现无依据抽象；
- 是否出现可以用组合解决却新增的业务继承层；
- 是否新增不必要的 Autoload / Manager / Singleton；
- 是否产生跨模块内部 NodePath 依赖；
- signal 和公开接口方向是否清晰；
- Scene / Resource 引用是否有效；
- 是否存在未使用节点、脚本、Resource 或死代码；
- 是否为了自动化新增了超过当前需求的基础设施；
- 是否引入没有真实失败场景支撑的 hash、baseline、gate、contract 或额外保障机制；
- Godot 是否能正常解析并运行修改内容。

## 最终汇报
完成后简要汇报：
- 改了哪些文件：每个文件分别修改了什么；
- 场景 / 节点变化：新增、删除或调整了哪些 Scene 和 Node；
- 当前能做什么：本任务完成后的实际能力；
- 还不能做什么：已知限制和未覆盖范围；
- 验证结果：使用了哪些 Godot MCP、测试、运行或人工验证，结果如何；
- 下一步建议：只写基于当前状态真正值得继续做的事项。
