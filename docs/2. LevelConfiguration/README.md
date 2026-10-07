# 2. LevelConfiguration 关卡配置系统任务拆分

## 系统目标

关卡配置系统负责回答三类问题：

1. **这一场是谁、有什么内容**：主播形象、主题、粉丝牌、词库、倾向比例、特殊玩法、真假矛盾。
2. **这一场基础怎么生成**：给弹幕生成系统提供基础数量、频率、速度和同屏上限；具体数值继续来自策划数值配置。
3. **这一场之后去哪**：当前关重开、当前关完成、下一关、全部普通关结束后的终局入口。

它是“关卡资料和关卡顺序”的来源，不负责真正生成弹幕、结算 PK、判定矛盾或播放终局。

## 当前仓库状态

- `LevelProfile`、`LevelCatalog`、`LevelRunState` 已实现，`data/level_configuration/` 提供可编辑的示例关卡。
- INT-01 Sandbox 持有当前 `LevelRunState`，普通战斗失败后原地重开同一关，关卡序号保持不变。
- 【吞并系统】【对手 PK 条系统】【休息时刻系统】【神降临系统】尚未实现时，与它们有关的任务卡只保留为后续联调任务，不提前制造临时跨系统接口。
- 身份系统任务卡已经拆分，但本系统不依赖身份系统才能先做静态关卡数据和关卡顺序。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| LC-01 | 定义关卡基础资料 | 无 |
| LC-02 | 定义本关词库与倾向比例 | 无 |
| LC-03 | 定义本关特殊玩法与真假矛盾内容 | 无 |
| LC-04 | 定义本关基础生成参数 | 无 |
| LC-05 | 当前普通关卡选择与读取 | 2 个关键单元测试 |
| LC-06 | 同一关只完成一次并推进 | 3 个关键单元测试 |
| LC-07 | 接入吞并后的继承内容 | 无新增自动化测试 |
| LC-08 | 接通当前关重开 | 无新增自动化测试 |
| LC-09 | 接通休息时刻后的下一关 / 终局入口 | 无新增自动化测试 |

## 测试预算

本系统只给“关卡推进状态”写单元测试，因为这里一旦出错会直接造成跳关、重复结算或进不了终局。

只测试：

- 默认读取第一关；
- 切换当前关后读取正确关卡；
- 一关第一次完成会推进；
- 同一关重复提交不会再次推进；
- 最后一关完成后会得到“普通关卡全部结束”的状态。

下面这些不逐项写单元测试：

- Resource 每个字段；
- 词库内容；
- 倾向比例具体数值；
- 美术资源引用；
- 真假矛盾文本；
- 生成参数字段；
- 与吞并、重开、休息、神降临的场景联调。

这些内容继续按任务卡做最小 Resource 加载、Godot 解析和实际流程验证。

## 依赖顺序

LC-01～LC-06 可以在其他战斗系统尚未完成时独立开发。

LC-07 等【14. 吞并系统】有真实输出后再做。

LC-08 等【7. 对手 PK 条系统】以及本场需要重置的战斗系统有真实重开流程后再做。

LC-09 等【18. 休息时刻系统】和【19. 神降临系统】存在真实入口后再做。

这样可以避免现在为了“以后要接”先造一批最后会被推翻的接口。

## 已实现的数据类型

LC-01 使用 `data/level_configuration/level_profile.gd` 定义 `LevelProfile` Resource，并提供 `data/level_configuration/level_001.tres` 作为可编辑示例。

基础资料包含稳定关卡 ID、关卡顺序、主播稳定 ID、主播显示名、主播立绘、头像、直播背景、直播主题、粉丝牌稳定 ID 和粉丝牌纹理。主播立绘、头像、直播背景分别由 `streamer_portrait`、`streamer_avatar`、`streamer_live_background` 引用；均为 `Texture2D`。对应主播素材未交付时可以暂留空值，资源到位后直接替换。粉丝牌也可先用稳定 ID 标识。

LevelProfile 保存静态关卡资料、普通话语池、倾向比例、特殊玩法标识、真假矛盾、前文线索和基础生成参数；当前周目进度由 LevelRunState 单独保存。

### LC-02 词库与倾向比例

`LevelProfile` 增加 `normal_speech_pool` 和三项比例字段；词库条目使用 `LevelSpeech` Resource，保存稳定 `original_sentence_id`、话语文本、可编辑的 `tendency_id` 字符串和 `appearance_weight` 相对权重。

三项比例字段为 `orthodox_ratio`、`heretical_ratio`、`absurd_ratio`，类型均为浮点数。本数据类型只保存比例，不负责抽取、归一化或玩家倾向累计；具体内容与比例由策划填写。

倾向稳定 ID 沿用身份选项系统 ID-01 的字符串值：`orthodox`、`heretical`、`absurd`。`LevelSpeech.tendency_id` 保持字符串字段，不在关卡配置系统另建枚举。

### LC-03 特殊玩法与矛盾内容

`LevelProfile.special_trait_ids` 保存本关使用的特性稳定 ID 字符串，具体 ID 由弹幕特性系统定义。当前仓库还没有 BT-01 数据定义，所以示例列表留空，本系统不预设一份特性枚举。

真、假矛盾分别保存在 `true_contradictions` 与 `false_contradictions` 中；每项为 `LevelContradiction` Resource，含稳定 `original_sentence_id` 与文本。`contradiction_context_clues` 保存本关前文线索文本。矛盾真假判定和命中流程仍由矛盾击破系统负责。

### LC-04 基础生成参数

`LevelProfile` 提供 `base_batch_count`、`base_spawn_interval_seconds`、`base_move_speed_pixels_per_second` 与 `normal_barrage_screen_cap`。间隔字段单位为秒；普通话语与普通战斗陷阱共用同屏上限，复读上限由弹幕生成系统单独处理。

`LevelSpeech.appearance_weight` 保存同一倾向话语间的相对出现权重，`1.0` 表示默认等权值。三项比例用于倾向类别选择，两者分别配置。

示例值 `3` 条 / 批、`1.0` 秒间隔、`100` 像素 / 秒、同屏 `24` 条与权重 `1.0` 都是临时试玩默认值，等待策划实测调整。本类型不执行生成，也不包含 Tier 倍率和弹幕寿命。

### LC-05 当前普通关卡选择

`LevelCatalog.profiles` 保存普通关卡集合；每个 `LevelProfile.level_order` 使用唯一递增序号表示流程位置。`LevelRunState` 新建时选择序号最小的关卡，通过 `set_current_level_order()` 切换，并由 `get_current_level_profile()` 返回当前配置。

示例目录 `data/level_configuration/level_catalog.tres` 列出 `level_001.tres` 与 `level_002.tres`。本阶段只读取当前关卡，不推进、不结算，也不接入 UI。

### LC-06 同一关只完成一次并推进

`LevelRunState.complete_level(level_id)` 只接受当前关的首次完成：存在更大的 `level_order` 时返回 `ADVANCED` 并推进；重复提交返回 `ALREADY_COMPLETED`；最后一关返回 `ALL_NORMAL_LEVELS_COMPLETED`，`is_all_normal_levels_completed()` 同时报告结束状态。空白或未知 ID 返回 `INVALID_LEVEL`，已知但非当前关返回 `LEVEL_NOT_CURRENT`。

完成记录保存在单个 `LevelRunState` 实例中，以当前周目状态实例 + `level_id` 识别本次提交。去重状态不写入 SaveData；本类不调用休息时刻、终局或奖励系统。
