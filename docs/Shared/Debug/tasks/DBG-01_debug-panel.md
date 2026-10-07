# DBG-01 游戏内 DEBUG 面板

## 开始前先阅读

- `AGENTS.md`
- `known_traps.md`
- `project.godot`
- `docs/Shared/README.md`
- `scenes/sandbox/sandbox.gd`
- `scenes/sandbox/sandbox_battle_hud.gd`
- `ui/pause_menu/pause_menu.gd`
- `docs/6. HitResolution/README.md`
- `docs/8. CombatStage/README.md`
- `docs/9. LiveDataPresentation/README.md`
- `docs/17. ThreeTendencies/README.md`

本任务属于 Shared Debug（共用调试）任务，不占用 1～20 玩法系统编号。

## 本次任务

做一个游戏内 DEBUG 面板。

### 打开方式

- 新增 Input Map：`debug_panel`
- 默认按键：`F3`
- 按一次 F3 打开，再按一次关闭
- DEBUG 面板打开时游戏继续运行
- DEBUG 面板显示在普通 HUD 上层

### 文本要求

DEBUG 面板内所有可见信息使用中文。

包括：

- 标题
- 字段名
- 按钮文字
- 状态说明
- 操作提示

枚举值或内部 ID 可以在中文说明后附带原始值，例如：

```text
战斗阶段：普通战斗（NORMAL_COMBAT）
攻击阶段：蓄力中（CHARGING）
```

---

## 面板需要显示的信息

至少显示当前真实运行状态：

```text
当前关卡
当前主播
当前战斗阶段

玩家 PK
当前 Tier
攻击阶段

普通弹幕数量
复读弹幕数量

我方直播数据
- 观看人数
- 点赞数
- 评论数
- 粉丝数

本场倾向
- 正统
- 异端
- 荒谬
```

数据直接读取现有系统真实状态。

DEBUG 面板不保存第二份游戏状态。

---

## 面板需要提供的操作

### 战斗

- 重新开始当前战斗
- 清空当前弹幕
- 立即生成一批普通弹幕
- 停止普通弹幕生成
- 恢复普通弹幕生成

### PK / Tier

提供可直接设置玩家 PK 的调试入口。

至少提供以下快捷值：

```text
0%
55%
56%
63%
64%
70%
71%
78%
79%
89%
90%
99%
100%
```

修改 PK 后继续走现有 HitResolution → CombatStage → HUD 的真实更新链路。

Tier 仍由正式规则计算，不在 DEBUG 面板单独保存一个 Tier 值。

### 直播数据

允许直接修改当前我方：

- 观看人数
- 点赞数
- 评论数
- 粉丝数

修改后使用现有 LiveSessionData 刷新 HUD。

### 倾向

允许直接查看并设置本场：

- 正统
- 异端
- 荒谬

用于后续结算和终局调试。

DEBUG 操作应写入当前已有的 TendencyState 调试入口或为其补充最小调试方法。

---

## Scene 建议

建立独立场景，例如：

```text
ui/debug/debug_panel.tscn

DebugPanel
├── Background
├── ScrollContainer
│   └── Content
│       ├── 状态
│       ├── PK / Tier
│       ├── 弹幕
│       ├── 直播数据
│       └── 倾向
```

使用基础 Godot Control 即可。

本任务不需要美术资源。

---

## 接入要求

- DEBUG 面板通过公开方法读取和操作现有系统
- 不通过修改 Label 文本伪造游戏状态
- 不复制 PK、Tier、LiveData、倾向等业务数据
- 某个系统缺少调试所需的最小公开入口时，在该系统补一个明确的调试方法
- 调试方法使用简明中文注释
- 不重构现有战斗系统

当前暂未实现的 ContradictionBreak、FinalOracle、Rest、DivineDescent、Ending 不在本卡中提前制作假流程。

后续系统完成后，再向同一 DEBUG 面板追加对应调试入口。

---

## 验收

1. 运行游戏后按 F3 可以打开 DEBUG 面板。
2. 再按 F3 可以关闭。
3. DEBUG 面板内所有可见说明为中文。
4. 打开面板时游戏继续运行。
5. 能看到当前关卡、PK、Tier、攻击阶段、弹幕数量、直播数据和三项倾向。
6. 点击 PK 快捷值后，正式 PK / Tier / HUD 联动正常。
7. 能重新开始当前战斗。
8. 能清空、停止、恢复和立即生成普通弹幕。
9. 能修改我方四项直播数据并立即看到 HUD 更新。
10. 能设置并读取本场三项倾向。
11. DEBUG 操作不产生第二份业务状态。
12. PauseMenu、攻击输入和现有 F3 以外输入保持正常。
13. Godot Output / Debugger 没有新增相关错误。

本卡以实际运行验收为主，不新增大规模自动化测试。

## 完成日志

完成后新增：

`docs/Shared/Debug/DBG-01_2026-10-07_log.md`

记录：

- DEBUG 面板 Scene Tree
- F3 Input Map
- 各状态读取来源
- 各调试按钮调用的真实系统接口
- Godot 实际运行验证结果
