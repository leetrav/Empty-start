# 18. Rest 休息时刻系统任务拆分

## 系统目标

休息时刻系统负责一场直播结束后的结算与过渡。

它读取本场结果，展示已经真正提交的成果，并决定：

- 还有下一名主播时，进入下一关；
- 普通关卡全部完成时，进入神降临。

它还提供历史经文、败者卡查看入口，以及当前倾向对应的房间表现。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| RS-01 | 接收并保存本场结果快照 | 无 |
| RS-02 | 未击破分支说明 | 无 |
| RS-03 | 读取本场新增圣典 / 卡片 / 吞并 | 无新增自动化测试 |
| RS-04 | 空奖励状态 | 无 |
| RS-05 | 历史圣典查看入口 | 无新增自动化测试 |
| RS-06 | 历史败者卡查看入口 | 无新增自动化测试 |
| RS-07 | 根据倾向切换房间表现 | 无新增自动化测试 |
| RS-08 | 重复打开只读取已有结果 | 1 个关键单元测试 |
| RS-09 | 进入下一普通关 | 1 个关键单元测试 |
| RS-10 | 普通关结束后进入神降临 | 1 个关键单元测试 |
| RS-11 | 结算结束后切换输入 | 无 |

## 测试预算

只保留 3 个关键纯逻辑 case：

- 同一份结算重复打开不会再次提交奖励；
- 还有普通关时选择下一关；
- 普通关全部结束时选择神降临。

UI、空态、历史查看、环境变化和输入切换全部做实际运行联调。

## 依赖顺序

RS-01～02 等 12. ContradictionBreak / 13. FinalOracle 结果。
RS-03 等 14/15/16。
RS-05～06 等 15/16。
RS-07 等 17. ThreeTendencies。
RS-09 等 2. LevelConfiguration。
RS-10 等 19. DivineDescent。

RS-01 已增加 `RestSession.open_result(result_snapshot)` 作为本场结果入口。快照包含来源 `level_id` 与 `result_kind`（`pk_win_unbroken` 或 `breakthrough_oracle_complete`）；会话只接受首次打开，读取方使用 `get_result_snapshot()` 获得深拷贝。

RS-02 为 `pk_win_unbroken` 增加专属结果面板，显示 PK 胜利但矛盾未击破、没有神谕或击败奖励，并发出继续请求。Sandbox 接收继续请求并处理 RS-09 路由，接受一次后发出 `rest_continue_requested(session)` 通知。

RS-03 增加 `RestSession.read_committed_rewards(save_data, level_catalog, loser_card_catalog)`：经文按当前 `level_id` 读取 `ScriptureData.get_entry_for_level()`；吞并用同一 Session 的 `level_id` 和真实 LevelCatalog 对应的 `streamer_id` 调用 `AssimilationData.get_new_content_for_source()`，返回 `new_assimilation` 快照。未打开、未击破、缺少关卡 / 来源或无新增时该字段为 `{}`。Rest 不保存来源映射或计算总量差值，需要总量的消费方使用 14 的 `get_current_content_snapshot()`。

RS-03 已接入 LCARD-07 正式只读入口 `SaveData.loser_card_data.get_new_card_for_level(level_id, loser_card_catalog)`：来源归 16 判断，本场无新增为 `{}`，Rest 映射为 `new_loser_card = null`；正式发卡但 Catalog 缺失时仍能得到主播 ID 与 `profile = null`。败者卡读取不依赖 LevelCatalog，后者仅用于解析吞并的同关主播来源；所有读取均不发奖或改写已提交结果。

RS-04 在现有 `RestResultView` 增加 `show_result(session, save_data, level_catalog, loser_card_catalog)`。三类本场成果均为空时显示“本场没有新增经文、败者卡或吞并内容”；历史经文和败者卡分别复用 `get_ordered_entries()` / `get_acquired_cards()` 判断空集合，在同一面板显示可读提示。缺少数据时不推断历史为空，已有卡片但 Catalog 缺失也保留其非空事实。继续按钮始终可用，仍发出 `continue_requested`；Sandbox 的未击破入口传入真实周目与目录并保留原信号转发。两类历史查看由 RS-05 / RS-06 接入，下一关路由已由 RS-09 接入。

