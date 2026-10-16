# INT-17E · Lane E · 27 表正式资源同步、美术绑定和结局素材闭环

## 开始前先阅读以下文档
- `AGENTS.md`
- `project.godot`
- `known_traps.md`
- `docs/Original/任务卡模板.md`
- `docs/Integration/tasks/SHEET-R2-E_importer-story-assets.md`
- `docs/Integration/tasks/SHEET-R2-F_production-integration-export.md`
- `data/source_tables/01_身份配置.csv`
- `data/source_tables/02_主播关卡.csv`
- `data/source_tables/03_普通词库.csv`
- `data/source_tables/04_矛盾内容.csv`
- `data/source_tables/13_吞并奖励.csv`
- `data/source_tables/14_败者卡.csv`
- `data/source_tables/16_结局配置.csv`
- `data/source_tables/18_表现资产.csv`
- `data/source_tables/23_对手立绘配置.csv`
- `tools/export_game_data.py`
- `data/shared/presentation_asset_config.tres`
- 与本卡涉及系统直接相关的正式 README、最新日志、Godot 生产 Scene/Resource、当前 PR 差异

## 已经实现的功能
- #230/#232 已将 27 张正式 CSV 和四关 `LevelProfile`、普通词库、Tier 导表资源带入 main；现行 `--approved-csv` 主要输出池、四关、Tier，并未同步全部运行消费 Resource。
- 目前 R26-E 有带未提交修改的现有本地 worktree：新增 `--audit-csv`、身份逐字段漂移检查、13 表奖励候选字段等，但完整报告和真实运行受 Python 权限及 Godot 导入缓存阻断，不能覆盖其工作。
- 13 表 5 行全禁用、14 表 4 行全禁用；16 表九种教名和四句判词仍为占位，三张主图仍缺，18 是资产状态台账，非可加载 Resource 路径。

## 本次任务
1. 继续现有 R26-E 的实际未完成变更，把已批准的 27 张 CSV 按字段与生产消费者映射列成可复查清单；复用当前导表器，不为字段审计新建复杂门禁。按源表的具体 ID 标记已生效、旧资源覆盖、配置未接线、禁用、资产缺失、文本未填。
2. 修复 `--approved-csv` 对已确定数值与数据对象的正式刷新覆盖：至少纳入与 A 协作的 06/09、08 music_event_id 与 01 正式身份一致性；不要把文档状态值当资源路径，不创建另一套运行时来源。
3. 按 02/23/18 清点四关 4 名主播正式立绘（包括 T1/T2/T3、击败过渡和背景）、仓鼠主角直播前景与素材路径，已入库资产写回现有配置，由 D/INT-16 读取；资源确实缺失时列源行 ID，不自创图片。
4. 13/14 维持按 disabled 跳过；16 表用当前可用明确字段填入现有结局资源，保留九种教名、四条判词和三张主图真实缺失状态。为 INT-16 交付独立结局漫画的资源路径/SceneRouter 接线建议，开场 P5～P6 继续属于开场，不冒充通关漫画。
5. 运行正式 4 关数据导入与 Godot Resource 复核，确认复导之后不再恢复旧值；交付 27 表逐字段报告、资产实际使用对照及最短补齐清单。

### 文件归属和并行交接
- 本 Lane 独占 `tools/export_game_data.py`、`data/level_configuration/` 的 Resource 生成逻辑、`data/identity/`、`data/ending/`、`data/shared/presentation_asset_config.tres` 和字段审计报告。
- 与 A 约定 `CombatStageTierConfig.music_event_id` 的数据格式，由 A 在 Tier 状态发事件；与 D 接口交付素材，不修改 `scenes/sandbox/sandbox_battle_hud.gd`，也不修改 INT-16 的根流程文件。

### 本卡验收
- 正式四关、身份与导表层数据可从生产 Resource 中读取；审计报告列出 27 表每个实际字段状态与消费者。
- 真实源文件存在且有明确业务归属的立绘/背景/音频可供 D 与 INT-16 绑定；16 结局现有素材能被消费，缺失明确。
- 保留既有 R26-E 进度，在本 Lane 维护原有改动后完成连续集成并提交。

### 本轮最短集成工作流
1. 先核对目前 main、所属 Lane 的既有工作树、未提交改动及当前相关 PR；在已实现的功能上增量修复。先打通真实玩家可触发的调用链，完成最小运行验证后提交。
2. 已经合并的 PR 保留；对仍开放的 PR 采用增量提交、必要时由总控负责合并和冲突处理，持续朝最终 main 集成推进。优先复用现有组件和测试，不以重新编写任务卡或重新提相同功能 PR 替代修复。
3. 每项实际改动一个 commit；按仓库日志规范交付。影响视觉/音效时提供真实 Godot 截图或录屏和触发步骤，让真人验收。
4. 本卡属于 Lane A–E 并行消费端收口；`scenes/sandbox/sandbox.gd`、`core/save/save_data.gd`、`data/level_configuration/level_run_state.gd`、`ui/rest/rest_opening_room.gd` 为正在推进的 INT-16 集成者所有。向该 Owner 交付可调用 API、参数、事件及按顺序接线的位置。
5. 本轮派工只通过已有 Codex Desktop/图形化 Agent 入口，**不得使用 CLI 派工或启动**。执行会话要求完全权限 `danger-full-access`、审批策略 `never`；只能由真实启动入口设置和确认。Agent 工作过程中按项目当前可用的 Godot MCP、代码编辑器和已连接工具验证。

### 完成日志
`docs/Integration/生产集成_INT-17E_2026-10-16_log.md`

## Godot 开发环境
Godot 版本：4.7.2
脚本语言：GDScript；已有导表器保持 Python
项目根目录：`D:\\Godot\\Empty-start`（使用现有 Lane 独立工作树）
目标平台：Windows x64、Android ARM64；正式分辨率 1920×1080
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
如果 MCP 当前不可用，如实说明，并使用已有 Godot 编辑器、项目插件和连接工具完成可行的验证；本轮派工不得使用 CLI。

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


### 本卡额外交接
- 以“已合并功能是否在正式玩家路径产生效果”为验收标准；列出具体入口、源 Resource/CSV、触发事件、实际画面/音效和验证材料。
- 与仍开放的相关 PR 直接继续增量修复，解决冲突以尽快主线集成为先；由总控负责 PR Review、合并顺序和集成验证。
- 汇报当前 PR/commit、同一任务各子任务的提交、Godot 真正运行的证据和交给 INT-16 的最小公开调用接口。
