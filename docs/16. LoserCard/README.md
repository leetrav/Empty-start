# 16. LoserCard 败者卡系统任务拆分

## 系统目标

败者卡系统负责记录本周目真正击败过哪些主播。

只有“矛盾击破成功 + 终结神谕确认完成”后才发卡。只赢下 PK 不发新卡。

## 当前数据底座

- `LoserCardProfile` Resource 以稳定 `streamer_id` 标识主播，提供 `streamer_name`、`card_art` 和 `card_text` 展示入口。
- `LoserCardCatalog` 保存资料列表，并通过 `find_profile(streamer_id)` 查找卡片。
- 当前目录中的 `data/loser_card/loser_card_catalog.tres` 是空资料库；正式主播 ID、卡面素材和文案尚未提供。
- `LoserCardData` Resource 保存周目获卡主播 ID 和已发卡关卡 ID；`grant_on_true_defeat(level_id, streamer_id, contradiction_broken, oracle_confirmed, catalog)` 同时要求 CB 击破成功和同关 FinalOracle 正式确认，并通过 Catalog 查到对应资料。同场重复不发，资料缺失不合成卡片。
- 同一个 `LoserCardData` 周目 Resource 内，以 `acquired_streamer_ids` 对主播去重：同场重报和同主播跨关重报均返回 false，保留首张卡。
- `pk_win_unbroken` 分支的 `contradiction_broken=false` 不满足发卡入口；PK 胜利不会替代击破或神谕确认，已有卡片及提交记录保持原值。
- `SaveData.loser_card_data` 持有当前周目的获卡 Resource，现有 SaveManager 保存 / 加载整个 SaveData 时自动包含已获主播及已提交关卡。缺少新字段的旧存档默认得到空 Resource，版本仍为 1。
- 后续失败只回滚本次战斗暂存，获卡 Resource 作为已提交周目成果保留；实际奖励接线与休息展示留后续联调。调用方需核对真实结果的当前周目与 level_id。
- 新周目复用 `SaveManager.new_game()` 创建新的 SaveData，默认建立独立空 LoserCardData，旧获卡和已提交关卡 ID 不带入；静态 Catalog 继续保留。
- LCARD-07 提供 `get_acquired_cards(catalog)` 和 `get_new_card_for_level(level_id, catalog)` 两个只读入口，供 Rest 读取当前周目卡片集合和本场发卡结果。

## LCARD-07 Rest 只读接口

- `SaveData.loser_card_data.get_acquired_cards(catalog) -> Array[Dictionary]` 按获得顺序返回全部已获卡片，包括已经提交的本场新卡；空周目返回空数组。
- `SaveData.loser_card_data.get_new_card_for_level(level_id, catalog) -> Dictionary` 只读取该关实际成功发出的卡片，未发卡时返回 `{}`。未击破、资料缺失导致发卡失败、同主播跨关重复发卡均不会产生该关新增结果；重复读取已发卡关卡仍返回同一份事实。
- 每条卡片快照形状为 `{"streamer_id": StringName, "profile": LoserCardProfile 或 null}`。容器和 Profile 都是新副本，读取方修改它们不会改写周目 ID 或静态 Catalog；Texture2D 继续作为展示资产使用。
- Catalog 缺失或不再包含已获主播时保留稳定 ID，`profile = null`。这表示已获卡片的展示资料缺失，和 `{}` 表示本场无新增可以明确区分。
- 来源关联复用现有保存结构：`grant_on_true_defeat()` 每次成功都同时追加 `rewarded_level_ids` 和 `acquired_streamer_ids`，同索引表示同一次获卡。没有增加第二份来源表或存档字段；读档后沿用这份对应关系，旧数据缺少对应项时返回无新增。
- Rest 只需从自己的结果快照取得 `level_id`，将它与 Catalog 传给上述入口。发卡条件、获卡集合、同关来源和无新增判断均由 16 系统持有；Rest 无需拼接两组保存 ID，也无需通过 LevelCatalog 反推获卡来源。

PR #32 的 RS-03 消费方应改为调用 `get_new_card_for_level()`，结果为空时保留既有 `new_loser_card = null` 空态，结果非空时直接使用卡片快照。历史查看调用 `get_acquired_cards()`。本卡只交付 16 系统入口，#32 的 Rest 分支由其负责 Lane 接线。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| LCARD-01 | 卡片资料数据 | 无 |
| LCARD-02 | 真正击败后发卡 | 2 个关键单元测试 |
| LCARD-03 | 同主播本周目只发一次 | 1 个关键单元测试 |
| LCARD-04 | 未击破分支不发卡 | 1 个关键单元测试 |
| LCARD-05 | 本周目保存已获卡片 | 无 |
| LCARD-06 | 新周目清空卡片 | 1 个关键单元测试 |
| LCARD-07 | 提供给休息时刻 | 无新增自动化测试 |

## 测试预算

只保留 5 个纯逻辑 case：

- 真正击败后可以获得对应卡片；
- 非真正击败结果不满足发卡条件；
- 同主播重复发卡只保留一张；
- 未击破 PK 胜利不新增卡片；
- 新周目开始后卡片记录清空。

## 依赖顺序

LCARD-01 可先做。
LCARD-02～04 等 13. FinalOracle / 12. ContradictionBreak 的真实结果。
LCARD-05 接现有 SaveData。
LCARD-06 接新周目流程。
LCARD-07 已提供 Rest 所需的历史卡片、本场新增与无新增只读语义；RS-03 / RS-06 消费方按上文调用。
