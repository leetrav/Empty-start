# Sandbox 布局 INT-02 任务日志

日期：2026-10-06

状态：静态布局与运行验收完成

分支：`codex/int-02-sandbox-layout`，从最新 `origin/main` 的 `743c006` 开始；INT-01 已通过 PR #9 合入 main。本任务工作树开工时干净，主工程 `D:/Godot/Empty-start` 的未提交配置与生成文件保持原样。

## 修改前的问题

Godot-MCP-Native 实际读取编辑器节点：BarrageArea 在 BattleArea 内为 `(40.96,43.2,942.08,216)`，锚点仍是旧预览的4%～24%。运行后 HUD 才改为 `(0,72,1024,896)`，形成两种空间事实。

BattleStateFeedback 位于 `(24,88)`，尺寸 `976×68`，占用弹幕主体上部；右侧下部重复显示 Tier。LiveDataHud 内卡片仅占部分宽度，敌方直播数据区域尚未建立。

## 实际修改

- `scenes/sandbox/sandbox.tscn`：保存所有设计 Rect；新增 TopBattleStatus，将 PK、Tier、战斗状态集中在顶部72高；明确 BarrageArea 实例区域；将右下 TierFeedback 替换为 EnemyLiveDataArea。
- `scenes/sandbox/sandbox_battle_hud.gd`：删除运行时 `_apply_stage_layout()`、`_set_design_rect()` 与未消费的舞台资源字段；继续整体缩放、更新只读数据和准心位置。状态中的换行只在显示端转换为“ · ”。
- `systems/barrage_generation/barrage_area.gd/.tscn`：根节点改为中性 Full Rect，删除旧 `stage_layout_profile` 导出字段、资源绑定与启动时锚点重写。生成、倍率、容量、移除及复读公开方法保留。
- `ui/live_data/live_data_hud.tscn`：添加“我方直播数据”标题，卡片填满内部宽度；数据绑定脚本保持原样。
- 既有测试只做引用适配：中央 Tier 断言、状态 unique-name、我方 Comment 查找范围、删除过时的 fixture 布局资源赋值。检查数量维持84，没有新增持久用例。
- 系统3、系统9、Shared正式文档及 `known_traps.md`。

未修改攻击判定、PK收益、Tier规则、回拉、复读、倾向或敌方数据公式；未修改关卡、攻击配置、StageLayoutProfile数值及项目显示配置。

## 最终 Scene Tree

```text
Sandbox
├── Background
├── BattleHud
│   ├── PlayerStreamerArea
│   │   ├── PlayerName / PlayerPortraitPlaceholder
│   │   └── LiveDataHud（我方真实数据）
│   ├── BattleArea
│   │   ├── TopBattleStatus
│   │   │   ├── PKBar（双方PK、PlayerShare）
│   │   │   ├── Tier
│   │   │   └── BattleStateFeedback
│   │   ├── BarrageArea
│   │   └── ChargeFeedback
│   ├── OpponentStreamerArea
│   │   ├── OpponentName / OpponentPortraitPlaceholder
│   │   └── EnemyLiveDataArea（静态占位）
│   └── AimReticle
├── AttackChargeInput
├── FailureOverlay
├── PauseMenu
└── OpponentPKBar（运行时）
```

## 最终设计尺寸

| 区域 | 相对位置 | 尺寸 |
| --- | --- | --- |
| BattleHud | Sandbox `(0,0)` | `1920×1080` |
| PlayerStreamerArea | BattleHud `(0,0)` | `448×1080` |
| BattleArea | BattleHud `(448,0)` | `1024×1080` |
| OpponentStreamerArea | BattleHud `(1472,0)` | `448×1080` |
| TopBattleStatus | BattleArea `(0,0)` | `1024×72` |
| BarrageArea | BattleArea `(0,72)` | `1024×896` |
| ChargeFeedback | BattleArea `(0,968)` | `1024×112` |
| 我方 / 敌方直播数据 | 各主播区 `(0,784)` | `448×296` |

顶部第一行显示玩家PK、中央Tier和对手PK；第二行 PlayerShare 横贯中央区，Rect为 `(24,26,976,18)`，两边各留24；第三行战斗状态为 `(24,46,976,26)`。状态保持在顶部72内，弹幕主体从72开始，到968结束。底部显示蓄力、攻击阶段与操作提示。

两侧上部保存主播名和392×600画面占位；左下复用真实 LiveDataHud，右下四项显示“—”并注明“暂无数据”。敌方区域没有脚本、运行数据或增长规则。

