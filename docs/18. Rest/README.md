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

RS-02 为 `pk_win_unbroken` 增加专属结果面板，显示 PK 胜利但矛盾未击破、没有神谕或击败奖励，并发出继续请求。Sandbox 将继续请求转成 `rest_continue_requested(session)` 信号；下一关切换仍由 RS-09 接入。

RS-03 增加 `RestSession.read_committed_rewards(save_data, level_catalog, loser_card_catalog)`：经文按当前 `level_id` 读取 `ScriptureData.get_entry_for_level()`；败者卡按 `rewarded_level_ids` / `acquired_streamer_ids` 确认后从静态 Catalog 读取。该接口只读，不执行任何奖励写入。吞并部分等待 14 提供按关卡归属的词库 / 特性结果；`AssimilationData` 当前只有这些内容的周目总量，无法识别本场新增条目。
