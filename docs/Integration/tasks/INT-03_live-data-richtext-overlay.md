# INT-03 直播数据富文本叠层 UI

## 开始前先阅读以下文档

- `AGENTS.md`
- `known_traps.md`
- `project.godot`
- `docs/Integration/tasks/INT-02_sandbox-layout-source-of-truth.md`
- `docs/9. LiveDataPresentation/README.md`
- `ui/live_data/live_data_hud.tscn`
- `ui/live_data/live_data_hud.gd`
- `scenes/sandbox/sandbox.tscn`
- `scenes/sandbox/sandbox_battle_hud.gd`

本任务属于 LiveDataPresentation（直播数据表现）与 Sandbox UI 集成任务。

INT-02 已确定左右两侧底部为直播数据区域。本卡只修改直播数据的视觉结构与富文本承载方式，不修改普通战斗核心规则。

---

## 已确认的设计

### 1. 特殊道具已经从当前设计中砍掉

当前仓库没有特殊道具系统、运行数据、场景或交互逻辑。

仓库里与“特殊道具 / 道具”相关的内容只存在于 `docs/Original/` 的旧原始需求中，保留用于历史追溯。

本卡不建立特殊道具槽位、不预留特殊道具逻辑，也不迁移任何道具系统。

左右两侧原本用于特殊道具的空间已经并入直播数据区域。

按 INT-02 当前布局，左右直播数据区使用其最终已确认尺寸。

---

## 本次目标

当前 `LiveDataHud` 使用：

```text
PanelContainer
└── 2×2 数据卡
    观看人数
    点赞数
    评论数
    粉丝数
```

这一表现不符合目标。

本卡改成接近普通直播 App 的边缘叠层数据：

### 我方

靠左侧直播区域的外侧边缘：

```text
👤233
👍233
🔊233
👥233
```

### 敌方

靠右侧直播区域的外侧边缘：

```text
233👤
233👍
233🔊
233👥
```

实际游戏中只显示：

```text
ICON + 数字
```

不显示：

```text
观看人数
点赞
评论
粉丝
```

这些中文名称只用于程序和策划理解字段含义。

---

## 图标约定

当前美术 ICON 尚未接入时，先使用 Emoji 占位：

| 数据 | 临时 ICON |
| --- | --- |
| Viewer / 观看人数 | 👤 |
| Like / 点赞 | 👍 |
| Comment / 评论 | 🔊 |
| Fan / 粉丝 | 👥 |

Emoji 只是临时表现。

后续正式 ICON 到位时，应允许替换显示内容，不修改直播数据的数据来源和更新逻辑。

---

## 富文本要求

四项数据的可见文本使用 `RichTextLabel`。

原因：

后续直播数据变化可能需要表现：

- 数字跳动；
- 瞬时放大；
- 颜色变化；
- 闪烁；
- 某一段文本单独变色；
- ICON 与数字使用不同表现；
- 其他 RichText / BBCode / RichTextEffect 表现。

本卡只需要把 UI 承载方式改为 `RichTextLabel` 并留出清晰的表现入口。

本卡不提前实现复杂动画系统、自定义 RichTextEffect 或统一特效框架。

---

## 本次任务

### 1. 移除现有数据卡 Panel 表现

当前：

```text
LiveDataHud
└── MarginContainer
    └── Rows
        └── Header
            └── StatsPanel
                └── Metrics
                    ├── TopRow
                    └── BottomRow
```

其中 `StatsPanel` / CardPanel 不再保留为直播数据背景。

直播数据应直接叠在直播区域边缘，不再像设置菜单或统计卡片。

最终可视结构应接近：

```text
LiveDataHud
└── Metrics
    ├── ViewerMetric
    ├── LikeMetric
    ├── CommentMetric
    └── FanMetric
```

具体是否使用 VBoxContainer 由实现选择，只要 Scene Tree 简单清晰。

---

### 2. 每项数据使用 RichTextLabel

四项分别使用独立 `RichTextLabel`：

```text
ViewerMetric
LikeMetric
CommentMetric
FanMetric
```

这样后续某一项发生变化时，可以独立做：

```text
scale
modulate
theme override
BBCode
RichTextEffect
Tween
```

本卡不把四个数字拼成一整个 RichTextLabel。

---

### 3. 我方直播数据左对齐

我方数据位于左主播区的直播数据区域。

布局规则：

```text
靠左侧外边缘
左对齐
从上到下竖排
```

显示格式：

```text
👤233
👍233
🔊233
👥233
```

