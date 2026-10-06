# INT-01 普通战斗可玩 Sandbox 集成

## 开始前先阅读以下文档

- `AGENTS.md`
- `known_traps.md`
- `project.godot`
- `docs/System_Collaboration.md`
- `docs/Original/程序需求汇总.md`
- `docs/2. LevelConfiguration/README.md`
- `docs/3. BarrageGeneration/README.md`
- `docs/4. BarrageTraits/README.md`
- `docs/5. CombatAttack/README.md`
- `docs/6. HitResolution/README.md`
- `docs/7. OpponentPKBar/README.md`
- `docs/8. CombatStage/README.md`
- `docs/9. LiveDataPresentation/README.md`
- `docs/10. Repeat/README.md`
- `docs/17. ThreeTendencies/README.md`
- 上述系统最近一份任务日志

本任务属于跨系统 Integration（集成）任务。

目标是把已经分别完成的系统组合成第一个可以实际操作、可以人工验收的普通直播 PK 战斗场景。

---

## 已经实现的功能

### 2. LevelConfiguration

已有：

- 当前关卡配置；
- 当前主播资料；
- 普通话语池；
- 三倾向比例；
- 真 / 假矛盾数据；
- 基础弹幕生成参数；
- `LevelRunState`。

### 3. BarrageGeneration

已有：

- 普通弹幕持续生成；
- `BarrageView`；
- `BarrageRuntimeRecord`；
- 生命周期；
- 移动；
- 普通弹幕容量；
- 复读弹幕生成入口；
- Tier 数量 / 频率 / 移动速度 / 生命周期倍率入口。

### 4. BarrageTraits

已有：

- 每条弹幕独立 `BarrageTraitSet`；
- 可选判定；
- 遮挡；
- 反弹；
- 目标最终 Trait Result。

当前普通样例弹幕使用空 TraitSet 也可以完成本次普通战斗集成。

特性具体如何根据 `LevelProfile.special_trait_ids` 分配到弹幕实例留给后续特性配置任务。

### 5. CombatAttack

已有：

- 鼠标准心；
- 准心与弹幕相交；
- 蓄力；
- 未蓄满取消；
- 满蓄释放目标快照；
- 飞行；
- 到达复核；
- 硬直；
- 暂停冻结；
- BarrageTraits 接入；
- HitResolution 提交。

当前 Sandbox 已挂载：

- `AimReticle`
- `AttackChargeInput`

当前 Sandbox 还需要补上运行时 `AttackTimingConfig` 注入，完成后即可在正式 Sandbox 中实际操作。

### 6. HitResolution

已有：

- 当前玩家 PK 唯一状态；
- PK 范围限制；
- 普通话语收益；
- 整发收益汇总；
- 反弹 / 遮挡 / MISS 异常选择；
- 普通命中历史；
- `final_player_pk_updated`。

### 7. OpponentPKBar

已有：

- 持续回拉；
- Tier 回拉倍率；
- PK 到 0 后失败；
- `attempt_failed`；
- 连败状态。

当前 Sandbox 需要创建并启动该对象。

### 8. CombatStage

已有：

- Tier 0～5；
- 升档 / 降档；
- 跨档处理；
- `HitResolution` 绑定；
- `BarrageArea` 倍率输出；
- OpponentPKBar 倍率输出；
- 当前 Tier 复读数量；
- Tier 状态事件；
- `tier_up` 音效事件。

当前 Sandbox 已绑定 `HitResolution`，本卡继续接通其余现有输出。

### 9. LiveDataPresentation

已有：

- `LiveSessionData`；
- Viewer / Like / Comment / Fan 四项数据；
- `LiveDataHud`；
- 成功生成评论计数入口。

当前 HUD 已存在于 Sandbox，本卡接通当前已经有明确规则的战斗事件。

### 10. Repeat

已有：

- `RepeatPlan`；
- 普通复读计划；
- 0.5～3 秒延迟队列；
- 队列容量；
- 到期后请求 `BarrageGeneration`；
- 实际生成统计；
- 普通 / 矛盾统计分离；
- 清理普通复读等待队列。

