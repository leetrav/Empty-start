# 策划数据导表｜TEST_ONLY 联调说明

## 当前数据状态

只有 01_身份配置，以及 06_战斗数值、08_Tier档位中已经写进系统案的确定规则具有正式依据。其他系统（包括当前的 344 条普通词库）均处于待定稿状态。CSV 能解析不代表策划批准。

## 日常操作

第一次需要 Python 3.10+ 和 openpyxl：

~~~powershell
python -m pip install openpyxl
~~~

使用 uv 管理 Python 时可创建独立环境：

~~~powershell
uv venv .venv
uv pip install --python .venv\Scripts\python.exe openpyxl
~~~

### 1. 正常 Google Sheets 导表

在 Google Sheets 选择「文件 → 下载 → Microsoft Excel (.xlsx)」，将 XLSX 放在仓库目录，在 PowerShell 执行：

~~~powershell
python tools/export_game_data.py --input "策划数据总表.xlsx"
~~~

产物：data/source_tables/ 下各系统原字段 CSV。新版 Google Sheets 的 `06_战斗数值`、`06_生命周期`、`06_基础参数` 是三张独立工作表，导表器直接读取；旧 TEST_ONLY 工作簿中的单页三区块格式仍可兼容读取。Tier 生成到 data/test_only/sheet_preview/combat_stage/tier_catalog.tres 供比对。游戏运行时只使用 data/combat_stage/tier_catalog.tres；只有正式评审确认新 Tier 数值后才更新该唯一入口。尚未定稿的普通词库只能生成到 data/test_only/sheet_preview/level_configuration/pool_streamer_a.tres，保留全部 344 条供读取测试，暂时不能作为正式关卡词库。

普通模式与 `--test-only` 共用 `00_填写说明!A1` 的 TEST_ONLY 来源标记。普通模式发现该标记后会在解析和写盘前拒绝输入，返回退出码 2；测试来源必须显式使用 `--test-only`，写入独立 TEST_ONLY 目录。

### 2. 生成一组可直接联调的 TEST_ONLY 数据

~~~powershell
python tools/export_game_data.py --input "tests/fixtures/data_export/test_only_data.xlsx" --test-only
~~~

测试工作簿有 19 张 Sheet：01 身份与 06、08 的来源内容直接沿用策划表供校验，15 张未定稿 Sheet 使用单独的 TEST_ONLY 数据。

会输出：
- data/test_only/source_tables/：15 个按系统独立的 CSV；
- data/test_only/generated/level_configuration/test_pool_01.tres、test_pool_02.tres：共 12 条测试弹幕；
- 同目录 test_level_01.tres、test_level_02.tres、test_only_level_catalog.tres：两关独立测试配置，包括主播、词库引用、真假矛盾、生成参数。

测试场景：res://tests/fixtures/data_export/test_only_sandbox.tscn。该场景继承原有 Sandbox，单独注入 TEST_ONLY LevelCatalog；游戏正式入口继续使用既有 LevelCatalog。

所有自行创造的记录使用 test_ 稳定 ID（例如 test_level_01、test_word_01），仅有 normal_delay_min_s 等固定接口参数键保留原名并用 notes 标记 TEST_ONLY。所有额外数值是测试占位，不构成策划定稿；音频、美术资产缺失时保留空值。

### 3. 提交与替换

导表工具在源工作簿出现字段/关联/类型错误时中止整轮写入，报告 Sheet、原始行号、字段、原因。未决定的空值报告警告；不会自动编造正式数值。相同输入重复导出字节和修改时间不变。可加 --csv-only 只导 CSV。

后续确定正式配置：更新 Google Sheets → 下载 XLSX → 运行正常导表命令 → Agent 根据正式 data/source_tables/ 建立相应 Resource。LevelProfile 已新增 normal_speech_pool_source: LevelSpeechPool 和 get_normal_speech_pool()；正式词库只需重新挂载资源，弹幕选择、经文和 Sandbox 已统一读取这个入口。原有 normal_speech_pool 继续兼容旧关卡。

