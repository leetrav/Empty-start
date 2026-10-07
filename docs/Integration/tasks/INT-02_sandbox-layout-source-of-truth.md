# INT-02 Sandbox 主界面静态布局修正

## 开始前先阅读以下文档

- `AGENTS.md`
- `known_traps.md`
- `project.godot`
- `docs/Integration/tasks/INT-01_playable-battle-sandbox.md`
- `docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md`
- `data/stage_layout/stage_layout_profile.tres`
- `data/stage_layout/stage_layout_profile.gd`
- `scenes/sandbox/sandbox.tscn`
- `scenes/sandbox/sandbox_battle_hud.gd`
- `systems/barrage_generation/barrage_area.tscn`
- `systems/barrage_generation/barrage_area.gd`

本任务属于 UI / Scene Integration（界面与场景集成）任务。

INT-01 已经把普通战斗流程接通，但当前编辑器中看到的 Sandbox 版面与实际目标结构不一致，尤其中央 BarrageArea 仍带有旧原型尺寸，导致编辑器中出现“顶部一小块弹幕区 + 中间大面积空白”的错误布局。

本卡目标是让 **Godot 编辑器中直接打开 `sandbox.tscn` 时看到的结构，就是实际运行时使用的结构**。

---

## 本次目标界面

设计基准继续使用：

```text
1920 × 1080

左主播区：448 × 1080
中央区：1024 × 1080
右主播区：448 × 1080
```

现行分区尺寸已于 2026-10-07 按评审设计更新：信息区 `448×128`、立绘区 `448×432`、直播数据区 `448×520`；中央顶部状态区 `1024×72`、BarrageArea `1024×760`、底部交互区 `1024×248`。以下首次实施步骤保留为历史基线，复审后的实际尺寸以INT-02任务日志、StageLayoutProfile规格与当前Scene为准。

当前三栏内部Rect为：信息区 `(0,0,448,128)`、立绘区 `(0,128,448,432)`、直播数据区 `(0,560,448,520)`；中央顶部 `(0,0,1024,72)`、BarrageArea `(0,72,1024,760)`、底部 `(0,832,1024,248)`。以下初版步骤中的区域边界已由评审尺寸替代。

最终结构必须呈现为：

```text
┌────左主播────┬────────────中央────────────┬────右主播────┐
│              │ PK BAR | Tier / 状态       │              │
│              ├───────────────────────────┤              │
│              │                           │              │
│   主播画面    │                           │   对手画面    │
│              │      整块弹幕战斗区域       │              │
│              │                           │              │
│              │                           │              │
│ 我方直播数据  ├───────────────────────────┤  敌方直播数据   │
│              │ 蓄力 / 操作反馈            │              │
└──────────────┴───────────────────────────┴──────────────┘
```

### 区域职责

#### 左主播区

上部：

```text
玩家身份 / 主播名
主播画面
```

下部：

```text
我方直播数据
Viewer
Like
Comment
Fan
```

现有 `LiveDataHud` 继续放在这里。

#### 中央顶部

同一顶部状态区集中显示：

```text
PK BAR
玩家 PK
对手 PK
Tier
当前战斗状态
```

当前 `BattleStateFeedback` 应归入顶部状态区，不再占用中央弹幕主体区域。

#### 中央主体

从顶部状态区结束位置开始，一直到下方蓄力区开始位置：

```text
全部作为 BarrageArea
```

这部分是主要操作区域。

弹幕生成、移动、准心瞄准与命中都发生在这里。

中央主体不保留额外技术说明、标题、测试 Panel 或大块未使用空白。

#### 中央底部

固定为：

```text
蓄力进度
攻击阶段
操作反馈
操作提示
```

现有 `ChargeFeedback` 继续承担该职责。

#### 右主播区

上部：

```text
对手主播名
对手画面
```

下部：

```text
敌方直播数据
```

当前阶段可继续使用功能性占位 UI。

Tier 已经统一放到中央顶部，因此右侧下部不再重复显示 Tier 作为主要信息。

未来若策划补充敌方直播数据、对手状态或特殊机制提示，可在这个区域继续扩展。

---

## 本次任务

### 1. 修正 Sandbox 编辑器静态布局

直接调整 `scenes/sandbox/sandbox.tscn` 及相关 UI 场景，使 Godot 编辑器中打开 Sandbox 时就能看到正确的三栏布局。

编辑器中的场景预览需要和真实运行结果保持一致。

