# FO-11 测试配置前置任务日志（2026-10-08）

## 1. 完成本次前置任务

按用户授权完成 FO-11 TEST_ONLY 奖励配置前置。开始前 fetch 最新 main `bf435882e43cce708e5c9b2d2e5651cbb8a8a4c4`，检查旧目录干净后建立独立 worktree 与 `codex/lane-e-fo11-test-fixtures` 分支。旧目录保持原状。

本任务只准备可读取的配置与实例，并验证现有奖励 API；完整 FO-11 Sandbox 集成仍由 A 接手。本轮没有执行 FO-12、AS-06/07 或 BT-13。

## 2. 修改文件与配置边界

- `data/level_configuration/word_pool_inheritance_config.gd` 与原生 UID：新增最小 `WordPoolInheritanceConfig` Resource，包含稳定 pool_id、整池继承权重、继承资格和矛盾池标记。
- `data/level_configuration/level_profile.gd`：新增可选 `normal_pool_inheritance` 和独立 `inheritable_trait_ids` 白名单；默认 null / 空列表，使旧关卡不自动产生继承奖励。
- `tests/fixtures/fo11/test_normal_pool_inheritance.tres`：TEST_ONLY 普通池 `test_only_streamer_sample_normal`，占位权重 1.0，允许继承，非矛盾池。
- `tests/fixtures/fo11/test_level_001.tres`：真实 LevelProfile 类型，保留 `level_001 / streamer_sample`，挂接上述元数据和已有 occlusion 白名单。话语 / 矛盾 ID、正文及基础参数沿用原样例。
- `tests/fixtures/fo11/test_level_catalog.tres`：真实 LevelCatalog，第一关使用测试配置，第二关只引用已有 `level_002.tres`，没有新造第二关奖励。
- `tests/fixtures/fo11/test_loser_card_catalog.tres`：真实 LoserCardCatalog / LoserCardProfile，含 streamer_sample 一张测试卡，卡名 / 文案和原生占位纹理均标明 TEST_ONLY。
- `tests/fixtures/fo11/README.md`：精确注入步骤、A 的同场确认回调读取示例、来源查询和正式替换路径。
- 2 / 4 / 13 / 14 / 16 系统 README 与 System_Collaboration：同步静态配置接口及职责。本日志记录验收与交接。

没有修改 `scenes/sandbox/sandbox.gd` 或生产关卡实例 / 目录、生产败者卡目录。没有新增运行 Manager、Autoload、奖励提交抽象或可变成果副本。普通词库正文继续由同关 `normal_speech_pool` 唯一提供，元数据 Resource 不另存句子。

## 3. 当前可以做什么

已有 LevelRunState / CB / Session 等接口可以直接读取测试 LevelCatalog / LevelProfile；14 的登记参数直接来自 `current_level.normal_pool_inheritance` 和 `inheritable_trait_ids`，16 通过注入的测试 Catalog 查到卡片。单句出现权重和本关启用特性不作为继承资格来源。

`occlusion` 是工程当前已有稳定特性 ID，组件装配与普通话语兼容规则实际通过。所有保存成果仍由 14 / 16 持有，其已有去重及按关卡 / 主播查询语义保持原状。

## 4. Godot 4.7.2 验证结果

- 引擎 `4.7.2.stable.steam.ed1daf0bf`，新 Resource 与修改后的 LevelProfile 单文件 `--headless --check-only --script` 解析通过，退出码 0。
- 最小临时实际运行 smoke 载入四份 fixture Resource 和生产目录，确认生产卡片目录仍为空、生产首关继承配置仍为 null / 空列表。
- 通过真实 `BarrageTraitSet.add_trait()` / `are_compatible()` 验证 fixture 的 occlusion ID 支持及兼容；正常句子仍能按 fixture 的 LevelProfile 读取。
- 通过真实 CB `register_launched_shot()` / `resolve_shot_hit_ids()` 得到 NOT_BROKEN 和 BREAKTHROUGH；未击破及尚未正式确认时，16 发卡和 14 真正击败 / 词库 / 特性登记均未新增奖励。
- 真正击破后使用已有 HitResolution 历史接口、RepeatGenerationStats 和 FinalOracleSession，调用 Session 的共同确认入口。临时接收方订阅真实 `confirmation_committed`，校验关卡 / CB 事实，从同一 LevelProfile 读取元数据并调用真实 `grant_on_true_defeat()`、`register_defeated_streamer()`、`register_inherited_word_pool()`、`register_inherited_trait()`，全部首次成功。
- 读取 `get_new_card_for_level()` / `get_acquired_cards()` 得到一张卡；读取 `get_new_content_for_source()` / `get_current_content_snapshot()` 得到一个稳定池权重 1.0 和一个 occlusion，来源正确归属 `level_001 / streamer_sample`。
- 同关重复确认不重发信号；直接重复请求四个登记入口均返回 false，来源记录保持原值。错误来源查询为空，矛盾池、禁止继承池和白名单外的特性登记被已有规则拒绝。
- 最终输出 `FO11_TEST_FIXTURES_SMOKE_PASS: 41 checks`，退出码 0，stderr 为空。没有新增仓库单元测试或长期 smoke 脚本；临时探针已删除。
- Godot-MCP 9080 doctor 未连接，使用 CLI 并按 KT-34 等待实际进程结束。新 worktree 首次导入有既有 OGG 预加载提示；导入完成后最终解析与 runtime smoke 无相关错误。无关导入 sidecar / UID 已恢复或删除，仅保留本任务新 Resource 的 UID。
- 使用独立临时 APPDATA，用户原有配置及存档未改写。`git diff --check` 通过；首次提交前 main 为 bf435882。发布 PR 前 main 新增 `DEVELOPMENT_PLAN_2026-10-08.md` 并前进至 56dfa20，本分支已无冲突合入；上游只增文档，本次已验证的资源、脚本与 fixture 内容保持一致。

## 5. A 的下一步与正式替换

完整操作说明在 `tests/fixtures/fo11/README.md`。当前 Sandbox 的关卡目录仍是 SAMPLE_LEVEL_CATALOG 常量；A 的 FO-11 卡需增加目录注入，使 LevelRunState 和 Scripture 绑定读取同一目录，同时使用既有 loser_card_catalog 属性注入测试卡片目录。

A 保留正式确认回调的同周目、同关、CB BREAKTHROUGH 校验和普通历史 / 倾向提交；首次真正击败登记成功后读取配置，补齐词库 / 特性登记，再完成真实 Sandbox 手动、自动、重复和未击破验收。本前置的临时接收方未替代或修改 Sandbox，不能据此把 FO-11 全卡标为完成。

正式交付时，在生产败者卡目录填写正式资料，在生产 LevelProfile 的同一字段填写策划认可的稳定 pool_id、整池权重和白名单，退出测试目录注入。1.0 和 TEST_ONLY 卡片内容均为验收占位；使用新周目复验，不能无依据补发历史确认奖励。

## 6. 文档与已知问题

已更新上述直接相关 README 和协作文档；旧 FO11 前置接线 note 保留为历史记录，FinalOracle README 明确区分已提供测试配置与尚未完成 Sandbox 联调。

已检查 known_traps，沿用 KT-15 / KT-18 / KT-20 / KT-27 / KT-34；没有新增可复现的长期陷阱，因此 `known_traps.md` 未修改。提交、推送及非 Draft PR 完成后停止，等待 ChatGPT Review 与用户合并。
