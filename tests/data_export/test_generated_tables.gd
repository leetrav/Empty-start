## 从待定稿 CSV 逐行核对 TEST_ONLY 词库预览；Tier 继续读取现有确认配置。
extends SceneTree

const CSV_PATH := "res://data/source_tables/03_普通词库.csv"
const POOL_PATH := "res://data/test_only/sheet_preview/level_configuration/pool_streamer_a.tres"
const TIER_PATH := "res://data/generated/combat_stage/tier_catalog.tres"

func _initialize() -> void:
    # 只有明确输出成功时才以退出码 0 结束，防止 headless 空跑。
    var speech_pool: LevelSpeechPool = load(POOL_PATH) as LevelSpeechPool
    if speech_pool == null or speech_pool.pool_id != "pool_streamer_a":
        _fail("词库资源加载失败或 pool_id 错误")
        return
    var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
    if file == null:
        _fail("CSV 文件无法打开")
        return
    var header: PackedStringArray = file.get_csv_line()
    var keys: Array[String] = ["word_id", "text", "tendency", "strength", "pool_id", "weight", "source_streamer_id", "enabled", "notes"]
    for idx: int in range(keys.size()):
        if idx >= header.size() or header[idx] != keys[idx]:
            _fail("CSV 字段漂移：" + keys[idx])
            return
    var by_id: Dictionary = {}
    for speech: LevelSpeech in speech_pool.speeches:
        if speech == null or speech.original_sentence_id in by_id:
            _fail("词库内存在无效或重复的 LevelSpeech")
            return
        by_id[speech.original_sentence_id] = speech
    var count: int = 0
    while not file.eof_reached():
        var cols: PackedStringArray = file.get_csv_line()
        if cols.size() <= 1 or cols[0].is_empty():
            continue
        if cols[7] != "true":
            continue
        count += 1
        if not by_id.has(cols[0]):
            _fail("缺少 word_id：" + cols[0])
            return
        var speech: LevelSpeech = by_id[cols[0]]
        var want_tendency: String = "heretical" if cols[2] == "heresy" else cols[2]
        if speech.text != cols[1] or speech.tendency_id != want_tendency:
            _fail("内容或倾向转换失败：" + cols[0])
            return
        if speech.strength != int(cols[3]) or not is_equal_approx(speech.appearance_weight, float(cols[5])):
            _fail("强度或权重转换失败：" + cols[0])
            return
    if count != by_id.size() or count < 1:
        _fail("记录数与启用词库不一致")
        return
    var tiers: CombatStageTierCatalog = load(TIER_PATH) as CombatStageTierCatalog
    if tiers == null:
        _fail("Tier Resource 加载失败")
        return
    var t3: CombatStageTierConfig = tiers.get_tier_config(3)
    if t3 == null or not is_equal_approx(t3.upgrade_threshold, 0.79):
        _fail("Tier 3 阈值转换失败")
        return
    if t3.repeat_count_per_hit != 12 or not is_equal_approx(t3.lifetime_multiplier, 0.6):
        _fail("Tier 3 复读数量或生命周期倍率错误")
        return
    print("PASS Godot LevelSpeech CSV -> Resource: ", count, " records; Tier Resource: 6 entries.")
    quit(0)


func _fail(reason: String) -> void:
    push_error("FAIL 导表加载验证：" + reason)
    quit(1)