固定舞台结构包括：

```text
PlayerStreamerArea
BattleArea
OpponentStreamerArea
```

以及中央内部：

```text
TopBattleStatus
BarrageArea
ChargeFeedback
```

节点具体名称可以沿用已有结构或做最小调整，以最终 Scene Tree 清晰为准。

---

### 2. 让中央 BarrageArea 占满主体区域

现有 `BarrageArea` 子场景根节点仍保存旧原型锚点：

```text
anchor_top = 0.04
anchor_bottom = 0.24
```

这些值来自旧技术预览阶段。

本任务将 `BarrageArea` 调整为适合被父场景组合的中性布局组件，并让 Sandbox 实例明确占据中央主体矩形。

按当前设计：

```text
中央总尺寸：1024 × 1080
顶部状态区：72
底部蓄力 / 操作区：248

BarrageArea 高度：
1080 - 72 - 248 = 760
```

目标矩形：

```text
x = 0
y = 72
w = 1024
h = 760
```

在 Godot 编辑器里必须直接看到这块完整区域。

---

### 3. 整理中央顶部状态区

当前：

```text
PKBar
BattleStateFeedback
```

分别占据中央顶部和 BarrageArea 上方内容。

本任务统一为顶部状态区。

顶部状态区至少显示：

```text
玩家 PK
PK ProgressBar
对手 PK
Tier
BattleStateFeedback
```

可在 72 高度内通过上下两行、左右分区或其他简单布局实现。

当前目标是信息清楚、无遮挡、区域归属正确。

正式视觉包装后续由 UI / 美术继续替换。

---

### 4. 整理右侧直播数据区

当前 `OpponentStreamerArea/TierFeedback` 主要重复显示 Tier。

本任务将右侧下部整理为：

```text
EnemyLiveDataArea / 敌方直播数据
```

右侧下部固定为敌方直播数据区，与左侧“我方直播数据”形成对应。

当前如果还没有真实敌方直播数据的数据源，可先使用功能性占位结构：

```text
Viewer
Like
Comment
Fan
```

本卡只处理布局与展示结构，不自行设计敌方直播数据的增长公式、结算规则或数据来源。

Tier 的主要显示位置归中央顶部。

后续只在该区域接入真实敌方直播数据与美术表现。

---

### 5. 保持编辑器与运行时同一布局事实

当前 `SandboxBattleHud._ready()` 会调用：

```gdscript
_apply_stage_layout()
```

运行后重新设置多个 Control 的位置和尺寸。

本任务完成后，编辑器预览与运行时最终布局应保持一致。

可以继续使用 `StageLayoutProfile` 作为设计尺寸来源。

实现时选择当前工程中最简单、稳定的方式，例如：

```text
A. 将正确位置/尺寸直接保存进 Scene，并让运行时只负责整体缩放；
或
B. 使用 Godot 编辑器可执行的布局同步方式，让同一份 StageLayoutProfile 同时驱动编辑器和运行时。
```

最终要求只有一个：

```text
打开 sandbox.tscn
≈
运行 sandbox.tscn
```

关键区域的位置、尺寸和层级一致。

---

### 6. 保持 1920×1080 设计坐标与窗口缩放

现有 BattleHud 的整体缩放继续保留。

```text
设计坐标：1920×1080
实际窗口：按父窗口缩放
```

AimReticle 继续跟随 BattleHud 的统一缩放。

本卡只修布局结构与预览一致性，不改攻击判定规则。

---

## 本卡范围

本次只处理：

```text
Sandbox 主界面布局
Scene 静态尺寸
编辑器预览
中央 BarrageArea 尺寸
顶部状态区
左右主播区域
我方直播数据位置
敌方直播数据位置
蓄力区位置
窗口缩放后的布局一致性
```

普通战斗逻辑继续沿用 INT-01：

```text
CombatAttack
HitResolution
CombatStage
OpponentPKBar
Repeat
LiveData
ThreeTendencies
```

本卡不增加新的战斗规则。

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

### 1. 先检查真实 Scene

开始前使用 Godot 编辑器 / Godot-MCP-Native 查看：

- `sandbox.tscn` 当前实际 Scene Tree；
- BattleHud 当前 Control Rect；
- PlayerStreamerArea；
- BattleArea；
- OpponentStreamerArea；
- PKBar；
- BattleStateFeedback；
- BarrageArea；
- ChargeFeedback；
- LiveDataHud；
- AimReticle。