### 17. ThreeTendencies

已有：

- 本场正统 / 异端 / 荒谬暂存；
- 普通话语倾向累计入口；
- 失败回滚；
- 主导 / 次要 / 并列 / 全零判断。

---

## 本次任务

把当前 `scenes/sandbox/` 从技术组件展示页改造成第一个真正可以操作的普通直播 PK 战斗场景。

本卡只整合已经存在的普通战斗能力。

目标链路：

```text
进入 Sandbox
↓
当前关卡初始化
↓
普通弹幕生成
↓
鼠标移动准心
↓
按住左键蓄力
↓
松开发射
↓
记录目标
↓
飞行
↓
到达复核
↓
BarrageTraits
↓
HitResolution
↓
玩家 PK 改变
↓
CombatStage 更新 Tier
├─→ BarrageGeneration 改变后续弹幕
├─→ OpponentPKBar 改变回拉速度
├─→ Repeat 使用当前 Tier
└─→ LiveData / Audio 获得表现事件

普通有效命中
├─→ Repeat
├─→ ThreeTendencies
└─→ LiveData

时间经过
↓
OpponentPKBar 回拉
↓
HitResolution
↓
PK 降低
↓
CombatStage 重新判断 Tier
```

---

## 一、重做 Sandbox 主界面结构

当前中央存在旧技术测试结构：

```text
CenterContainer
└── PanelContainer
    ├── SANDBOX
    ├── 普通弹幕持续生成原型
    ├── Reload
    └── MainMenu
```

本任务把这套技术测试面板移出中央战斗区域。

Sandbox 按现有 `StageLayoutProfile` 组织为直播 PK 主界面。

当前设计基准：

```text
1920 × 1080

左主播区：448 × 1080
中央战斗区：1024 × 1080
右主播区：448 × 1080

PK Bar 区域：1024 × 72
LiveData 区域：448 × 520（INT-02 当前 Sandbox 布局；早期 448×296 值保留在 docs/Original/ 供历史追溯）
```

目标结构参考：

```text
Sandbox
├── Background
│
├── PlayerStreamerArea
│   ├── PlayerPortraitPlaceholder
│   ├── PlayerName
│   └── LiveDataHud
│
├── BattleArea
│   ├── PKBar
│   ├── BarrageArea
│   ├── ChargeFeedback
│   └── BattleStateFeedback
│
├── OpponentStreamerArea
│   ├── OpponentPortraitPlaceholder
│   ├── OpponentName
│   └── TierFeedback
│
├── AimReticle
│
├── FailureOverlay
│
└── PauseMenu
```

正式美术资源尚未提供的区域使用中性占位块、Label、ProgressBar 等基础 Control 表达。

布局尺寸读取现有 `StageLayoutProfile`。

中央弹幕区域始终完整可见并可操作。

原 Reload / MainMenu 开发入口放入 PauseMenu 或屏幕边角的小型 Debug 区域，保持战斗主视野清晰。

---

## 二、让 CombatAttack 在正式 Sandbox 中可操作

当前 `AttackChargeInput` 已完成逻辑，Sandbox 需要补上 `AttackTimingConfig`。

优先读取仓库已经存在的正式数值配置。

当前仓库还没有正式攻击时长表时，建立独立 Sandbox / Prototype 运行配置 Resource。

现有 smoke test 已经验证过：

```text
charge_time_s = 0.20
projectile_flight_s = 0.10
recovery_time_s = 0.15
```

这组值可以作为本次集成验收的临时运行值。

测试目录中的 fixture 继续承担测试输入。

Sandbox 使用独立运行 Resource。

完成：

```gdscript
AttackChargeInput.configure_attack_timing(...)
```

实际运行流程：

```text
按住左键
→ 蓄力

未满松开
→ 取消

蓄满松开
→ 发射
→ 飞行
→ 结算
→ 硬直
→ 再次可攻击
```

---

## 三、加入最小蓄力反馈

在中央战斗区域加入最小 `ChargeFeedback`。

至少表现：

