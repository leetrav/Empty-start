# ID-08 十二身份卡片选择与开局倾向映射

## 开始前先阅读以下文档
- AGENTS.md
- known_traps.md
- project.godot
- docs/System_Collaboration.md
- docs/Original/程序需求汇总.md
- docs/Original/任务卡模板.md
- docs/1. Identify/README.md
- docs/1. Identify/tasks/ID-01_identity-option-data.md
- docs/1. Identify/tasks/ID-03_identity-confirm-lock.md
- docs/1. Identify/tasks/ID-05_identity-setup-ui.md
- docs/1. Identify/tasks/ID-07_custom-fan-group-name.md
- 上述任务对应的最新身份系统完成日志
- data/source_tables/01_身份配置.csv（仓库内身份配置数据源）
- Google Sheets「2026聚光灯GameJam_策划数据总表」的「01_身份配置」工作表（策划编辑源）：https://docs.google.com/spreadsheets/d/1SorBVCqsy7wj7Fp1TmzCxZqDkxpo_ijYQSqLUWg72cY/edit

## 已经实现的功能
- IdentityOption Resource 现有稳定 identity_id、display_name、icon、tendency_id；三份 placeholder 资源分别代表正统、异端、荒谬。
- ui/identity_setup/identity_setup.gd 当前通过三份预载 Resource 创建横排选项按钮；identity_setup.tscn 保留主播名、粉丝团名、确认按钮。
- SaveData.identity_id 保存本周目确认的具体身份 ID；IdentityConfirmationState 实现首次确认及锁定；SaveManager 保存并读取。
- 身份确认时已调用 TendencyState.initialize_from_identity_option(option)，将 option.tendency_id 保存为本周目的开局倾向参照；17 三项倾向、20 结局继续消费已有事实。
- data/source_tables/01_身份配置.csv 已经拥有 12 条正式身份标题、描述及分类；tools/export_game_data.py 当前会校验/导出该 CSV，但还没有把这 12 条自动生成为身份选择页面使用的正式 IdentityOption Resource。
- 表格异端分类写作 heresy，游戏内稳定倾向 ID 为 heretical；导表工具的其他资源生成逻辑已有此明确转换先例。

## 本次任务
将开局页面的三种占位身份选择升级为「12 张身份卡片，实际对应 3 种倾向」的角色扮演选择界面。本卡专门负责身份选项数据接入、12 张卡片的单选 UI、具体身份 ID 与倾向映射。本系统的三个独立步骤「你叫什么？→身份选择→粉丝团取名」、最终一次性存档与进入开局房间由新增 **ID-09** 和 **RS-12** 负责；本卡的身份卡片应作为 ID-09 第二步的可复用视图。

### 1. 身份数据
- 在现有 IdentityOption 上补充适用于 UI 展示的 description 字段，沿用原有 identity_id、display_name、icon、tendency_id。
- 从 data/source_tables/01_身份配置.csv 的 12 条正式身份生成或建立可编辑 Godot Resource；沿用现有目录、类型与加载方式，采用最小必要实现。
- 每个身份保存自己的稳定 ID、显示标题、原文描述，以及对应的底层倾向。异端表格值 heresy 在运行时统一映射为 heretical。
- 同组四种身份的身份 ID 保持独立；三项倾向系统仍只接收 orthodox、heretical、absurd。
- 策划正文以源 CSV 为准，UI 显示原文；从表格同步时保持源字段及稳定 ID 一致。

正式 12 个身份如下（标题和描述作为本次实现的核对清单）：