## 布局事实与接口

采用任务卡方案A：所有实际设计位置和尺寸保存进 Scene，运行时沿用这些 Rect，仅缩放整个 BattleHud。StageLayoutProfile保留设计规格；修改设计时同步保存Scene，资源不再隐式重排组件。

BarrageArea只读取自己的尺寸控制生成和裁剪。被移除的布局资源字段只有组件、默认Scene及一个fixture使用，fixture已适配；普通战斗公开方法与信号保持。AimReticle继续继承同一整体缩放，FailureOverlay和PauseMenu保留上层顺序。

## 实际验证

- Godot：`4.7.2.stable.steam.ed1daf0bf`；通过本地9082的Godot-MCP-Native连接本任务工作树，查看修改前/后实际Scene Tree和Inspector。
- 编辑器重新打开后，BarrageArea直接为 `(0,72,1024,896)`；顶部、底部及左右数据区域的Inspector位置/尺寸与上表一致。冷启动编辑器确认新LiveDataHud标题和卡片排版已加载，并检查完整三栏截图。
- 真正GUI窗口运行最小临时smoke，检查物理窗口与截图尺寸、同一Scene主体Rect、最终屏幕缩放及准心尺寸：`1920×1080`整体屏幕比例1.0、准心约32px；`1152×648`整体屏幕比例0.6、准心约19.2px。两种尺寸均截图并人工查看，进程退出0、stderr为空。
- Godot逻辑视口与物理窗口可不同。以上比例包含HUD与Viewport最终变换；仅按窗口像素除设计尺寸比较HUD自身scale的临时检查曾误报，修正检查后通过。隐藏窗口截图显式强制绘制，避免等待未触发的frame_post_draw；生产代码未因此修改。
- 编辑器与运行时均沿用 `(0,72,1024,896)` 主体Rect，连续的72/896/112中央分区完整。普通弹幕生成、移动和区域裁剪继续正常；真实生成Comment刷新，我方指标与敌方静态占位分离。
- 复用INT-01真实场景回归：**84/84通过**，退出0、stderr为空，包含攻击、PK/Tier、回拉、复读、直播、倾向、暂停、失败重开和满值提示。
- 复用INT-01攻击边界runner：PASS，退出0、stderr为空；BarrageArea与SandboxBattleHud单文件解析通过。
- Native Debugger仅有引擎启动信息，无新增本卡运行错误。FailureOverlay与PauseMenu层级保持，暂停和失败重开通过既有真实场景回归。
- `git diff --check`通过；临时smoke脚本与场景已清理，截图与Inspector记录留在忽略的 `.godot/` 中，编辑器自动生成的项目配置/资源导入改动不入本任务提交。

验证截图：`.godot/int02-after-editor.png`、`.godot/int02-runtime-1920.png`、`.godot/int02-runtime-1152.png`。修改前Inspector与截图分别保存为 `.godot/int02-before-editor.json/.png`，运行时基线为 `.godot/int02-before-runtime.json`。

## 交接与剩余项

直接打开 `scenes/sandbox/sandbox.tscn` 查看1920×1080设计结构；编辑区域位置/尺寸时保存该Scene。运行时HUD负责整体缩放和数据映射，BarrageArea不再调整自己的舞台位置。后续接入敌方直播数据时从右下EnemyLiveDataArea开始，使用新的真实数据源；Tier继续留在中央顶部。

等待美术替换主播画面、基础色块、进度条与指标卡片；敌方Viewer/Like/Comment/Fan的数据来源和规则仍未实现。本卡未启动CB及后续玩法开发，INT-01记录的CB切场景前倾向提交边界继续有效。

已更新系统3、系统9与Shared布局职责。`known_traps.md`新增KT-32，记录嵌套PackedScene缓存导致编辑器预览仍显示旧子场景的复现条件与重载方法。INT-01日志作为上一任务历史保留，当前布局以本日志和Scene为准。

## PK 条宽度补做

按用户图1参考恢复全宽 PK 条，保留原绿粉圆角和18设计像素高度；战斗提示独占下行。顶部仍为72，弹幕主体及底部区域保持原Rect。

本次只修改Scene排版与本日志。实际字体最小高度为26，首行和状态均使用18字号、26高，确保三行内容在72内无重叠。1152×648真实GUI验证通过：条为976×18设计像素，首行结束于26、条结束于44、状态结束于72；进程退出0，运行stderr为空。截图保存在 `.godot/int02-pk-full-width.png`；临时预览脚本已清理，未增加测试或修改业务逻辑。