RS-09 增加 `RestSession.continue_to_next_level(run_state) -> LevelRunState.CompletionResult`：只从本场已冻结结果读取 `level_id`，调用关卡所有者的 `complete_level(level_id)`；存在下一普通关时返回 `ADVANCED`，重复提交沿用 `ALREADY_COMPLETED`，Rest 不另存进度或去重记录。

Sandbox 在 `ADVANCED` 时复用 `restart_current_attempt()`，按新的当前 LevelProfile 重建普通战斗；清理旧弹幕、队列、输入、神谕、矛盾、休息界面及未提交暂存，并通过 `OpponentPKBar.complete_current_level()` 清除旧关连败。继续沿用同一 SaveData，入关粉丝基数读取当前已入账粉丝，经文 / 败者卡 / 吞并等已提交成果保留。`level_catalog` 为可注入的现有关卡目录 Resource，运行状态、经文来源与 Rest 展示统一读取它。

重复点击继续时，重建后的当前 Rest 绑定已清空；重复提交旧结果也由 LevelRunState 拒绝，均不会跳过下一关。最后一普通关返回 `ALL_NORMAL_LEVELS_COMPLETED` 时仅保留休息界面和一次通知，神降临入口仍留 RS-10。FO-12 已将成功确认并提交奖励后的 `breakthrough_oracle_complete` 接到同一 Rest 入口，既有 `read_committed_rewards()` 从真实周目 / 目录只读获取成果，Continue 继续复用 RS-09。正式 `level_002.tres` 目前只有基础信息，词库 / 矛盾内容仍待补齐；TEST_ONLY 切关 smoke 不代表第二关正式可玩。

RS-05 在结果面板增加“查看历史圣典”，沿用 `show_result()` 传入的 `SaveData.scripture_data` 与 `LevelCatalog`。组合子场景 `ui/rest/scripture_history_view.tscn` 的 `show_history(scripture_data, level_catalog)` 只读数据，复用 `EndingScriptureDisplayData.build_from_scripture()` → `ScriptureData.get_chapter_slots()` 和 `EndingScriptureRow` 显示原章号、固定节号、主播、正式原文及“未形成神谕”的缺章；暂存 `pending_entry` 不作为正式经文展示。章节规则仍由 15 持有，Rest 没有新增历史数据层。

历史为空时保留清楚的空提示与缺章行，空目录另行提示；缺少 SaveData / ScriptureData / LevelCatalog 时显示“历史圣典资料暂不可用”并禁用查看入口，避免将未知资料视为空收藏。子面板沿用项目 Theme，长文本自动换行并使用原生 ScrollContainer 纵向滚动，返回按钮固定在滚动区外。返回请求恢复原结果面板与按钮焦点，原继续信号保持可用；重新显示或隐藏结果时同步收起历史面板。Sandbox 已有上下文足够，本卡无需修改其接线。

RS-06 在同一结果面板增加“查看历史败者卡”，与圣典入口并排，沿用 `show_result()` 传入的 `SaveData.loser_card_data` / `LoserCardCatalog`。子场景 `ui/rest/loser_card_history_view.tscn` 的 `show_history(loser_card_data, catalog)` 调用正式 `get_acquired_cards(catalog)`，按其返回顺序组合 `LoserCardHistoryRow`，展示 Profile 中的真实主播名、卡面和完整文案；获得与排序规则继续归 16，Rest 没有新增收藏或奖励登记。

有效获卡数据返回空数组时显示“暂无已获卡片”；目录为 null、空目录或某个档案缺失时保留正式读取接口返回的已获主播 ID，并清楚提示档案暂缺。Profile 存在但卡面 / 文案缺少时也显示对应缺资料提示，不合成素材。缺少 SaveData / LoserCardData 属于上下文不可用，禁用查看入口且保留继续按钮；缺少卡片目录仍允许查看已获记录，和空收藏区分。卡片页沿用项目 Theme，长文换行、原生纵向滚动，固定返回按钮恢复原面板与败者卡入口焦点；圣典查看与原继续信号保留，两个子面板互斥显示。Sandbox 接线继续由 Lane A 持有，本卡无需修改。
