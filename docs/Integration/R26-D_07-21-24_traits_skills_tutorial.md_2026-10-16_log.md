# R26-D · 07/21/24 特性、反击技能与教学日志（2026-10-16）

## 1. 改动与接口

- `systems/barrage_traits/barrage_trait_catalog.gd` 新增正式 CSV 读取：07 的 6 条特性定义、21 中 `enabled=true` 且权重大于 0 的技能。支持按主播 ID 和 Tier 加权抽选，并把 21 的特性 ID 转为 `Array[StringName]`。
- `systems/barrage_generation/barrage_area.gd` 增加 `configure_trait_catalog(catalog)`、`spawn_counter_skill_barrage(level_profile, speech, tier, rng)` 和 `get_trait_definition(trait_id)`。新入口复用 `spawn_normal_barrage()` 的 TraitSet 校验、普通话语来源、遮挡静止行为与特殊容量账本。目录注入后，07 非空 `lifetime_override_s` 覆盖类别寿命。
- `systems/barrage_traits/tutorial_step_runner.gd` 新增配置驱动步骤运行器，读取 24 表并以 trigger/completion 稳定 ID 推进，发出 `hint_requested`、`step_completed`、`tutorial_completed`。
- `ui/tutorial/tutorial_hint_label.gd` 提供可连接提示 Label 的显示与清理方法。
- `tests/unit/barrage_traits/test_formal_trait_skill_and_tutorial_tables.gd` 检查正式行数、两主播不同 Tier 抽选及 aim/charge/fire 顺序。
- `docs/4. BarrageTraits/README.md` 记录后端状态及 INT-16 接线边界。

## 2. 数据字段覆盖与遗留

### 07 特性参数（6 行）

| 字段 | 当前消费者/状态 |
| --- | --- |
| `trait_id` | `BarrageTraitSet` 稳定 ID 校验及目录查询 |
| `display_name`、`inheritable`、`notes` | 当前没有生产 UI 或继承决策消费者 |
| `penalty_param_id` | 结果类型已有映射：遮挡/反弹进入异常结算，假牌/反击复制体跳过普通收益；07 ID 尚未驱动参数查表 |
| `lifetime_override_s` | 目录注入后由 BarrageArea 覆盖实例寿命；目录未接入正式 Sandbox，运行时仍待接线 |
| `split_child_count` | `try_begin_split()` 仅限制一次触发；缺少真实子弹幕生成消费者，未实现数量字段 |
| `visual_asset_id` | 现有特殊表面按特性 ID 绘制；表内资产 ID 未被加载或核验，缺少映射证据 |

六个 ID：`occlusion`、`retaliation_copy`、`fake_card`、`unselectable`、`split`、`reflect`。现有命中选择/结果、遮挡定位和生命周期类型行为继续由原系统拥有。

### 21 反击技能池（32 条启用）

| `streamer_id` | Tier | 技能 ID | 行为状态 |
| --- | --- | --- | --- |
| alien | 2–5 | `alien_t2_occlusion`, `alien_t2_unselectable`, `alien_t3_split`, `alien_t3_occlusion`, `alien_t4_split`, `alien_t4_unselectable`, `alien_t5_occlusion`, `alien_t5_reflect` | 八项均由新抽选入口装配 trait ID；分裂子体逻辑仍缺 |
| kiwi | 2–5 | `kiwi_t2_fake_card`, `kiwi_t2_retaliation_copy`, `kiwi_t3_retaliation_copy`, `kiwi_t3_fake_card`, `kiwi_t4_reflect`, `kiwi_t4_retaliation_copy`, `kiwi_t5_fake_card`, `kiwi_t5_reflect` | 装配既有 TraitSet 行为；复制触发仍需实战 owner 对接 |
| frog | 2–5 | `frog_t2_split`, `frog_t2_occlusion`, `frog_t3_split`, `frog_t3_fake_card`, `frog_t4_occlusion`, `frog_t4_split`, `frog_t5_fake_card`, `frog_t5_retaliation_copy` | 同上 |
| fox | 2–5 | `fox_t2_fake_card`, `fox_t2_reflect`, `fox_t3_reflect`, `fox_t3_unselectable`, `fox_t4_fake_card`, `fox_t4_retaliation_copy`, `fox_t5_reflect`, `fox_t5_fake_card` | 同上 |