记录编辑器状态与运行时状态之间当前存在的尺寸差异。

---

### 2. 以 Scene 可读性为验收事实

任务完成后，策划、美术或其他程序直接打开：

`scenes/sandbox/sandbox.tscn`

即可理解整个直播 PK 主界面的真实空间结构。

关键布局信息应直接体现在：

- Scene Tree；
- Control Rect；
- Anchor / Offset；
- Container；
- StageLayoutProfile 驱动结果。

---

### 3. 保持现有系统接口

当前普通战斗的数据流和系统公开接口继续使用 INT-01 已有实现。

布局调整过程中同步确认：

- BarrageArea 仍可正常生成；
- AimReticle 仍能覆盖中央区域；
- PK / Tier UI 仍读取同一数据；
- LiveDataHud 仍绑定当前 LiveSessionData；
- Pause / FailureOverlay 层级正常。

---

### 4. UI 仍使用功能占位

当前重点是：

```text
结构
空间
层级
可读性
可操作性
```

主播画面继续使用占位色块。

敌方直播数据继续使用占位内容。

正式视觉风格由后续美术替换。

---

## 验证

本卡以编辑器人工检查 + 最小运行 smoke 为主。

至少验证：

1. Godot 编辑器直接打开 `sandbox.tscn` 时，三栏结构完整可见。
2. 左 / 中 / 右区域尺寸比例与 `StageLayoutProfile` 一致。
3. 中央顶部显示 PK BAR + Tier + 战斗状态。
4. BattleStateFeedback 不再占用 BarrageArea 主体空间。
5. BarrageArea 在编辑器中直接显示为完整 1024×760 主体区域。
6. BarrageArea 不再呈现旧原型的约 20% 高度。
7. 中央主体不存在大块无用途黑色空白。
8. 左下区域是我方 LiveData。
9. 右下区域明确保留为敌方直播数据。
10. 中央底部是蓄力 / 操作反馈。
11. 运行 Sandbox 后布局与编辑器预览一致。
12. 1920×1080 下布局正确。
13. 1152×648 等 16:9 窗口下整体缩放正确。
14. 普通弹幕仍在完整中央主体内生成、移动、裁剪。
15. AimReticle 显示与命中区域保持正常。
16. PK、Tier、蓄力、LiveData 更新仍正常。
17. FailureOverlay 与 PauseMenu 仍覆盖在主界面上层。
18. Godot Output / Debugger 没有新增与本任务有关的错误。

现有 INT-01 自动化测试继续作为回归参考。

本卡不为纯布局重复增加大规模集成测试。

---

## 本卡验收画面

最终在编辑器和运行时都应近似：

```text
┌────左主播────┬────────────中央────────────┬────右主播────┐
│              │ PK BAR | Tier / 状态       │              │
│              ├───────────────────────────┤              │
│              │                           │              │
│   主播画面    │                           │   对手画面    │
│              │      整块弹幕战斗区域       │              │
│              │                           │              │
│              │                           │              │
│ 我方直播数据  ├───────────────────────────┤  敌方直播数据   │
│              │ 蓄力 / 操作反馈            │              │
└──────────────┴───────────────────────────┴──────────────┘
```

验收重点：

```text
中央大面积 = 弹幕区域
顶部 = PK / Tier / 状态
底部 = 蓄力 / 操作
左下 = 我方直播数据
右下 = 敌方直播数据
```

---

## 日志

完成后新增：

`docs/Integration/Sandbox布局_INT-02_2026-10-06_log.md`

日志至少记录：

- 修改前编辑器布局问题；
- 最终 Scene Tree；
- 最终设计尺寸；
- 编辑器与运行时如何保持一致；
- BarrageArea 最终 Rect；
- 顶部状态区最终结构；
- 左右侧区域最终结构；
- 1920×1080 与至少一个缩放窗口的实际验证结果；
- 普通战斗回归结果；
- 当前仍等待美术替换的占位节点。

---

## 最终汇报

完成后汇报：

1. Sandbox 编辑器里现在看到的最终结构；
2. BarrageArea 最终尺寸与位置；
3. 顶部 PK / Tier / 状态如何排列；
4. 左侧主播 / LiveData 如何排列；
5. 右侧主播 / 敌方直播数据如何排列；
6. 蓄力区位置；
7. 编辑器与运行时是否一致；
8. 1920×1080 与缩放窗口验证结果；
9. INT-01 普通战斗是否保持正常。
