## 从正式 CSV 读取当前 Sandbox 需要的展示字段，并转成现有 Resource/UI 接口。
class_name FormalSheetRuntimeConsumer
extends RefCounted

const BubbleConfig = preload("res://data/streamer_bubble_dialogue/bubble_dialogue_config.gd")
const BubbleEntry = preload("res://data/streamer_bubble_dialogue/bubble_dialogue_entry.gd")
const AudioEventScript = preload("res://core/audio/audio_event.gd")

const TABLES := {
	"levels": "res://data/source_tables/02_主播关卡.csv",
	"audio": "res://data/source_tables/17_音频事件.csv",
	"comments": "res://data/source_tables/19_直播评论词库.csv",
	"dialogue": "res://data/source_tables/20_主播气泡对白.csv",
	"portraits": "res://data/source_tables/23_对手立绘配置.csv",
	"viewers": "res://data/source_tables/25_直播观众账号.csv",
}

var _tables: Dictionary = {}
var comment_parameters: Dictionary = {}


func _init() -> void:
	for table_name: String in TABLES:
		_tables[table_name] = _read_csv(TABLES[table_name])
	for row: Dictionary in _read_csv("res://data/source_tables/22_直播评论表现参数.csv"):
		var key := str(row.get("param_id", ""))
		var value: String = str(row.get("value", ""))
		# 两个布尔开关按表定义转成原生 bool，避免字符串 "false" 在调用方被判真。
		if key in ["comment_pause_with_game", "comment_updates_business_counter"]:
			comment_parameters[key] = value.to_lower() == "true"
		elif not value.is_empty() and value.is_valid_float():
			comment_parameters[key] = float(value)


## 按稳定 level_id 取正式关卡表现，不依赖旧示例 Resource 的 streamer_id。
func get_level_presentation(level_id: String) -> Dictionary:
	var level_row := _find_row("levels", "level_id", level_id)
	if level_row.is_empty():
		return {}
	var streamer_id := str(level_row.get("streamer_id", ""))
	var portrait_row := _find_row("portraits", "portrait_set_id", str(level_row.get("portrait_set_id", "")))
	var portraits: Array[Texture2D] = []
	for column: String in ["idle_asset_path", "tier_01_asset_path", "tier_02_asset_path", "tier_03_asset_path"]:
		portraits.append(_load_texture(str(portrait_row.get(column, ""))))
	var background := _load_texture(str(level_row.get("background_asset_id", "")))
	if background == null:
		# 正式表未填背景资源 ID 时，只使用仓库内已存在且与 streamer_id 同名的实物资源。
		background = _load_texture("assets/environment/live/%s/background.png" % streamer_id)
	return {
		"streamer_id": streamer_id,
		"streamer_name": str(level_row.get("streamer_name", "")),
		"fan_group_name": str(level_row.get("fan_group_name", "")),
		"story_config_id": str(level_row.get("story_config_id", "")),
		"portrait_set_id": str(level_row.get("portrait_set_id", "")),
		"portrait_idle": portraits[0],
		"portrait_tiers": portraits,
		"portrait_defeat": _load_texture(str(portrait_row.get("defeat_asset_path", ""))),
		"portrait_defeat_transition": _load_texture(str(portrait_row.get("defeat_transition_asset_path", ""))),
		"background": background,
		"fan_badge": _load_texture(str(level_row.get("fan_badge_asset_id", ""))),
	}


## 把当前剧情 ID 下已启用的事件对白装入现有剧情 Presenter 配置。
func create_dialogue_config(story_config_id: String) -> BubbleDialogueConfig:
	var config: BubbleDialogueConfig = BubbleConfig.new()
	for row: Dictionary in _tables.get("dialogue", []):
		if str(row.get("story_config_id", "")) != story_config_id or not _is_enabled(row):
			continue
		var event_id := _dialogue_event_id(
			str(row.get("trigger_type", "")), str(row.get("trigger_key", "")))
		if str(row.get("trigger_type", "")) == "random_idle":
			event_id = &"timed"
		if event_id == &"":
			continue
		var entry: BubbleDialogueEntry = BubbleEntry.new()
		entry.side = BubbleEntry.SpeakerSide.OPPONENT if str(row.get("speaker_side", "")) == "opponent" else BubbleEntry.SpeakerSide.PLAYER
		entry.text = str(row.get("text", ""))
		entry.original_sentence_id = str(row.get("source_word_id", ""))
		entry.event_id = event_id
		entry.is_random_idle = str(row.get("trigger_type", "")) == "random_idle"
		# 闲聊使用低优先级定时气泡；CSV 定时字段即使当前为空也保留为 0。
		entry.priority = BubbleEntry.Priority.TIMED_IDLE if entry.is_random_idle else BubbleEntry.Priority.PLOT
		entry.display_duration_seconds = maxf(0.1, float(row.get("display_duration_s", "3")))
		entry.trigger_time_seconds = _float_or(str(row.get("trigger_time_s", "")), 0.0)
		entry.random_weight = maxf(0.0, float(row.get("random_weight", "1")))
		config.entries.append(entry)
	return config


