# SHEET-R2-F · 第二阶段：五条 Lane 生产集成、玩家流程验收与出包

## 开始前先阅读以下文档
- `AGENTS.md`
- `project.godot`
- `known_traps.md`
- `docs/Original/任务卡模板.md`
- `tools/README.md`
- `docs/Integration/战斗表接线_SHEET-A_2026-10-15_log.md`
- `docs/Integration/矛盾复读神降临表接线_SHEET-B_2026-10-15_log.md`
- `docs/Integration/评论气泡音频表接线_SHEET-C_2026-10-15_log.md`
- `tools/build_internal_playtest.ps1`
- `docs/Integration/InternalPlaytestExport_2026-10-15.md`
- `data/level_configuration/level_catalog.tres`
- `tests/integration/int_15_production_catalog_preflight.gd`
- 与本任务范围直接相关的系统正式文档、最近完成日志、当前生产 Scene/Resource/脚本

## 已经实现的功能
- main@4eb4c80 已有四关正式资源检查和双端出包流程，Windows 独立启动冒烟通过；旧的 INT-01、SD-07 headless 场景在原 main 亦曾复现失败。
- SHEET-R2-A 至 E 正在作为下一轮并发代码任务准备，五条业务 Lane 将交付独立 PR、真实数据消费者和字段覆盖证据。
- 已有明确问题：旧的出包检查只能验证关卡、词库、矛盾基本存在，不能保证全部关键表值实际接入。

## 本次任务
1. 收取 A～E 五张 PR，按文件所有权和消费依赖逐一 Review 并合并已完成的实现；合并后同步最新 main，核对四关资源与内容身份未回退。
2. 由唯一集成者负责 `scenes/sandbox/sandbox.gd`、正式流程 SceneRouter 和直接相关组合场景，按公开调用接口连接战斗数值、Paradox、反击技能、教学、评论和结局数据生命周期。
3. 运行从主菜单/身份选择到房间、四主播开播与战斗、胜负、Paradox、神谕/Rest/结局的真实生产路径，使用隔离存档并复现/修复阻断；给真人提供截图/录屏和试玩包。
4. 以 E 的字段清单为依据复核 27 张表关键业务行和已填写字段在正式运行时的结果；自动核对明确定义且此前被遗漏的 21 反击技能池/24 三步教学/11 候选运动/09 数据事件。实际源表空、disabled、缺素材分开记录。
5. 使用已存在的 `tools/build_internal_playtest.ps1` 产出 Windows ZIP 与 Android ARM64 APK，执行正式关卡预检、独立 EXE 启动、APK 签名与 Android 设备可得范围内的实测，并核对 build_manifest 和新包中的正式 CSV/Resource。
6. 向项目负责人交付最终已修/待修清单、直接可下载或本地可打开的新版文件位置以及人工必须检查的关键试玩点，记录版本 SHA。

### 文件归属和并行交接
- F 是第二阶段唯一 `scenes/sandbox/sandbox.gd` 和正式出包入口集成者；合并 B/C/D/E 新消费接口时记录真实调用方和时序。
- F 负责 PR 依赖审查、集成冲突解决、生产场景验证、旧 main 既存失败与新引入回归的对照、构建日志和交付。

### 本卡验收
- 五个业务 Lane 的已合入接口在正常玩家流程中被调用，四名主播的正式关卡能够进入且核心结果可验证。
- 关键已填表字段的正式消费验证 PASS，剩余不适用/源空/缺资源清单明确；无未处理的 P0 运行阻断。
- Windows ZIP 与 Android APK 均从本次唯一 main SHA 重新生成，独立启动/签名证据和交付路径完整。

### 依赖与后续联调
- 本卡第二阶段开始：先完成 A～E 的接口交付与 PR Review，再进入中央 Sandbox 和新版构建。
- 由第五条 Lane E 或空闲 Agent 在 A～E 合并后接手 F，确保本轮同时保持五个并发工作者。

### 完成日志
`docs/Integration/生产集成出包_SHEET-R2-F_2026-10-16_log.md`

## Godot 开发环境
Godot 版本：4.7.2
脚本语言：GDScript；导表辅助脚本沿用仓库既有语言
项目根目录：`D:\Godot\Empty-start`（Agent 使用各自独立 worktree）
目标平台：Windows x64、Android ARM64；生产场景分辨率 1920×1080
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
- 按表号列出 **已填写字段 → 数据入口 → 生产消费者函数/Resource → 实际表现 → Godot 验证证据**。
- 列出本次修改的源码、资源、Scene 和公共接口，区分已有能力与新增实现。
- 报告真实 Godot 4.7.2 执行命令、退出码、错误日志，涉及画面/音效提供截图或录屏供真人验收。
- 列出未完成项的具体表号、行 ID、字段以及归因（缺素材、源值未定、接口缺失、未联调）。
- 提供独立分支、各子任务 commit、任务日志和 PR 链接，说明下一张联调任务需要怎么接入。
