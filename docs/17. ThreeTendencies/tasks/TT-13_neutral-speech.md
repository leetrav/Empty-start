# TT-13 Neutral 普通闲聊接入

## 开始前先阅读
- AGENTS.md
- docs/System_Collaboration.md
- docs/2. LevelConfiguration/README.md
- docs/3. BarrageGeneration/README.md
- docs/6. HitResolution/README.md
- docs/10. Repeat/README.md
- docs/13. FinalOracle/README.md
- docs/17. ThreeTendencies/README.md
- docs/19. DivineDescent/README.md
- 当前相关系统最新 log

## 新需求

策划词库新增普通闲聊类别：

```
tendency_id = "neutral"
```

`neutral` 表示主播日常闲聊、暖场、回应观众、生活碎话等普通直播内容。

它属于普通话语内容，但不属于正统、异端、荒谬三项倾向。

当前策划表中的 neutral 话语统一使用强度 1；程序继续从内容数据读取强度，不额外写死文案数值。

## 本次任务

实现 neutral 普通闲聊从关卡配置到战斗结算、再到后续内容筛选的完整支持。

### 1. 关卡配置

- `LevelSpeech.tendency_id` 支持稳定值 `neutral`。
- `LevelProfile` 增加与现有三项比例同语义的 `neutral_ratio`。
- 现有未配置 neutral 的关卡继续保持原有生成结果；默认 `neutral_ratio` 使用 0。
- 身份系统仍只使用 `orthodox / heretical / absurd` 三种开局倾向；`neutral` 只属于普通话语内容。

### 2. 弹幕生成

- `NormalSpeechSelector` 可以按 `neutral_ratio` 抽到 neutral 类别。
- neutral 条目继续读取自己的 `appearance_weight`。
- 生成后的 `BarrageRuntimeRecord.tendency_id` 保留 `neutral`，供后续结算识别。
- neutral 与其他普通话语共用普通弹幕生成、寿命、容量和移除流程。

### 3. 命中结算

neutral 被正常命中时：

- 仍按普通话语强度计算 PK 收益；
- 当前策划数据为强度 1，因此使用当前强度 1 的普通 PK 收益；
- 本次 `tendency_delta` 为 0；
- 仍然属于有效普通命中；
- 仍然进入现有普通话语命中、直播表现和复读流程。

HitResolution 输出给下游的结果中保留：

```
tendency_id = "neutral"
tendency_delta = 0
```

### 4. 三项倾向

- `TendencyState` 接收到 neutral 普通命中时，正统、异端、荒谬的本场值与累计值都保持不变。
- 玩家本场只命中 neutral 时，三项仍保持全零。
- `has_no_effective_behavior()` 对“三项全零、只有 neutral 行为”的情况继续返回 true。
- 主导倾向、次要倾向、并列裁决和开局身份参照仍只处理正统、异端、荒谬三项。

### 5. 复读与直播表现

- neutral 命中继续按普通话语进入现有普通复读流程。
- neutral 的实际生成、普通命中和复读继续使用现有直播数据表现事件。
- 复读 neutral 时保留原句 ID 与 `neutral` 内容类别。

### 6. 普通命中历史与后续筛选

- HR-14 普通命中历史允许记录 neutral 原句，继续保留原句 ID、命中次数和顺序信息。
- FinalOracle 构建候选时只从 `orthodox / heretical / absurd` 中取正式候选，neutral 不进入终结神谕候选和圣典提交。
- DivineDescent 汇总最终主旨候选与锁定句时只使用三项倾向话语，neutral 不进入终局锁句候选。
- 吞并词库继续按既有 `pool_id` 规则处理；被继承词库中的 neutral 仍可在后续普通战斗生成。

## 数据流

```text
LevelSpeech(neutral)
→ BarrageGeneration 正常生成
→ CombatAttack 正常命中
→ HitResolution：PK 正常收益，tendency_delta = 0
├─→ Repeat：正常复读
├─→ LiveData：正常表现
├─→ HitHistory：记录普通命中
└─→ ThreeTendencies：三项数值不变化

HitHistory
├─→ FinalOracle：过滤 neutral
└─→ DivineDescent：过滤 neutral
```

## 验收条件

- 配置 `neutral_ratio > 0` 后，实际普通战斗可以生成 neutral 台词。
- neutral 台词可以被正常选中、命中、移除，并获得普通 PK 收益。
- 命中 neutral 后正统、异端、荒谬三个本场值都不变化。
- 只命中 neutral 时，三项倾向仍属于全零有效状态。
- neutral 可以触发现有普通复读与直播表现。
- neutral 不会成为 FinalOracle 候选、圣典句或 DivineDescent 最终锁句。
- 现有只配置三项倾向的关卡保持原有行为。

## 测试

只补与本需求直接相关的最小验证：

1. `neutral_ratio` 可让 selector 选择 neutral 条目。
2. neutral 正常命中有 PK 收益且三项倾向增量为 0。
3. FinalOracle 与 DivineDescent 的正式候选筛选不会包含 neutral。

其余生成、命中、复读和表现使用现有 Sandbox 实际流程验收。

## 完成后

- 更新直接受影响系统的 README。
- 按项目规则写本任务 log。
- log 记录实际修改接口、验证结果以及 neutral 在各系统中的最终数据语义。