ICON 在前，数字在后。

四行应保持一致的起始边界。

直播数据区域本身不需要 Panel 背景。

---

### 4. 敌方直播数据右对齐

敌方数据位于右主播区的直播数据区域。

布局规则：

```text
靠右侧外边缘
右对齐
从上到下竖排
```

显示格式：

```text
233👤
233👍
233🔊
233👥
```

数字在前，ICON 在后。

四行应保持一致的右边界。

我方和敌方形成镜像关系：

```text
我方：👤233        233👤：敌方
     👍233        233👍
     🔊233        233🔊
     👥233        233👥
```

---

### 5. LiveDataHud 支持左右两种展示方向

优先复用当前 `LiveDataHud`，通过最小配置支持：

```text
PLAYER / LEFT
OPPONENT / RIGHT
```

该配置只控制表现：

- ICON 在数字前还是后；
- 左对齐还是右对齐；
- 靠左外边缘还是靠右外边缘。

数据字段本身仍然是：

```text
viewer_count
like_count
comment_count
fan_count
```

不要为左右两边复制两套完全相同的 HUD 逻辑。

---

### 6. 我方继续读取真实 LiveSessionData

当前我方数据继续绑定：

```gdscript
SaveManager.data.live_session
```

并继续响应：

```text
LiveSessionData.changed
```

已有 Viewer / Like / Comment / Fan 数值更新接口继续复用。

INT-01 已接通的 Comment 更新不能被本卡破坏。

---

### 7. 敌方当前只做表现入口，不新增虚构业务规则

当前仓库还没有正式敌方直播数据的数据所有者与增长规则。

因此本卡只让敌方 HUD 具备显示四项数据的能力。

允许提供一个最小公开表现入口，例如：

```gdscript
set_values(viewer_count, like_count, comment_count, fan_count)
```

或等价的简单接口。

该接口只把传入数字映射到 RichTextLabel，不保存第二份业务真相。

Sandbox 当前可以使用明确的占位值验证布局。

本卡不自行设计：

- 敌方 Viewer 如何变化；
- 敌方 Like 如何变化；
- 敌方 Comment 如何变化；
- 敌方 Fan 如何变化；
- 与 PK / Tier 的计算关系。

未来真实敌方直播数据系统建立后，再把其数据源绑定到同一 HUD。

---

### 8. 为后续数值动画保留最小表现入口

每项数据更新时，结构上应可以独立定位对应的 RichTextLabel。

建议在 `LiveDataHud` 内保持清晰的方法，例如：

```gdscript
_refresh_viewer()
_refresh_like()
_refresh_comment()
_refresh_fan()
```

或统一的内部刷新逻辑。

可以保留一个最小的表现调用点，例如：

```text
数值发生变化
→ 更新 RichTextLabel
→ 后续可在这里调用该项动画
```

本卡不实现完整跳字动画。

---

## 目标 Scene 结构参考

```text
PlayerStreamerArea
├── ...
└── PlayerLiveDataHud
    └── Metrics
        ├── ViewerMetric    RichTextLabel  "👤233"
        ├── LikeMetric      RichTextLabel  "👍233"
        ├── CommentMetric   RichTextLabel  "🔊233"
        └── FanMetric       RichTextLabel  "👥233"

OpponentStreamerArea
├── ...
└── OpponentLiveDataHud
    └── Metrics
        ├── ViewerMetric    RichTextLabel  "233👤"
        ├── LikeMetric      RichTextLabel  "233👍"
        ├── CommentMetric   RichTextLabel  "233🔊"
        └── FanMetric       RichTextLabel  "233👥"
```

节点名称可按当前 Scene 最小调整。

---

## 视觉原则

目标参考普通直播 App：

- 数据直接悬浮在直播画面 / 直播区域上；
- 没有大块 CardPanel；
- 没有统计仪表盘感；
- ICON + 数字是主要信息；
- 靠边显示，不占据中间主体；
- 我方和敌方镜像；
- 文本可继续承担动态视觉表现。

当前阶段仍使用项目现有字体和 Theme。

正式 ICON、字体、描边、阴影、发光等由后续 UI / 美术任务继续处理。

---

## Godot 开发环境

Godot 版本：4.7.2

脚本语言：GDScript

目标平台：

- PC
- Android

Godot 工程操作 MCP：

- Godot-MCP-Native

Godot 官方文档 MCP：

- godot_mcp

---

## 执行要求

### 1. 先确认 INT-02 实际结果

开始前检查当前开发分支和最新 Sandbox Scene。

