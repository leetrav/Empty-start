# 5. CombatAttack 战斗攻击系统任务拆分

## 系统目标

战斗攻击系统负责玩家从“移动准心”到“一发攻击完成”的过程。

它负责：
1. 鼠标 / 触摸输入；
2. 准心位置与判定范围；
3. 蓄力；
4. 释放时记录本发目标；
5. 飞行、到达与硬直；
6. 把普通战斗结果交给【6. HitResolution】；
7. 把矛盾阶段结果交给【12. ContradictionBreak】。

它不负责计算 PK，也不负责弹幕自身的生成和寿命。

## 当前实现

- CA-01 提供独立 `AimReticle` 场景并接入当前 sandbox 游戏入口。
- `reticle_diameter` 保留准心尺寸配置入口；`get_aim_center_global_position()` 返回与绘制中心相同的位置，供后续瞄准判定复用。
- CA-02 提供 `BarrageAimIntersection.circle_overlaps_rect()`，边缘接触判为相交；`AimReticle.intersects_target_area()` 复用同一准心尺寸。
- CA-03 提供 `AttackChargeInput` 和纯状态 `AttackChargeProgress`；按住鼠标左键会累积到 `AttackTimingConfig.charge_time_s`，和准心 / 候选目标状态解耦。
- CA-04 未蓄满松开会清空当前进度，不产生攻击结果。
- CA-05 在 Sandbox 中接入真实 `BarrageArea` / `BarrageView`：满蓄释放时检查当前视图、运行时到期时间和区域内可见矩形，再按准心相交结果创建去重快照；释放后的候选变化不会修改本发目标。
- CA-06 在到达时按真实 `BarrageRuntimeRecord` / `BarrageView` 状态过滤已释放目标；目标移动后仍保留资格，到期、离开 BarrageArea、脱离所属区域、排队删除或已释放的目标均失效，不再检查原准心范围。
- CA-07 提供可注入 `AttackTimingConfig` 和普通攻击阶段计时：快照释放后进入飞行，到达时复核并发出结果，再进入硬直；硬直期间不推进蓄力。`tests/fixtures/combat_attack/ca07_short_attack_timing.tres` 只用于计时逻辑验证；正式 Sandbox 仍等共享数值表注入配置。
- CA-11 让 AttackChargeInput 在全局暂停时冻结蓄力处理，并让飞行 / 硬直 Timer 使用可暂停模式；恢复后沿用暂停前的进度。
- CA-08 为每条 `BarrageRuntimeRecord` 装配独立 `BarrageTraitSet`；释放扫描调用 `is_selectable()`，到达复核调用 `get_hit_result()`，并通过 `shot_arrival_resolved` 传递目标 ID、目标节点和原始 `BarrageTraitResult`。
- 当前生成记录的特性集合默认为空；如何把 `LevelProfile.special_trait_ids` 分配到具体弹幕实例尚无已定规则，本卡不猜分配方式。
- CA-09 通过注入的 `HitResolution` 调用正常收益、整发落空 / 异常优先级、单次 `resolve_shot_results()` 和普通命中历史接口；HitResolution 持有唯一 PK。Sandbox 用原始系统案的 0.5 初始 PK 组合 HitResolution，并把最终 PK 信号接给 CombatStage。
- `shot_hit_resolution_submitted` 同发包含目标有效性、`ShotAnomaly`、逐目标 `BarrageTraitResult` / 奖励字典及 HitResolution 返回值。异常惩罚映射等待 HR-03，倾向提交等待 HR-10 / 17，复读请求等待 HR-11 / 10。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| CA-01 | 鼠标准心移动 | 无 |
| CA-02 | 准心与弹幕相交判定 | 2 个关键单元测试 |
| CA-03 | 蓄力进度 | 2 个关键单元测试 |
| CA-04 | 未蓄满松开取消 | 1 个关键单元测试 |
| CA-05 | 释放时记录并去重目标 | 2 个关键单元测试 |
| CA-06 | 飞行结束后复核目标有效性 | 无 |
| CA-07 | 普通攻击硬直节奏 | 无 |
| CA-08 | 接入弹幕特性的可选/遮挡/反弹 | 无新增自动化测试 |
| CA-09 | 普通攻击结果交给命中结算 | 无新增自动化测试 |
| CA-10 | 矛盾攻击交给矛盾击破 | 无新增自动化测试 |
| CA-11 | 暂停时冻结蓄力/飞行/硬直 | 无 |
| CA-12 | Android 触摸输入接入 | 无 |

## 测试预算

只保留 7 个纯逻辑 case：

- 相交时可选；
- 边缘接触也算相交；
- 没有目标仍可蓄力；
- 移动 / 换目标不清空蓄力；
- 未蓄满松开清零；
- 同一实例同发只记录一次；
- 释放后后来进入准心的目标不加入本发。

UI、飞行表现、硬直、暂停、触摸和跨系统传递全部用最小运行联调。

## 依赖顺序

CA-01～09、CA-11 已完成。
CA-10 等 12. ContradictionBreak 和 10. Repeat 有真实接口。
CA-12 放到 Android 输入适配阶段。
