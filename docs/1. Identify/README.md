# 1. Identify 身份系统任务拆分

## 系统目标

身份系统负责本周目的三件基础信息：

1. 玩家确认的主播名；
2. 玩家确认的粉丝团名；
3. 玩家确认的开局身份。

确认后的主播名、粉丝团名和身份需要进入本周目数据，当前关卡重开时继续沿用。后续需要展示玩家侧信息的系统读取对应字段；【三项倾向系统】和【结局系统】读取开局身份。

本系统当前不负责三项倾向的累计，也不负责结局判词。它只把“开局是谁”保存好并提供给后续系统。

## 当前数据约定

- `IdentityOption` 是可编辑的 Godot `Resource`，包含稳定身份 ID、显示名称、完整原文 `description`、`Texture2D` 图标引用和倾向 ID。
- 倾向 ID 使用 `orthodox`、`heretical`、`absurd`，供后续系统读取；身份系统不负责累计倾向。
- 身份确认后，身份设置页将所选 `IdentityOption.tendency_id` 交给 `SaveData.tendency_state.initialize_from_identity_option()`，只提供开局比较参照。
- `data/identity/identity_*_1.tres` 至 `*_4.tres` 提供 12 份正式身份资源，标题、描述与 ID 来自 `data/source_tables/01_身份配置.csv`，图标保持为空。`IdentityOptions.CARDS` 保存任务卡规定的混排顺序；三份旧占位资源仅保留兼容用途，`IdentityOptions.find_option()` 可按正式或旧 ID 查询。
- `IdentityNameRules.confirm_streamer_name()` 与 `confirm_fan_group_name()` 共用 `confirm_name()` 规则；空字符串和纯空白回退到各自默认值，其他输入原样保留。
- 默认主播名目前为临时值“新主播”，正式文案确定后修改 `IdentityNameRules.DEFAULT_STREAMER_NAME`。
- 默认粉丝团名目前为临时值“新粉丝团”，正式文案确定后修改 `IdentityNameRules.DEFAULT_FAN_GROUP_NAME`。
- `IdentityConfirmationState` 首次只接受调用方从当前身份资源整理出的有效 ID，之后拒绝覆盖；运行持有者通过 `get_confirmed_identity_id()` 读取结果。
- `IdentityConfirmationState` 锁定后的身份 ID 可通过 `SaveManager.set_identity_data()` 写入 SaveData，供本周目场景重建后继续读取。
- `SaveData.streamer_name`、`SaveData.fan_group_name` 与 `SaveData.identity_id` 保存本周目确认结果；新周目初始化为空值，确认后由 `SaveManager.set_identity_data()` 一次写入。
- 新增字段有明确空值默认，并兼容旧版 SaveData，因此 `SaveData.CURRENT_VERSION` 保持 `1`。
- `ui/identity_setup/identity_setup.tscn` 提供主播名、粉丝团名、身份选项和当前选中态；确认时调用共享名称规则与身份锁定、写入并保存 SaveData，再由 SceneRouter 进入 Game。
- 旧身份设置页在图标为空时仍用倾向字标占位；ID-08 新身份步骤只展示正式标题、描述，图标字段保留且不用于分组表现。

## 当前仓库状态

- 身份流程已接通：主菜单 Start 新建 SaveData 并进入身份设置；确认后保存主播名、粉丝团名和身份 ID，并初始化三项倾向系统的开局参照，再由 SceneRouter 进入当前 Game 入口。
- 身份选项数据类型、12 份正式资源、三份旧兼容资源、独立身份步骤、名称确认、身份锁定、周目存档字段和旧身份设置页面已建立。
- `SaveManager` 已存在，并持有 `SaveData`。
- `SaveData` 包含版本、游玩时间、当前场景、checkpoint、主播名、粉丝团名和身份 ID 字段。
- 当前 `SceneRouter.goto_game()` 仍指向 Sandbox 技术测试场景，后续替换真实游戏入口时更新。
- 当前仓库没有独立单元测试框架。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| ID-01 | 定义身份选项数据 | 无 |
| ID-02 | 确认主播名，空白使用默认名 | 2 个关键单元测试 |
| ID-03 | 确认身份并在本周目锁定 | 2 个关键单元测试 |
| ID-04 | 把姓名和身份写入 SaveData | 无新增自动化测试 |
| ID-05 | 做身份设置界面 | 无新增自动化测试 |
| ID-06 | 接通主菜单 → 身份设置 → 游戏 | 无新增自动化测试 |
| ID-07 | 自定义粉丝团名并写入本周目数据 | 复用 ID-02 名称确认测试 |
| ID-08 | 十二身份卡片选择与开局三倾向映射（独立步骤已实现） | 1 个 CSV/映射回归用例、原锁定测试、真实图形 UI smoke 通过 |
| ID-09 | 三步开局流程：主播取名 → 12 身份卡 → 粉丝团取名，最终进入房间（待实施） | 复用原有存档测试与真实流程 smoke；RS-12 负责开局房间入口 |

