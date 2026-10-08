# LC-10 关卡配置正式导表与新增需求联调（待补充）

**状态：未完成 / 暂缓 / 待策划继续提需求。**

## 开始前阅读
- AGENTS.md、known_traps.md
- docs/2. LevelConfiguration/README.md
- tools/README.md
- docs/2. LevelConfiguration/关卡配置系统_导表工具_2026-10-08_log.md
- data/source_tables/02_主播关卡.csv、03_普通词库.csv、04_矛盾内容.csv、05_关卡生成.csv
- 本系统与其他系统后续新增且已经确认的任务卡及完成日志

## 已完成的基础
- LC-01～LC-09 已提供 LevelProfile、LevelCatalog、LevelRunState 及当前关卡/推进相关接口。
- tools/export_game_data.py 已支持策划 XLSX 到独立 CSV 的字段校验与导出。
- TEST_ONLY 已将 02/03/04/05 的测试记录转换为 LevelProfile、LevelCatalog、词库和矛盾 Resource，并通过专用测试场景完成基础战斗联调。
- LevelProfile.normal_speech_pool_source / get_normal_speech_pool() 已支持读取词库 Resource。
- 正式运行入口仍使用现有关卡配置及占位内容；TEST_ONLY 资源与正式资源隔离。

## 待完成事项（仅登记，暂不执行）
1. **等待其他系统的新需求明确。** 收集对关卡资料、开播入口、主播展示、弹幕规则、特性、矛盾、关卡推进等的实际新增要求，再决定本系统需添加或调试的字段及接口。
2. **正式导表与绑定。** 在策划正式填写并确认对手、关卡、词库、矛盾与生成参数后，核对 Google Sheets → CSV → Godot Resource → LevelCatalog / LevelProfile → 运行时消费端的数据映射与稳定 ID，补齐当前未完成的正式资源接线。
3. **跨系统联调。** 按已确认的新任务卡检查开局房间「开始直播」进入首关、普通关切换、失败重开、Rest 继续、终局入口，以及实际使用的关卡内容，记录并修复真实错误。
4. **验证正式数据。** 使用真实关卡资源做最小 Godot 加载、战斗和流程验证；TEST_ONLY 测试结果不可替代正式配置验收。

## 当前明确的缺口
- data/source_tables/02_主播关卡.csv 和 04_矛盾内容.csv 当前仅有表头，没有有效正式数据。
- 05_关卡生成仍存在空白待定参数。
- data/level_configuration/level_001.tres 和 level_002.tres 仍以示例/占位内容为主。
- 工具目前具备 TEST_ONLY 的完整关卡生成路径，但普通正式导表尚未把 02/04/05 自动生成并绑定到正式 LevelProfile / LevelCatalog。
- 其他新增需求尚未全部确认，当前不确定是否需要调整 LevelProfile 字段和联动范围。

## 恢复条件与验收
本卡保持**未完成**；由项目负责人确认其他相关新需求和正式策划数据后，先修订本卡为可实施范围，再安排开发。

实施后的验收以实际确认的关卡内容和联动需求为准，至少检查：
- 正式导表生成及稳定 ID 关联；
- 主场景读取正式关卡配置；
- 进入首关、换关/重开、Rest 继续与结束分支；
- 运行时无新增相关 Godot 错误。

本次只登记待办，**不新增功能、不修改正式配置、不启动 Agent、不进行程序调试**。