`skill_type` 当前 32 行均为 `trait`，`trait_ids` 为单 ID。`skill_id`、主播、Tier、权重与启用字段已被目录用于筛选/抽选。素材效果/强弱仍按 CSV notes 标注为试玩方案，需实机验证；没有增加臆造的表值。

### 24 新手教学（3 行）

`tutorial_001_aim`: `tutorial_target_available` → `tutorial_aim_acquired`；`tutorial_001_charge`: `tutorial_aim_acquired` → `tutorial_charge_full`；`tutorial_001_fire`: `tutorial_charge_full` → `tutorial_normal_hit`。步骤顺序与提示文本由 CSV 读取。

运行器可消费真实事件，但 Sandbox 尚未发布这些事件，周目存档也没有教学步骤字段。生产操作验收因此未完成。

## 3. INT-16 / Sandbox 对接契约

1. Sandbox 在可用时创建并 `load_production_tables()` 一个 `BarrageTraitCatalog`，向 `BarrageArea.configure_trait_catalog(catalog)` 注入。
2. 普通批次触发反击技能时调用 `barrage_area.spawn_counter_skill_barrage(level_profile, selected_speech, combat_stage.get_current_tier())`；若返回 `null`，沿原普通批次重试/回退策略处理。
3. Sandbox 创建 `TutorialStepRunner`，连接 `hint_requested` 至已有提示 UI 的 `show_tutorial_hint(step_id, hint_text)`；`step_completed` 写入当前周目已完成步骤集合。
4. 只在真实事实发生后调用 `notify_event()`：AimReticle 与普通目标重叠时 `tutorial_target_available`；真实 aim acquired、`AttackChargeInput.is_fully_charged()`、`BattleAttemptFlow.shot_resolved` 中至少命中一条普通非复读话语时分别发送表内对应事件。开始步骤时把完成 ID 快照交给 `begin(level_profile.tutorial_config_id, completed_ids)`。

本分支未改 `scenes/sandbox/sandbox.gd`、`core/save/save_data.gd`、`data/level_configuration/level_run_state.gd`、`ui/rest/rest_opening_room.gd`。上述契约供这些文件的 INT-16 owner 接入。

## 4. 验证

- Godot 4.7.2 headless 定向脚本：退出码 0；断言通过，正式表读取 6 个特性和 32 个启用技能，alien T2/kiwi T3 得到预期技能，三步事件顺序完成。
- 正式 `project.godot` 默认 Boot 场景 headless 启动退出码 0；此项只验证应用启动，不覆盖战斗内技能触发或教学输入。
- 全项目 `--import`/定向运行输出既有缺资源错误：`assets/fonts/NotoSansSC-VF.ttf`、`ZCOOLKuaiLe-Regular.ttf` 与若干音频文件缺失；项目主题和 AudioManager 资源无法加载。定向逻辑脚本及默认 Boot 分别退出 0，但缺资源的生产内容和新功能实战仍待验证。
- Sandbox 实际 runtime、UI 截图、Android 输入及两主播 Tier 全流程未验证。Godot MCP 工具未在当前工具列表提供。

## 5. 接手与状态

后续从 INT-16 的 Sandbox / SaveData owner 接入上方接口契约，并在资产恢复后进行正式场景运行。06 参数字段、分裂子体数量、反击复制实际触发、07 视觉资产 ID 映射以及 24 表周目完成记录仍未闭环。无新 Scene/Resource；`known_traps.md` 未更新。