| 身份 ID | 标题 | 描述 | 运行时倾向 |
| --- | --- | --- | --- |
| identity_orthodox_1 | 随侍 | 祂是你绝不会离开的人，也是你绝不会承认的人 | orthodox |
| identity_orthodox_2 | 最后的见证者 | 所有人都在猜测、争论神最后说了什么；只有你记得自己当时就站在祂旁边 | orthodox |
| identity_orthodox_3 | 圣伤 | 血与水从那道伤口流出，你是祂被打开的证明 | orthodox |
| identity_orthodox_4 | 殉道者 | 你从不相信世界会变好，但还是走上了那条道路 | orthodox |
| identity_heresy_1 | 神意重释者 | 你们理解错了，神真正说的是另一回事 | heretical |
| identity_heresy_2 | 第二先知 | 神第一次说得不够完整。幸运的是，祂还有你 | heretical |
| identity_heresy_3 | 净化者 | 异见者将受雷火天降，但没有说过必须由祂亲自动手 | heretical |
| identity_heresy_4 | 但书 | 神爱世人，但是总得有人替祂划掉几个例外 | heretical |
| identity_absurd_1 | 耶^^复活了 | 这就是神迹！......什么电线杆？ | absurd |
| identity_absurd_2 | 亲爱的朋友 | 你没有背叛任何人——至少目前没有 | absurd |
| identity_absurd_3 | 三二一上链接 | 神奇的优惠券将产品价格一百元变成九十九元，这难道不神奇吗？ | absurd |
| identity_absurd_4 | 必须想象 | 石头又滚回去了，请保持微笑 | absurd |

### 2. 十二槽位 UI
- 基准画面为 1920×1080、16:9。身份选择区同时显示 12 张卡，固定布局 **4 列 × 3 行**；在较小视口中保证文字、点击区域及确认控件可用，必要时由当前页面提供滚动。
- 每张卡片由大字号身份标题与较小字号完整描述组成；描述可以自动换行，保留足够的可读空间。
- 12 张卡片的固定混排顺序（按行从左到右）：

| 第 1 列 | 第 2 列 | 第 3 列 | 第 4 列 |
| --- | --- | --- | --- |
| 随侍 | 但书 | 耶^^复活了 | 第二先知 |
| 亲爱的朋友 | 圣伤 | 净化者 | 必须想象 |
| 殉道者 | 三二一上链接 | 最后的见证者 | 神意重释者 |

- 玩家侧卡片只展示角色扮演身份信息（标题、描述）与统一的交互反馈。视觉样式采用相同规则，不以倾向分组、不显示「正统/异端/荒谬」文字或「正/异/谬」占位标识，也不以倾向分配专属颜色/图标。
- 鼠标点击卡片可单选；选中态明确可见，再点另一张卡会更新选择。支持现有 PC 键盘焦点与确认操作。
- 本卡的身份选择步骤独立展示 12 张卡片、当前选中状态和前进确认操作；主播名输入属于 ID-09 第一步，粉丝团名输入属于 ID-09 第三步。卡片底色、描边、悬停/选中反馈优先使用 Godot 原生 Control、Theme、StyleBox 制作；此次以程序实现的 UI 为交付，不依赖新美术图片。
- 初次进入时由玩家主动选择其中一张卡片后再确认，保持单选行为。

### 3. 身份选择与下游交接
- 身份卡片提供具体稳定 identity_id 对应的选项数据给 ID-09 的开局第二步使用，包括运行时 tendency_id；选中「亲爱的朋友」时应交出 identity_absurd_2 与 absurd。选择同组其他身份时交出另一个具体 identity_id 和同样的 absurd 倾向。
- 本卡复用现有 IdentityOption 数据及选择状态；由 ID-09 在第三步粉丝团取名完成后复用 IdentityConfirmationState、SaveManager.set_identity_data()、TendencyState.initialize_from_identity_option() 一次性正式提交并保存。身份选择步骤点击「下一步」时进入粉丝团取名，不直接进入 Game 或 Rest。
- 在 ID-09 的流程内回退后再次显示身份卡片时，能按此前临时 identity_id 还原卡片选中态；本周目最终确认后沿用已有身份锁定规则。
- 检查旧三占位 identity_id 的存档读取表现，保留已有存档事实，并在任务日志记录兼容处理方式。

