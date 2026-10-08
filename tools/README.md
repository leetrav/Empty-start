# 策划数据导表工具

Google Sheets 是策划编辑源；XLSX 作为本地输入，CSV 作为 Git / Agent 交付，已有接口对应的 Godot Resource 由工具生成。工具不会更改原始 XLSX。

## 首次准备

安装 Python 3.10+ 和 openpyxl：

~~~powershell
python -m pip install openpyxl
~~~

如果全局 Python 由 uv 管理并拒绝安装，则在仓库根目录创建虚拟环境：

~~~powershell
uv venv .venv
uv pip install --python .venv\Scripts\python.exe openpyxl
~~~

## 日常使用

1. 在 Google Sheets 策划数据总表中修改数据。
2. 选择「文件 → 下载 → Microsoft Excel (.xlsx)」，保存完整工作簿。
3. 在仓库根目录打开 PowerShell，运行：

~~~powershell
python tools/export_game_data.py --input "策划数据总表.xlsx"
~~~

如果使用上述 uv 虚拟环境，改用：

~~~powershell
.\.venv\Scripts\python.exe tools/export_game_data.py --input "策划数据总表.xlsx"
~~~

输入文件在其他目录时填写完整路径；只想更新 CSV，可添加 --csv-only。运行后终端逐项列出处理 Sheet、有效记录、警告、错误、输出路径和未变化文件。

## 输出

- data/source_tables/：18 个业务 Sheet 共导出 20 个 UTF-8 CSV；06_战斗数值单独拆成 06_战斗数值、06_生命周期、06_基础参数，每个文件只有自己的字段表头。
- data/generated/level_configuration/：按 pool_id 分组生成 LevelSpeechPool 资源；仅启用的普通话语进入 Resource，停用行仍保留在 CSV。
- data/generated/combat_stage/tier_catalog.tres：从已有正式 Tier Resource 模板生成表格对应字段；Sandbox 已读取这份生成配置，原模板里独有的 Neutral 权重和立绘状态保留。
- 00_填写说明仅供策划阅读，跳过导出；以 EXAMPLE_ 开头的 ID、notes 明确为「示例行」的记录会跳过，并显示警告。

同一输入连续运行保持文件字节与修改时间不变。校验错误时停止整轮写入；可保留警告项的原始空值。仅管理工具自身输出路径，其他人工文件不受影响。**直接在 Google Sheets 修改正式数据，下次重新导出，不编辑生成文件。**

## 已确认的字段映射

| 策划表字段 | Godot 字段 | 说明 |
|---|---|---|
| 03.word_id | LevelSpeech.original_sentence_id | 稳定 ID 原样保留 |
| 03.text | LevelSpeech.text | 文本、标点、换行原样 |
| 03.tendency | LevelSpeech.tendency_id | heresy → heretical；其他值原样 |
| 03.strength | LevelSpeech.strength | int，必须为 1～3 |
| 03.weight | LevelSpeech.appearance_weight | float，必须大于 0 |
| 08.pk_up_threshold | CombatStageTierConfig.upgrade_threshold | 策划 56 → Godot 0.56 |
| 08.pk_down_threshold | CombatStageTierConfig.downgrade_threshold | 同上；Tier 0 空值按现有资源 0.0 |
| 08.spawn_batch_mult | generation_count_multiplier | 倍率 float |
| 08.spawn_frequency_mult | generation_frequency_multiplier | 倍率 float |
| 08.move_speed_mult | movement_speed_multiplier | 倍率 float |
| 08.lifetime_mult | lifetime_multiplier | 倍率 float |
| 08.pullback_mult | opponent_pullback_multiplier | 倍率 float |
| 08.repeat_count | repeat_count_per_hit | int |
| 05.spawn_interval_s | LevelProfile.base_spawn_interval_seconds | 映射记录，待正式接入 |
| 06.word_strength_1_pk=0.12 | PK 内部 0.0012 | 百分点除以 100；06 暂只导 CSV |

08.presentation_key、music_event_id、repeat_lifetime_s 留在 CSV，当前 Tier Resource 无对应字段。03.pool_id、source_streamer_id、enabled、notes 留在 CSV，仅 pool_id/启用状态参与 Resource 分组与过滤。

## 校验和待办

错误：缺表头、重复稳定 ID、无效数字/布尔/枚举、已具备正式来源的关联缺失、Tier 阈值与复读寿命异常。警告：示例/说明行、未填写正式值、暂无正式父表的引用。均显示 Sheet/行号/字段/原因。

当前 03_普通词库有 344 条正式话语，归属 pool_streamer_a。02_主播关卡、04_矛盾内容、14_败者卡目前只有明确示例数据，所以对应 CSV 仅含表头。

**关卡数据的正式 ID 待策划决定**：工作簿示例 level_01/streamer_a，项目既有样例 level_001/streamer_sample。导表已真实加载 LevelSpeechPool，暂时保留原本 LevelProfile.normal_speech_pool，等待稳定 ID 对齐后由 Agent 正式绑定词库。

## Godot 验证

Godot 4.7.2 完成项目导入后，在根目录执行：

~~~powershell
godot --headless --path . --script res://tests/data_export/test_generated_tables.gd
~~~

测试将 03 的 CSV 与已加载的 LevelSpeech Resource 逐条核对，并检查 6 档 Tier 资源。全量流程仍以真实 Sandbox 场景启动为准；不通过脱离 Autoload 的单文件编译判定 Sandbox 可用性（known_traps.md / KT-25）。