```text
0%
↓
蓄力增加
↓
100%
↓
可释放
```

读取：

```gdscript
AttackChargeInput.get_charge_progress()
AttackChargeInput.get_attack_phase()
```

UI 只显示状态，CombatAttack 继续拥有蓄力和攻击阶段。

当前阶段目标是功能性反馈。

正式动画、Shader、音效强化和最终视觉留给后续表现任务。

---

## 四、完整绑定 CombatStage

Sandbox 创建并持有当前战斗的：

```text
HitResolution
CombatStage
```

完成：

```gdscript
CombatStage.bind_hit_resolution(hit_resolution)
CombatStage.bind_barrage_area(barrage_area)
CombatStage.bind_audio_manager(AudioManager)
CombatStage.begin_combat()
```

验证：

```text
HitResolution PK 改变
→ CombatStage 更新 Tier
→ BarrageArea 收到新的：

generation_count_multiplier
generation_frequency_multiplier
movement_speed_multiplier
lifetime_multiplier
```

Tier 变化实际影响之后生成的新弹幕。

已有弹幕继续沿用生成时确定的参数。

---

## 五、接入 OpponentPKBar

在普通战斗 Sandbox 中创建真实 `OpponentPKBar` Node。

完成：

```gdscript
CombatStage.bind_opponent_pk_bar(opponent_pk_bar)
OpponentPKBar.start_pullback(hit_resolution, base_pullback_speed)
```

基础回拉速度优先读取现有数值配置。

当前仓库还没有正式基础回拉值时：

- 使用一个集中、可编辑的 Prototype / Sandbox 配置字段；
- 数值承担本次可玩验收；
- 在任务 log 标记该值等待策划试玩调参；
- 运行代码从配置读取该值。

验证：

```text
时间经过
→ PK 持续下降
→ HitResolution 更新最终 PK
→ CombatStage 重新计算 Tier
```

暂停时回拉停止，恢复后继续。

---

## 六、做出可见 PK Bar

中央区域加入最小 PK Bar。

数据来源：

```gdscript
HitResolution.get_player_pk()
HitResolution.final_player_pk_updated
```

显示逻辑：

```text
玩家占比 = player_pk
对手占比 = 1.0 - player_pk
```

至少显示：

- 当前玩家 PK；
- 当前对手占比；
- 当前 Tier。

PK Bar UI 只负责显示。

实际 PK 修改继续全部经过 `HitResolution`。

---

## 七、普通有效命中后结束对应弹幕

现有命中流程已经能够得到逐目标最终结果。

实际有效命中后：

```text
正常命中
→ 对应 BarrageView 从场上结束
```

反弹等规则要求结束的目标同样由真实结算结果决定。

遮挡后实际未命中的目标继续存在。

弹幕实例生命周期继续由 BarrageGeneration 管理。

如果 BarrageGeneration 当前缺少用于结束指定弹幕的公开入口，本卡增加一个最小公开方法，由场景组合方 / 结算事件调用。

---

## 八、接入普通复读完整链路

创建当前战斗使用的 `RepeatDelayQueue`。

普通有效话语命中完成后：

```text
HitResolution 完成这一发
↓
CombatStage 已得到结算后 Tier
↓
读取：
current_tier
repeat_count_per_hit
↓
创建 RepeatPlan
↓
RepeatDelayQueue.enqueue_plan()
↓
每帧 advance_and_dispatch()
↓
BarrageGeneration.spawn_repeat_barrage()
↓
复读实际出现在屏幕
```

RepeatPlan 使用：

- 原句 ID；
- 原句文本；
- 结算后 Tier；
- 当前 Tier 的 `repeat_count_per_hit`；
- 当前复读寿命配置。

本卡组合已有 Repeat 规则。

复读实际生成成功后更新 `RepeatGenerationStats`。

复读弹幕进入屏幕后可以被 CombatAttack 选中。

复读命中使用已有：

```gdscript
HitResolution.calculate_repeat_hit_result()
```

结果：

```text
有效命中
PK + 0
倾向 + 0
```

---

