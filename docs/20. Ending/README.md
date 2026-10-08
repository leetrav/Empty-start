# 20. Ending 结局系统任务拆分

## 系统目标

结局系统负责把整局已经固定的结果组合成最终页面。

它读取：

- 神降临完成结果；
- 三项倾向的主导、次要、并列和全零状态；
- 圣典完整内容；
- 开局身份；
- 玩家主播名。

然后生成：

- 教派主图；
- 教名；
- 经文展示；
- 身份与最终倾向比较；
- 最终判词。

即使圣典、败者卡或吞并数量为 0，也要能够正常完成结局。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| EN-01 | 接收终局固定结果 | 无 |
| EN-02 | 主导倾向映射教派主图 | 无 |
| EN-03 | 主导 / 次要组合映射九个教名 | 3 个关键单元测试 |
| EN-04 | 读取并排列经文与缺章 | 无新增自动化测试 |
| EN-05 | 身份与最终倾向比较分类 | 4 个关键单元测试 |
| EN-06 | 根据分类选择判词 | 无 |
| EN-07 | 空圣典仍生成结局数据 | 1 个关键单元测试 |
| EN-08 | 组合完整结局页面 | 无 |
| EN-09 | 零收藏成果仍正常完成 | 1 个关键单元测试 |

## 测试预算

只保留 9 个关键纯逻辑 case：

- 一个纯倾向组合能得到对应教名；
- 两个不同混合组合能得到各自不同配置教名；
- 无有效行为 → 无行为类；
- 有最高分并列 → 并列类；
- 其余情况下开局身份对应倾向与最终主导一致 → 一致类；
- 其余情况 → 偏移类；
- 圣典全空仍能生成教名与判词；
- 圣典 / 败者卡 / 吞并都为 0 时仍能完成；
- 教名映射使用配置，不因为页面展示而改动最终倾向结果。

其中最后一条可以和教名映射测试合并，不额外增加测试文件。

页面布局、主图资源、字体、动画和结局演出全部做实际运行验收。

## 依赖顺序

EN-01 等 19. DivineDescent。
EN-02～03 等 17. ThreeTendencies 的冻结结果与结局配置。
EN-04 等 15. Scripture。
EN-05 等 1. Identify 与 17. ThreeTendencies。
EN-06～09 完成页面数据和显示。

## EN-02 当前主图配置接口

- `data/ending/ending_main_art_config.tres` 是三类教派主图的唯一配置入口。
- `EndingMainArtConfig` 提供 `orthodox_main_art`、`heretical_main_art`、`absurd_main_art` 三个 `Texture2D` 字段，以及 `get_main_art_for_tendency(tendency_id)` 查询方法。
- 查询输入沿用 17. ThreeTendencies 的稳定 ID：`orthodox`、`heretical`、`absurd`。未知 ID 返回 `null`。
- 当前仓库尚未提供正式教派主图，配置字段暂为空；后续美术交付只需更新 `.tres`，结局逻辑无需改路径。

## EN-03 当前教名配置接口

- `data/ending/ending_religion_name_config.tres` 是九个教名的策划配置入口。
- `EndingReligionNameConfig` 提供三种纯倾向字段和六种主导 → 次要混合字段；`get_religion_name(primary_tendency_id, secondary_tendency_id)` 按稳定 ID 与顺序读取文本。
- 纯组合键为 `orthodox/orthodox`、`heretical/heretical`、`absurd/absurd`；混合组合覆盖六个有序组合。`has_complete_mapping()` 可检查九个配置槽位是否都有文本。
- 当前九个字段均为空，等待策划填写正式教名；逻辑不猜测或写入教名文本。

## EN-04 当前经文显示数据接口

- `EndingScriptureDisplayData.build_from_scripture(scripture_data, level_catalog)` 直接复用 `ScriptureData.get_chapter_slots(level_catalog)`，保留 Scripture 已决定的章号顺序和缺章位置。
- 每行输出 `level_id`、`chapter_number`、`verse_number`、`streamer_name`、`original_line_id`、`original_line_text`、`tendency_id`、`has_oracle` 和 `status`。
- 正式经文的 `status` 为 `confirmed_oracle`，读取已保存的原文和固定节号；缺章的 `has_oracle` 为 `false`、`verse_number` 为 0、`status` 为 `not_formed_oracle`，供页面显示“未形成神谕”。
- EN-04 只整理显示快照，不复制 Scripture 的排序、节号生成或缺章判定规则。

## EN-05 当前身份结果分类接口

- `EndingIdentityResultClassifier.classify(tendency_state)` 接收已完成身份初始化、包含已提交结果的 `TendencyState`，返回稳定 `StringName` 分类：`no_effective_behavior`（无行为）、`primary_tied`（并列）、`consistent`（一致）、`shifted`（偏移）。
- 优先级固定为无有效行为 → 最高分并列 → 开局倾向与主导一致 → 其余偏移；全零时即使存在并列及身份一致也归为无行为类。
- 无行为、并列和主导分别调用 17 系统的 `has_no_effective_behavior()`、`is_primary_tied()`、`get_primary_tendency_id()`；Ending 不读取或重算精确分数。
- 开局参照读取 `TendencyState.opening_identity_tendency_id`：Identify 确认身份时已经通过 `initialize_from_identity_option()` 从所选 `IdentityOption.tendency_id` 写入该周目值，无需根据身份显示名称或 ID 推测倾向。
- 分类器只读传入数据。当前尚未接入 EN-01 终局接收流程；后续集成应传入终局固定的三项倾向结果，判词配置与页面由对应任务卡实现。

## EN-06 当前判词配置接口

- `data/ending/ending_judgement_text_config.tres` 是四类判词的策划配置入口，使用 `EndingJudgementTextConfig` Resource。
- `get_judgement_text(result_class: StringName)` 直接复用 EN-05 分类常量，返回对应多行文本字段：

| EN-05 分类 ID | 判词配置字段 |
| --- | --- |
| `no_effective_behavior` | `no_effective_behavior_text` |
| `primary_tied` | `primary_tied_text` |
| `consistent` | `consistent_text` |
| `shifted` | `shifted_text` |

- 四个字段当前均为空，等待策划填写正式判词；查询保留配置原文，允许空文本，未知分类返回空字符串。
- 后续调用先取得 EN-05 的 `classify(tendency_state)` 结果，再传给配置的 `get_judgement_text()`；配置运行时只读。EN-06 只提供映射，页面和终局接线由后续任务卡完成。

## EN-07 当前结局显示数据接口

- `EndingDisplayData.build(tendency_state, scripture_data, level_catalog, main_art_config, religion_name_config, judgement_text_config)` 组合 EN-02～06 已有接口，返回显示数据字典；调用方提供已初始化身份的有效三项倾向、圣典、完整关卡目录和三份配置 Resource。
- 输出 `primary_tendency_id`、`secondary_tendency_id`、`main_art`、`religion_name`、`identity_result_class`、`judgement_text` 和 `scripture`。
- `scripture.rows` 直接沿用 EN-04 的章节显示列表；`scripture.is_empty` 通过 Scripture 的 `get_ordered_entries().is_empty()` 得到。全空时区域 `status` 沿用 EN-04 的 `not_formed_oracle`，保留目录中的缺章位置；有正式经文时为 `confirmed_oracle`。
- 空圣典不会阻断主图、教名和判词读取。正式配置尚未填写时，文本保持空字符串、主图保持 `null`，显示数据字段仍完整返回。
- 组装过程只读上游和配置，未接入 EN-01 终局完成事件，未制作 EN-08 页面。仅新增一个关键单元测试，验证全空圣典仍生成配置结果和明确空态。