正常模式与 TEST_ONLY 模式使用不同输出目录；未标记 TEST_ONLY 的工作簿不能使用 `--test-only`，带标记的工作簿也不能进入普通模式。可用 `--output-root <目录>` 将导出产物重定向到隔离根目录；省略时继续写入当前项目根目录，引用校验仍读取当前项目中的正式来源数据。当前尚未实现全部业务表的正式 Godot 导入器；TEST_ONLY 模式只实现了联调必需的 02/03/04/05 → LevelProfile 和 LevelCatalog，其他表已准备 CSV，可由对应系统 Agent 使用。

## 字段映射

普通词库：word_id → LevelSpeech.original_sentence_id；text → text；tendency → tendency_id（heresy → heretical）；strength → strength；weight → appearance_weight。

关卡/矛盾：02.level_id → LevelProfile.level_id；02.streamer_id → streamer_id；02.word_pool_id → normal_speech_pool_source 的 pool_id；04.type=true/false → true_contradictions / false_contradictions；05.spawn_interval_s → base_spawn_interval_seconds；05.move_speed_px_s → base_move_speed_pixels_per_second。生成的 TEST_ONLY 关卡中四类倾向的比率 1/1/1/0.5 为临时混合权重。

Tier：pk_up_threshold/down → upgrade_threshold/downgrade_threshold；策划百分比 56 → 0.56。spawn_batch_mult → generation_count_multiplier；spawn_frequency_mult → generation_frequency_multiplier；move_speed_mult → movement_speed_multiplier；lifetime_mult → lifetime_multiplier；pullback_mult → opponent_pullback_multiplier；repeat_count → repeat_count_per_hit。06 中的 PK 收益按百分点 / 100 映射，如 0.12 → 0.0012，06 目前只生成 CSV。Tier 原资源独有的 neutral_weight_multiplier 和立绘状态保持不变。

## 验证命令

~~~powershell
python tests/data_export/test_export_modes.py
godot --headless --path . --script res://tests/data_export/test_generated_tables.gd
godot --headless --path . --script res://tests/data_export/test_test_only_integration.gd
godot --headless --path . res://tests/fixtures/data_export/test_only_live_smoke.tscn --quit-after 720
~~~

已知环境问题：独立 Windows worktree 在首次运行前可能需要 Godot --headless --editor --import，才能生成音频 .ogg 的导入缓存；不能仅根据缓存缺失报错判定游戏代码失败。真实战斗 Smoke 使用场景启动方式，从而初始化完整的 Autoload。

注意：当前 TEST_ONLY Live Smoke 只验证实际 Sandbox 生成、未击破 Rest 信号与第二关数据消费；蓄力攻击、真假矛盾、PK 命中、存档、重复继续及最终 Ending 交由 tests/integration/int_04_full_run.tscn 进行完整路线验收。自动输入不代表实体鼠标操作。Godot 资源导入准备阶段的 ObjectDB / Resource 清理提示应与正式测试结果分开记录。


## 2026-10-15 新表与 Motion 更新

Google 策划总表最新版支持 01～25 业务表（06拆为三表），共 27 张 CSV。新增 19～25 表按原字段名保留启用/禁用记录；旧正式工作簿和旧 TEST_ONLY 夹具缺失这些新表时继续兼容。

追加校验包括：02↔23立绘关联、02↔24教学关联、02↔20剧情关联、19↔25账号关联、20/21/23启用主播与02匹配；22的 value 同时允许数字和 true/false。Tier四种 Motion 权重须非负整数且合计100，并逐档写入 TEST_ONLY Tier 预览。

本工具生成的 Tier 资源仍然只放在 data/test_only/sheet_preview，不改正式运行的 data/combat_stage/tier_catalog.tres。17音频 CSV 的文件路径还需未来由音频配置消费，不能把配表当作Godot音频已接通。

回归命令（需要 Python + openpyxl）：

    python tests/data_export/test_export_modes.py
    python tests/data_export/test_new_sheets_motion.py

具体本轮导表数目、来源与待办见 docs/2. LevelConfiguration/关卡配置系统_LC-10B_2026-10-15_log.md。
