# TT-14 Neutral 随 Tier 衰减

## 开始前先阅读

- AGENTS.md
- known_traps.md
- docs/System_Collaboration.md
- docs/17. ThreeTendencies/tasks/TT-13_neutral-speech.md
- docs/3. BarrageGeneration/README.md
- docs/8. CombatStage/README.md
- docs/17. ThreeTendencies/README.md
- data/level_configuration/level_profile.gd
- core/combat/combat_stage_tier_config.gd
- core/combat/combat_stage.gd
- systems/barrage_generation/normal_speech_selector.gd
- 当前相关系统最新 log

## 新需求

Neutral 普通闲聊会随着战斗 Tier 提升而逐渐退出直播内容池。

玩家和对手越进入高压、失控状态，普通闲聊出现得越少；Tier 5 时不再生成 neutral。

## 数值

Neutral 使用“关卡基础权重 × 当前 Tier 倍率”得到本次参与普通话语类别抽取的实际权重。

| Tier | Neutral 权重倍率 |
| --- | ---: |
| Tier 0 | 1.00 |
| Tier 1 | 0.99 |
| Tier 2 | 0.70 |
| Tier 3 | 0.40 |
| Tier 4 | 0.15 |
| Tier 5 | 0.00 |

计算：

```text
effective_neutral_weight
= LevelProfile.neutral_ratio
× current_tier.neutral_weight_multiplier
```

正统、异端、荒谬仍读取各自原有 ratio。

例如：

```text
neutral_ratio = 1.0

Tier 0 → 1.00
Tier 1 → 0.99
Tier 2 → 0.70
Tier 3 → 0.40
Tier 4 → 0.15
Tier 5 → 0.00
```

这些值是“参与四类话语抽取时的相对权重”，不是最终生成百分比。最终概率仍由 neutral 与当时另外三类有效权重共同归一化决定。

## 本次任务

### 1. Tier 配置

在现有 CombatStage Tier 配置中增加 Neutral 权重倍率字段。

默认值使用 1.0，正式 `tier_catalog.tres` 按本卡表格填写 Tier 0～5。

该数值跟随 Tier 配置，由 CombatStage 作为当前战斗档位事实提供。

### 2. 生成系统接入

NormalSpeechSelector 在计算 neutral 类别权重时同时读取：

- 当前关 `neutral_ratio`
- 当前 Tier 的 `neutral_weight_multiplier`

Neutral 的实际类别权重使用两者乘积。

Orthodox / Heretical / Absurd 继续使用当前关卡 ratio。

### 3. Tier 切换实时生效

CombatStage Tier 发生变化后，后续新生成批次立即使用新 Tier 的 Neutral 倍率。

已经生成在场上的弹幕保持原样。

Tier 降档后，Neutral 权重恢复到该档对应倍率。

### 4. Tier 5

Tier 5 的 Neutral 权重倍率固定为 0。

当另外三类存在有效内容和权重时，Tier 5 普通生成只从 Orthodox / Heretical / Absurd 中选择。

### 5. TT-13 语义保持

Neutral 继续保持 TT-13 已定义的行为：

- 属于普通话语
- 正常生成、命中、增加 PK
- 正常进入普通命中历史
- 正常触发普通复读和直播表现
- 三项倾向增量为 0
- 不进入 FinalOracle 候选
- 不进入 Scripture
- 不进入 DivineDescent 最终锁句候选

本卡只改变 Neutral 的生成权重随 Tier 的变化。

## 数据流

```text
CombatStage 当前 Tier
→ CombatStageTierConfig.neutral_weight_multiplier
                         │
LevelProfile.neutral_ratio
                         │
                         ↓
            NormalSpeechSelector
                         ↓
        effective_neutral_weight
                         ↓
          普通话语类别抽取
```

## 验收

1. Tier 0 时 Neutral 使用 1.00 倍基础权重。
2. Tier 1 时使用 0.99。
3. Tier 2 时使用 0.70。
4. Tier 3 时使用 0.40。
5. Tier 4 时使用 0.15。
6. Tier 5 时 Neutral 不进入本次普通话语类别抽取。
7. Tier 升降后，下一批新生成话语立即使用当前 Tier 对应倍率。
8. 未配置 Neutral 的旧关卡继续保持原有生成结果。
9. TT-13 的 PK、倾向、复读、历史及后续过滤语义保持不变。
10. Godot 4.7.2 实际运行时无新增相关错误。

## 测试

只补与本需求直接相关的最小验证：

- Tier 配置能返回对应 Neutral 倍率。
- 同一关卡在 Tier 0 与 Tier 5 下，Neutral 分别可参与抽取 / 完全退出抽取。
- Tier 切换后下一次选择使用新的倍率。

其余普通生成与 Tier 联动沿用现有 Sandbox 实际运行验收。

## 完成后

新增：

`docs/17. ThreeTendencies/三项倾向系统_TT-14_2026-10-07_log.md`

记录：

- Neutral 倍率字段所在 Resource
- Tier 0～5 实际配置
- CombatStage → BarrageGeneration 的传递方式
- 实际运行验证结果
