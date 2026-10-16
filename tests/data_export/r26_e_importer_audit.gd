extends SceneTree

## 复用正式导表 smoke：核对 CSV 与实际 Godot Resource，不触碰存档或场景根流程。
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


## 直接读取真实来源表，避免用脚本默认值作为预期结果。
func _rows(table: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open("res://data/source_tables/%s.csv" % table, FileAccess.READ)
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() <= 1:
			continue
		var row: Dictionary = {}
		for i: int in mini(headers.size(), cells.size()):
			row[headers[i]] = cells[i]
		result.append(row)
	return result


## 失败同时写入 Godot Output，并使进程返回失败码。
func _expect(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		push_error("INT-17E FAIL: " + label)


## 核对四关、身份、Tier、数值和缺失结局的真实加载边界。
func _run() -> void:
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	_expect(catalog != null and catalog.profiles.size() == 4, "正式四关目录")
	var levels := _rows("02_主播关卡")
	for i: int in levels.size():
		var row: Dictionary = levels[i]
		var profile: LevelProfile = catalog.profiles[i]
		_expect(profile.level_id == row["level_id"] and profile.streamer_id == row["streamer_id"], "关卡顺序/主播 ID")
		_expect(profile.streamer_name == row["streamer_name"] and profile.stream_topic == row["live_theme"], "主播名/主题")
		_expect(profile.normal_speech_pool_source.pool_id == row["word_pool_id"], "真实普通池 ID")
		_expect(not profile.get_normal_speech_pool().is_empty(), "普通词句可读")
		_expect(profile.true_contradictions.size() == 1 and profile.false_contradictions.size() == 5, "真假矛盾完整")
		_expect(profile.streamer_portrait != null and profile.opponent_tier_03_portrait != null and profile.opponent_defeat_portrait != null, "四关正式立绘")
		_expect(profile.assimilation_rewards.is_empty(), "禁用奖励没有进入关卡")
		_expect((profile.streamer_live_background == null) == (profile.streamer_id == "fox"), "Fox缺背景，其余三关已有背景")
		if profile.streamer_id == "frog":
			_expect(profile.streamer_live_foreground != null and profile.opponent_defeat_effect_id == &"", "青蛙前景/空特效ID")
		print("INT-17E LEVEL PASS: ", profile.level_id, " / ", profile.streamer_id)
	for row: Dictionary in _rows("01_身份配置"):
		var identity: IdentityOption = load("res://data/identity/%s.tres" % row["identity_id"])
		_expect(identity != null, "身份加载")
		_expect(String(identity.identity_id) == row["identity_id"] and identity.display_name == row["display_name"] and identity.description == row["description"], "身份逐字段同步")
		_expect(identity.tendency_id == String(row["tendency"]).replace("heresy", "heretical"), "身份倾向转换")
	var tiers: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	for row: Dictionary in _rows("08_Tier档位"):
		var tier: CombatStageTierConfig = tiers.get_tier_config(int(row["tier"]))
		_expect(String(tier.music_event_id) == row["music_event_id"], "Tier音乐稳定事件ID")
		_expect(tier.foreground_slot_count == int(row["foreground_screen_cap"]), "Tier正式容量")
		_expect(tier.retaliation_draw_count_first_entry == int(row["retaliation_draw_count_first_entry"]), "首次入档抽取次数")
		_expect(is_equal_approx(tier.upgrade_threshold, float(row["pk_up_threshold"]) * 0.01), "Tier百分点转换")
	var numerics: CombatNumericsConfig = load("res://data/combat_stage/combat_numerics.tres")
	for row: Dictionary in _rows("06_基础参数"):
		if row["param_id"] == "aim_visual_size":
			_expect(is_equal_approx(numerics.aim_visual_diameter_px, float(String(row["value"]).split("x")[0])), "准心正方形视觉尺寸")
	for row: Dictionary in _rows("06_生命周期"):
		_expect(is_equal_approx(float(numerics.lifetimes_by_type_seconds[row["barrage_type"]]), float(row["base_lifetime_s"])), "12类生命周期")
		_expect(numerics.lifetime_tier_affected[row["barrage_type"]] == (row["affected_by_tier_lifetime_mult"] == "true"), "生命周期Tier资格")
	for row: Dictionary in _rows("09_直播数据"):
		var prefix: String = ""
		if row["rule_id"] == "contradiction_break":
			prefix = "contradiction_break"
		elif row["rule_id"] == "oracle_confirm":
			prefix = "oracle_confirmation"
		if not prefix.is_empty():
			_expect(numerics.get(prefix + "_viewer_gain") == int(row["viewer_value"]), "真实09观众增量")
			_expect(numerics.get(prefix + "_like_gain") == int(row["like_value"]), "真实09点赞增量")
			_expect(numerics.get(prefix + "_comment_delta") == int(row["comment_delta"]), "真实09评论增量")
			_expect(is_equal_approx(float(numerics.get(prefix + "_boost_duration_seconds")), float(row["duration_s"])), "真实09持续时间")
	var loser: LoserCardCatalog = load("res://data/loser_card/loser_card_catalog.tres")
	_expect(loser.profiles.is_empty(), "14禁用卡片不产生对象")
	var assets: PresentationAssetConfig = load("res://data/shared/presentation_asset_config.tres")
	_expect(assets.player_live_foreground != null and assets.player_live_background != null and assets.player_streamer_portrait != null, "主角素材真实加载")
	var names: EndingReligionNameConfig = load("res://data/ending/ending_religion_name_config.tres")
	for primary: String in ["orthodox", "heretical", "absurd"]:
		for secondary: String in ["orthodox", "heretical", "absurd"]:
			_expect(names.get_religion_name(primary, secondary).is_empty(), "九教名占位未冒充正式文本")
	var judgement: Resource = load("res://data/ending/ending_judgement_text_config.tres")
	for field: String in ["no_effective_behavior_text", "primary_tied_text", "consistent_text", "shifted_text"]:
		_expect(String(judgement.get(field)).is_empty(), "四判词占位过滤")
	var art: Resource = load("res://data/ending/ending_main_art_config.tres")
	for field: String in ["orthodox_main_art", "heretical_main_art", "absurd_main_art"]:
		_expect(art.get(field) == null, "结局主图真实缺失")
	var ending_comic: ComicSequence = load("res://data/ending/ending_comic.tres")
	var opening_tail: ComicSequence = load("res://data/comics/ending.tres")
	_expect(ending_comic.frames.is_empty() and not opening_tail.frames.is_empty(), "独立空通关漫画与开场P5/P6隔离")
	if _failures == 0:
		print("INT-17E RESOURCE SMOKE PASS: 4 levels / 12 identities / 6 tiers / 12 lifetimes / 09 / 13-14 disabled / ending gaps / assets")
	quit(0 if _failures == 0 else 1)