## ID-08 可复用身份步骤（2026-10-09）

- `ui/identity_setup/identity_selection.tscn` 是身份第二步的独立全屏视图。基准 1920×1080 同时展示 4×3 卡片；1280×720 提供纵向滚动，960×540 提供双向滚动，状态与下一步控件常驻。卡片标题 30px、描述 21px，统一沿用现有 Theme，不显示底层倾向或图标。
- `selection_changed(option: IdentityOption)` 通知临时选择变化；`next_requested(option: IdentityOption)` 交出具体身份和倾向。视图自身没有 SaveManager、TendencyState 或 SceneRouter 调用。
- `restore_selection(identity_id: StringName, locked: bool = false)` 支持入树前设置与回退恢复。`get_selected_option()` 读取选择；重新显示后调用 `focus_selection()` 恢复键盘焦点。初始空选，下一步禁用。
- ID-09 持有临时 ID，连接 `next_requested` 后切入第三步粉丝团取名，最终复用既有身份锁定、存档与倾向初始化入口提交。真实三步流程及 RS-12 房间跳转仍待对应任务完成。本卡运行 smoke 使用明确标注的临时 TEST_ONLY 第三步接收端。
- 已确认的旧 `identity_orthodox`、`identity_heretical`、`identity_absurd` 以 `locked=true` 恢复时沿用旧 Resource、原 ID 和原开局倾向，卡片禁用、显示沿用记录；不映射到任何新角色。未知已存 ID 同样锁住并禁用下一步。调用方继续负责最终确认锁定。
- 本次资源直接由既有 CSV 建立，正文未改动；Google Sheet 在线内容未能访问。现有导表工具仍负责 Sheet → CSV，后续修改身份正文时同步相应 `.tres` 并运行 `tests/unit/identity_mapping_test.gd` 核对完整正文与映射。没有增加导表基础设施。
- 原 `identity_setup.tscn/.gd` 保留原有同页输入与保存入口，等待 ID-09 接线替换；ID-08 没有更改主菜单、Sandbox 或存档流程。

## 已确认的三步开局需求（ID-09 待实施）

- 开局身份从当前 3 个占位选项升级为 12 张正式身份卡片，每张卡片展示标题与完整描述；正式内容来自 data/source_tables/01_身份配置.csv，与 Google Sheets 的「01_身份配置」对应。
- 12 张卡片在 1920×1080 的身份页面固定采用 **4 列 × 3 行**混排，顺序详见 ID-08 任务卡。玩家侧仅看到角色扮演信息与统一交互反馈，内部三个倾向仅用于游戏逻辑。
- 12 个独立 identity_id 分别保存具体选中身份，对应的运行时 tendency_id 仍只有 orthodox、heretical、absurd（每类 4 个）。表格中的 heresy 在 Godot 运行时映射为 heretical。
- 现有 SaveData、IdentityConfirmationState、TendencyState 的存档与开局比较职责沿用；**主播名、身份选择、粉丝团名分成三个依次进入的独立全屏步骤**，各自仅显示当前步骤的输入/选择。
- ID-09 确定顺序为「你叫什么？」→ 12 身份卡 →「粉丝团叫什么？」；最终确认后统一保存三项身份数据及开局倾向，然后经 RS-12 入口进入**休息时刻的主角房间**。第一场普通战斗须从房间主动开始。
- 本节记录已确定设计；ID-08 独立身份卡视图已实现，ID-09 / RS-12 仍待开发与完整流程验收，当前主菜单入口仍沿用旧页面。

## 测试预算

身份系统只给容易被以后改坏、同时可以快速运行的纯逻辑写单元测试：

- 空白主播名和粉丝团名会分别回退到各自默认名字；
- 正常主播名和粉丝团名会保留玩家输入；
- 第一次身份确认会成功；
- 本周目已经确认后，第二次选择不会改掉身份。

静态 Resource 字段、UI 排版、按钮连接、场景切换和现有 SaveManager 流程不逐项增加单元测试。

这些功能继续按任务卡做最小 Godot 解析、资源加载和实际运行检查。

## 后续系统怎么拿身份数据

ID-07 完成后，本周目的主播名、粉丝团名和身份使用稳定数据保存在 `SaveData` 中。

后续：
- 【三项倾向系统】读取开局身份作为比较依据；
- 直播 UI、休息时刻等需要展示玩家侧信息时读取 `fan_group_name`；
- 【结局系统】读取主播名和开局身份。

等 17、20 系统开发时再做具体接线，不在身份系统阶段提前实现它们。