## 九、接入 ThreeTendencies

普通话语有效命中后，使用 HitResolution 已经计算出的：

```text
tendency_id
tendency_delta
```

调用：

```gdscript
SaveManager.data.tendency_state.record_normal_speech_tendency(...)
```

本次普通战斗中只修改：

```text
attempt_orthodox_total
attempt_heretical_total
attempt_absurd_total
```

当前 UI 保持倾向精确值隐藏。

本卡通过调试日志或 Inspector 验证数值真实变化。

---

## 十、接入 LiveData 已有能力

保留现有 `LiveDataHud`。

至少接通当前已经有明确实现规则的事件。

普通弹幕 / 复读成功生成：

```text
→ LiveSessionData.record_generated_comments(actual_generated_count)
```

HUD 应立即刷新：

```text
Comment
```

已经有明确公开接口的战斗表现事件继续接入。

当前仍缺策划具体数值规则的 Viewer / Like 变化保持现有数据入口和 UI，等待后续规则配置。

---

## 十一、普通战斗失败入口

`OpponentPKBar.attempt_failed` 发生后：

```text
停止当前普通战斗输入
停止回拉
停止普通生成
清理等待中的普通复读
回滚本场未提交倾向
显示 FailureOverlay
```

FailureOverlay 至少提供：

```text
重新开始当前关
```

重新开始后恢复：

```text
PK 初始值
Tier 0
普通弹幕生成
OpponentPKBar 回拉
CombatAttack READY
Repeat 等待队列为空
本场未提交倾向为 0
LiveData 本场状态重新初始化
```

已有跨周目数据继续由 SaveData 保留。

---

## 十二、PK 满值边界

本任务负责普通战斗。

当玩家 PK 达到最大值：

```text
普通战斗停止继续回拉
普通战斗停止继续生成新的普通内容
```

当前 main 已经存在 ContradictionBreak 的真实公开入口时，调用该入口。

当前 main 还没有 ContradictionBreak 真实公开入口时，显示最小状态提示：

```text
普通战斗完成
等待进入矛盾击破
```

并保持当前满值状态。

本卡把该位置作为 ContradictionBreak 的接入点。

---

## 十三、场景组合原则

`Sandbox` 负责：

- 创建当前战斗生命周期对象；
- 注入系统依赖；
- 连接公开 Signal；
- 驱动跨系统流程；
- 页面 UI 状态切换。

各系统继续保存自己的业务状态：

```text
HitResolution
→ PK

CombatStage
→ Tier

OpponentPKBar
→ 回拉与失败

BarrageGeneration
→ 场上弹幕

CombatAttack
→ 当前攻击

Repeat
→ 复读计划 / 等待 / 统计

ThreeTendencies
→ 倾向

LiveData
→ 直播表现数据
```

当某个跨系统事实当前缺少公开入口时，在事实拥有者上补充最小公开 Signal / 方法。

Sandbox 只负责协调，业务规则继续留在对应系统。

---

## Godot 开发环境

Godot 版本：4.7.2

脚本语言：GDScript

目标平台：

- PC
- Android 后续适配

Godot 工程操作 MCP：

- Godot-MCP-Native

Godot 官方文档 MCP：

- godot_mcp

---

## 执行要求

### 1. 先检查真实工程

开始前确认：

- 最新 `main`；
- 当前工作区状态；
- `sandbox.tscn` 最新节点树；
- 当前各系统公开接口；
- 最近 B / C / D 集成任务日志；
- 当前 Godot Output / Debugger 状态。

涉及 Scene Tree 修改时优先使用 Godot-MCP-Native 检查实际结果。

### 2. 本卡只做普通战斗集成

当前任务范围：

```text
LevelConfiguration
BarrageGeneration
BarrageTraits
CombatAttack
HitResolution
OpponentPKBar
CombatStage
LiveDataPresentation
Repeat
ThreeTendencies
```

ContradictionBreak 作为下一阶段入口。

FinalOracle、Assimilation、Scripture、LoserCard、Rest、DivineDescent、Ending 保持当前实现状态。

### 3. 使用现有接口