### 验收条件
1. 身份页显示恰好 12 个正式槽位，4×3 固定混排，全部可以选中；每张卡片准确显示其标题和完整描述。
2. 玩家侧看不到底层倾向分组、倾向文字、倾向字标或分组色；不同倾向的卡片采用一致视觉规则。
3. 12 个身份 ID 两两不同，运行时分类恰好 orthodox / heretical / absurd 各四个。
4. 「亲爱的朋友」及同组另一张身份分别向 ID-09 返回不同 identity_id 和相同 absurd 倾向；正统、异端组各抽一张验证对应映射。实际 SaveData / TendencyState 提交与保存由 ID-09 联调。
5. 第二步只显示身份选择界面；选中任一卡片确认后进入 ID-09 第三步粉丝团取名；回到本步时可恢复临时选中态。最终身份存档、读档和进入房间通过 ID-09 / RS-12 联调。
6. 1920×1080 实际运行中 12 张卡、选中操作与前进确认完整可用；较小 16:9 窗口中没有阻断选择或确认的遮挡。两个姓名输入框分别由 ID-09 的步骤一、步骤三验收。
7. 正式身份配置保持可编辑，正式文字来自仓库数据源；下游 17 和 20 无需改写原有三项倾向规则。

### 本任务测试约束
- 对 12 个稳定 ID 和 4/4/4 倾向映射进行一次集中数据核对，复用现有身份锁定与存档测试；若确需新增自动化，限一个针对身份映射的关键回归用例。
- 真实 Godot 运行身份卡步骤验证布局、选中/焦点及切换到第三步；最终存档/场景跳转在 ID-09 和 RS-12 的完整流程中验收，同时检查 Output/Debugger。
- 完成后的任务日志记录测试输入、可见结果、保存身份 ID 与开局倾向，以及实际运行环境。

## Godot 开发环境
Godot 版本：4.7.2

脚本语言：GDScript

项目根目录：仓库根目录

目标平台：Windows / Android（本卡优先验收 PC UI；Android 实机触控由平台联调验收）

Godot 工程操作 MCP：Godot-MCP-Native

Godot 官方文档 MCP：godot_mcp

## 执行要求
1. 开工前根据最新 main 检查相关 Scene、Resource、导表输出与公开接口，阅读 AGENTS.md、known_traps.md 和上述依赖，确认文件 Owner 与并发工作区。
2. 保持身份系统的现有职责与保存方向；仅为 12 身份展示和选择增加必要数据、UI 与绑定代码。优先复用原有 Theme、Button、GridContainer 等 Godot 能力，以及已有身份校验与存档接口。
3. 涉及表格同步与新字段时核对「Google Sheet → 源 CSV → 身份 Resource → UI → SaveData / TendencyState」的一致性；保留原始 ID 与中文文本，注意 heresy / heretical 边界。
4. 以身份选择 UI 为单一修改目标，尽量集中在 data/identity/、ui/identity_setup/ 和必要的最小导表/验证代码中；遵循 AGENTS.md 的高内聚、中文简注、现有节点所有权与信号边界。
5. 通过 Godot 4.7.2 验证资源解析、12 槽位、选中状态和可复用的身份步骤；在 ID-09 合并联调时再验证最终提交、保存与开局房间入口。
6. 完成后更新 docs/1. Identify/README.md 中相关接口/实现状态，并新建 docs/1. Identify/身份系统_ID-08_YYYY-MM-DD_log.md；独立分支提交实现并按当前 PR/Review 流程交付。

## 最终汇报
- 主要修改文件、Scene 与 Resource；
- 12 张卡片最终布局与文本来源；
- identity_id 与 tendency_id 的实际存档/传递结果；
- Godot 实际运行验证；
- 旧存档与小视口的处理情况；
- 尚待策划或美术确认的内容。
