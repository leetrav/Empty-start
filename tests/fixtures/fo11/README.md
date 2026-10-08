# TEST_ONLY：FO-11 奖励配置前置

这里全部是显式注入的测试资源。词库继承权重 `1.0` 是占位值，卡面和文案是验收占位，均不代表正式策划交付。生产 `data/loser_card/loser_card_catalog.tres`、关卡目录及关卡实例保持原状。

## 可读取资源

| 文件 | 用途 |
| --- | --- |
| `test_level_catalog.tres` | `LevelCatalog`，首关使用测试 LevelProfile；第二关直接引用工程已有 `level_002.tres`，没有新增第二份内容或奖励 |
| `test_level_001.tres` | `level_001 / streamer_sample`，普通话语和真假矛盾沿用现有样例 ID / 文本；配置 `normal_pool_inheritance` 和独立 `inheritable_trait_ids` 白名单 |
| `test_normal_pool_inheritance.tres` | 稳定 `pool_id=test_only_streamer_sample_normal`、权重 `1.0`、`can_inherit=true`、`is_contradiction_pool=false`；内容对应所属 LevelProfile 的 `normal_speech_pool` |
| `test_loser_card_catalog.tres` | `streamer_sample` 的一张 TEST_ONLY 卡；使用 Godot 原生占位纹理，卡名和文案均带 TEST_ONLY 标记 |

`occlusion` 是现有 `BarrageTraitSet` 支持的真实 ID，单独装配适用于正常话语。是否继承读取 `inheritable_trait_ids`，不能直接复制 `special_trait_ids` 作为奖励白名单。

## A 后续 FO-11 接线

1. 本任务没有修改 Sandbox。当前 `SAMPLE_LEVEL_CATALOG` 是固定常量；A 在 FO-11 集成时需允许注入关卡目录，并让 `LevelRunState` 与 Scripture 绑定读取同一目录。测试注入这里的 `test_level_catalog.tres`；正式默认值继续使用生产目录。
2. 使用 Sandbox 已有 `loser_card_catalog` 属性显式注入 `test_loser_card_catalog.tres`。无需替换生产 Catalogue 的文件或默认引用。
3. 保留现有确认回调对当前周目、Session 关卡、CB BREAKTHROUGH 与当前 LevelProfile 的校验。普通命中历史 / 倾向提交照常进行。
4. 在该回调使用实际 `level_id / streamer_id` 调用 16 / 14 接口；首次真正击败登记成功后，从当前 LevelProfile 读取本任务新增配置。

以下读取方式复用现有接口，放在上述正式校验之后：

```gdscript
var source_level_id := StringName(current_level.level_id)
var source_streamer_id := StringName(current_level.streamer_id)
run_data.loser_card_data.grant_on_true_defeat(
    source_level_id, source_streamer_id, true, true, loser_card_catalog
)
var defeat_added := run_data.assimilation_data.register_defeated_streamer(
    source_level_id, source_streamer_id, true, true
)
if defeat_added:
    var pool := current_level.normal_pool_inheritance
    if pool != null:
        run_data.assimilation_data.register_inherited_word_pool(
            source_level_id, pool.pool_id, pool.appearance_weight,
            pool.can_inherit, pool.is_contradiction_pool
        )
    for trait_id: StringName in current_level.inheritable_trait_ids:
        run_data.assimilation_data.register_inherited_trait(source_level_id, trait_id, true)
```

读取实际结果使用 `get_new_card_for_level()`、`get_acquired_cards()`、`get_new_content_for_source()` 和 `get_current_content_snapshot()`；来源与去重继续由 16 / 14 持有。

## 正式替换

- 正式卡片资料填写在 `data/loser_card/loser_card_catalog.tres`，恢复 / 保留该正式目录注入值。
- 给生产 `data/level_configuration/level_001.tres` 等关卡配置正式 `normal_pool_inheritance` Resource：策划提供正式稳定 pool_id、整池权重和允许继承标记，普通句子继续保存在同关 `normal_speech_pool`。矛盾内容仍独立，矛盾池禁止继承。
- 策划填写生产关卡 `inheritable_trait_ids` 白名单，具体 ID 和后续兼容性由 4 系统处理。未配置的旧关卡默认没有词库 / 特性继承奖励。
- 生产启动场景和目录不得引用 `tests/fixtures/fo11/`。测试资源可保留供回归注入，但正式交付后移除游戏运行中的测试注入，并使用新周目验收，避免对已确认关卡擅自补发。

本任务只准备配置和验证已有发奖入口。完整 Sandbox FO-11 接线、AS-06/07、BT-13 和 FO-12 均留给后续指定任务。