INT-03 基于 INT-02 最终布局继续工作。

确认：

- 左右直播数据区域最终 Rect；
- 左右主播区真实 Scene Tree；
- 当前 `LiveDataHud` 实例位置；
- 当前是否已经存在敌方 LiveDataHud 占位；
- 编辑器与运行时布局是否一致。

如果 INT-02 尚未合入当前分支，先基于 INT-02 的真实完成结果继续，不重新实现其布局任务。

---

### 2. 保持数据与表现边界

`LiveSessionData` 继续拥有我方直播数据。

`LiveDataHud` 只负责读取和显示。

敌方当前没有正式数据所有者时，仅提供显示入口和占位验证。

---

### 3. 使用 RichTextLabel

实际可见的四项直播数据使用 `RichTextLabel`。

配置：

- 支持 BBCode / 富文本；
- 不拦截鼠标；
- 文本不遮挡战斗输入；
- 不出现滚动条；
- 单行内容保持完整可见。

如 Godot 4.7.2 的具体 RichTextLabel 属性存在疑问，先查询官方文档。

---

### 4. 不建立额外 UI 框架

本卡只需要：

- 4 个 RichTextLabel；
- 左 / 右展示方向；
- 数据刷新；
- 最小未来动画入口。

不建立通用直播 UI 框架、复杂动画管理器或新的 Autoload。

---

## 验证

本卡以编辑器检查 + 实际运行人工验收为主。

至少验证：

1. 我方直播数据区没有 StatsPanel / CardPanel 背景。
2. 我方显示为：
   `👤数字`
   `👍数字`
   `🔊数字`
   `👥数字`
3. 我方四行靠左侧外边缘并左对齐。
4. 敌方显示为：
   `数字👤`
   `数字👍`
   `数字🔊`
   `数字👥`
5. 敌方四行靠右侧外边缘并右对齐。
6. 实际游戏不显示“观看人数 / 点赞数 / 评论数 / 粉丝数”等字段标题。
7. 四项实际控件均为 `RichTextLabel`。
8. Viewer / Like / Comment / Fan 四项可独立更新。
9. 我方仍正确读取 `SaveManager.data.live_session`。
10. INT-01 已有 Comment 自动增长显示继续正常。
11. 敌方 HUD 能通过最小公开入口显示四个测试值。
12. 左右直播数据不覆盖角色立绘主体和中央 BarrageArea。
13. 数据 UI `mouse_filter` 不影响攻击和准心操作。
14. 编辑器与运行时位置一致。
15. 1920×1080 下布局正确。
16. 1152×648 等 16:9 缩放窗口中仍贴近各自外侧边缘。
17. Godot Output / Debugger 没有新增相关错误。

本卡不新增大规模自动化测试。

已有 LiveData / INT-01 回归入口可继续复用。

---

## 本卡验收画面

左侧：

```text
┌──────────────────────┐
│ 👤233                │
│ 👍233                │
│ 🔊233                │
│ 👥233                │
│                      │
│      直播区域         │
└──────────────────────┘
```

右侧：

```text
┌──────────────────────┐
│                233👤 │
│                233👍 │
│                233🔊 │
│                233👥 │
│                      │
│      直播区域         │
└──────────────────────┘
```

核心要求：

```text
我方：ICON → 数字，贴左外侧
敌方：数字 → ICON，贴右外侧
无 Panel
无字段标题
使用 RichTextLabel
```

---

## 日志

完成后新增：

`docs/Integration/直播数据富文本_INT-03_2026-10-06_log.md`

日志至少记录：

- 修改前 LiveDataHud 结构；
- 最终 LiveDataHud Scene Tree；
- 左右展示模式如何配置；
- 四项 RichTextLabel 节点；
- 我方真实数据绑定；
- 敌方当前占位数据入口；
- INT-01 Comment 更新回归结果；
- 编辑器与运行时截图 / 实际验证结果；
- 当前等待正式 ICON 和数值动画的内容。

---

## 最终汇报

完成后汇报：

1. 移除了哪些旧 Panel / Card UI；
2. 我方四项直播数据最终位置与格式；
3. 敌方四项直播数据最终位置与格式；
4. RichTextLabel 如何组织；
5. 我方真实 LiveSessionData 是否保持正常；
6. 敌方当前如何输入占位数值；
7. Comment 自动更新是否正常；
8. 不同分辨率下靠边布局是否正确；
9. 后续正式 ICON 与跳字 / 变色效果从哪里接入。