## 正式音频表覆盖已有稳定事件 ID；未映射资产保留项目现有兼容配置。
func register_audio_events(audio_manager: Node) -> int:
	var registered := 0
	for row: Dictionary in _tables.get("audio", []):
		var event_id := str(row.get("event_id", ""))
		var asset_path := str(row.get("asset_path_or_id", ""))
		if event_id.is_empty() or asset_path.is_empty() or not ResourceLoader.exists("res://" + asset_path.trim_prefix("res://")):
			continue
		var stream := load("res://" + asset_path.trim_prefix("res://")) as AudioStream
		if stream == null:
			continue
		var event: AudioEvent = AudioEventScript.new()
		event.event_id = StringName(event_id)
		event.audio_type = _audio_type(str(row.get("audio_type", "sfx")))
		event.stream = stream
		event.volume_db = float(row.get("volume_db", "0"))
		event.pitch_min = maxf(0.01, float(row.get("pitch_min", "1")))
		event.pitch_max = maxf(event.pitch_min, float(row.get("pitch_max", str(event.pitch_min))))
		event.loop = str(row.get("loop", "false")).to_lower() == "true"
		event.transition_group = str(row.get("transition_group", ""))
		if audio_manager.has_method("register_event") and audio_manager.call("register_event", event):
			registered += 1
	return registered


## 19/25 两表按 viewer_id 关联；通用评论和当前主播专属评论合并给所属直播侧。
func get_comments(side_scope: String, streamer_id: String) -> Array[Dictionary]:
	var viewers: Dictionary = {}
	for viewer: Dictionary in _tables.get("viewers", []):
		if _is_enabled(viewer):
			viewers[str(viewer.get("viewer_id", ""))] = viewer
	var result: Array[Dictionary] = []
	for comment: Dictionary in _tables.get("comments", []):
		if not _is_enabled(comment):
			continue
		var comment_streamer := str(comment.get("streamer_id", ""))
		if not comment_streamer.is_empty() and comment_streamer != streamer_id:
			continue
		var viewer: Dictionary = viewers.get(str(comment.get("viewer_id", "")), {})
		if viewer.is_empty() or not _side_matches(str(viewer.get("side_scope", "")), side_scope):
			continue
		if side_scope == "opponent":
			var viewer_streamer := str(viewer.get("streamer_id", ""))
			if not viewer_streamer.is_empty() and viewer_streamer != streamer_id:
				continue
		var weight := maxf(0.0, float(comment.get("weight", "1"))) * maxf(0.0, float(viewer.get("weight", "1")))
		if weight > 0.0:
			result.append({"text": str(comment.get("text", "")), "viewer": viewer, "weight": weight})
	return result


func _read_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty():
			continue
		var row: Dictionary = {}
		for index: int in mini(headers.size(), cells.size()):
			row[str(headers[index])] = cells[index]
		rows.append(row)
	return rows


func _find_row(table_name: String, key: String, value: String) -> Dictionary:
	for row: Dictionary in _tables.get(table_name, []):
		if str(row.get(key, "")) == value and _is_enabled(row):
			return row
	return {}


func _load_texture(asset_path: String) -> Texture2D:
	if asset_path.is_empty():
		return null
	var resource_path := "res://" + asset_path.trim_prefix("res://")
	if not ResourceLoader.exists(resource_path):
		return null
	return load(resource_path) as Texture2D


func _is_enabled(row: Dictionary) -> bool:
	return str(row.get("enabled", "true")).to_lower() == "true"


func _dialogue_event_id(trigger_type: String, trigger_key: String) -> StringName:
	match trigger_key:
		"T1_connect": return &"combat_connected"
		"pk_win": return &"combat_win"
		"pk_lose": return &"combat_lose"
		"tier_down": return &"combat_tier_down"
	match trigger_type:
		"timed": return &"timed"
		"connect": return &"combat_connected"
		"tier_up": return &"combat_tier_up"
		"tier_down": return &"combat_tier_down"
		"win": return &"combat_win"
		"lose": return &"combat_lose"
		"hit_word": return &"actual_hit"
		_: return &""


func _audio_type(value: String) -> int:
	match value.to_lower():
		"music": return AudioEvent.AudioType.MUSIC
		"ui": return AudioEvent.AudioType.UI
		_: return AudioEvent.AudioType.SFX


## CSV 空值按既有默认值处理，避免一个空选填单元格中止整张表加载。
func _float_or(value: String, fallback: float) -> float:
	return float(value) if value.is_valid_float() else fallback


func _side_matches(account_scope: String, side_scope: String) -> bool:
	return account_scope == "both" or account_scope == side_scope