优先组合当前公开：

```text
signal
method
Resource
Node
Scene
```

缺少跨系统事实出口时，在真正的数据拥有者上补一个最小公开接口。

### 4. 保持现有系统数据归属

本次场景集成完成以后，各系统继续拥有自己的状态。

`Sandbox.gd` 只承担当前战斗的生命周期和协调。

### 5. UI 使用功能性占位表现

本次 UI 目标：

```text
结构正确
无遮挡
数据可读
操作有反馈
可以验收
```

正式人物立绘、动画、Shader、字体表现、直播视觉包装由后续美术整合替换。

### 6. 中文注释

新增函数和关键跨系统接线使用简明中文注释。

重点说明：

```text
为什么连接这个 Signal
这个数据由谁拥有
发送后由谁处理
```

---

## 验证

本卡以真实运行验收为主。

完成后使用 Godot 4.7.2 实际运行完整 Sandbox。

至少验证：

1. 进入 Sandbox 后中央区域没有旧大 Panel 遮挡。
2. 左 / 中 / 右直播 PK 主界面区域正确存在。
3. 普通弹幕持续生成并移动。
4. 准心跟随鼠标。
5. 左键可以真实蓄力。
6. 未蓄满松开会取消。
7. 满蓄松开会产生一发攻击。
8. 准心罩住真实弹幕时能够命中。
9. 命中的普通弹幕按结算结果结束。
10. PK Bar 发生可见变化。
11. PK 变化能够引起 Tier 变化。
12. Tier 变化后后续弹幕生成数量 / 频率 / 速度 / 寿命实际变化。
13. 对手回拉使 PK 随时间下降。
14. 回拉导致 PK 跨档时 Tier 可以下降。
15. 普通有效命中产生复读计划。
16. 0.5～3 秒后实际出现复读弹幕。
17. 复读弹幕可以被攻击。
18. 复读命中不会增加 PK 和倾向。
19. 普通话语命中会增加本场 ThreeTendencies 暂存。
20. 成功生成普通 / 复读弹幕后 LiveData Comment 实际变化。
21. Pause 时弹幕、蓄力、飞行、硬直和回拉停止推进。
22. 恢复后继续。
23. PK 到 0 后进入失败状态。
24. 当前关可以重新开始。
25. 重新开始后本次未提交战斗状态恢复到入关状态。
26. PK 到满值后普通战斗正确停止，并等待 / 进入 ContradictionBreak。

Godot Output / Debugger 中没有新增与本任务有关的错误。

---

## 本卡验收目标

玩家打开 Sandbox 后，应能够在不查看控制台的情况下理解并完成以下操作：

```text
看见直播 PK 主界面
↓
看见弹幕
↓
移动准心
↓
按住左键蓄力
↓
松开发射
↓
打中弹幕
↓
看到 PK 变化
↓
看到 Tier 和弹幕节奏发生变化
↓
看到复读重新出现
↓
感受到对手持续回拉 PK
↓
继续攻击或被拉回
↓
最终达到 PK 满值或 PK 归零
```

达到这里后，Sandbox 作为“普通战斗可玩验收场”。

---

## 日志

完成后新增：

`docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md`

日志至少记录：

- 实际修改文件；
- 最终 Sandbox Scene Tree；
- 新增的最小跨系统接口；
- 使用的运行时临时配置值；
- 当前普通战斗完整数据流；
- 实际 Godot 运行验证结果；
- 已经可以人工验收的行为；
- ContradictionBreak 接入点；
- 当前仍等待策划调参或美术资源的内容。

---

## 最终汇报

完成后汇报：

1. Sandbox 主界面现在长什么结构；
2. 移动了哪些旧技术测试 UI；
3. 哪些系统已经真实接通；
4. 玩家现在能进行哪些操作；
5. PK / Tier / 回拉 / Repeat / LiveData / Tendency 是否真实联动；
6. 失败与重开是否成立；
7. PK 满值后当前停在哪里；
8. Godot 实际运行验证结果；
9. 下一步只写当前真正需要继续的任务。
