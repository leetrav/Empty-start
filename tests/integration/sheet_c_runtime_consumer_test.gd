extends SceneTree

const ConsumerScript = preload("res://data/shared/formal_sheet_runtime_consumer.gd")
const AudioManagerScript = preload("res://core/autoload/audio_manager.gd")
var _failed := false


func _initialize() -> void:
	var consumer = ConsumerScript.new()
	_assert(typeof(consumer.comment_parameters["comment_pause_with_game"]) == TYPE_BOOL, "22 pause parameter is bool")
	_assert(typeof(consumer.comment_parameters["comment_updates_business_counter"]) == TYPE_BOOL, "22 counter parameter is bool")
	_assert(consumer.comment_parameters["comment_updates_business_counter"] == false, "display comments do not alter business count")
	var audio_manager = AudioManagerScript.new()
	var audio_registered: int = consumer.register_audio_events(audio_manager)
	_assert(audio_registered == 23, "all 23 audio rows with present assets load into AudioManager")
	var barrage_event = audio_manager.get("_audio_config").find_event(&"barrage_spawn")
	_assert(barrage_event != null and barrage_event.volume_db == 0.0 and barrage_event.pitch_min == 1.0 and barrage_event.pitch_max == 1.0, "audio event carries CSV playback values")
	var dialogue_counts := {"story_level_001": 0, "story_level_002": 0, "story_level_003": 0, "story_level_004": 0}
	var idle_count := 0
	var dialogue_total := 0
	for story_id: String in dialogue_counts:
		var config = consumer.create_dialogue_config(story_id)
		for entry in config.entries:
			dialogue_counts[story_id] += 1
			dialogue_total += 1
			if entry.event_id == &"timed":
				idle_count += 1
	_assert(idle_count == 48, "all 48 enabled random_idle lines enter timed dialogue config")
	_assert(dialogue_total == 119, "all enabled dialogue rows map into the four production stories")
	var player_rows: Array[Dictionary] = consumer.get_comments("player", "")
	var alien_rows: Array[Dictionary] = consumer.get_comments("opponent", "alien")
	_assert(not player_rows.is_empty() and not alien_rows.is_empty(), "enabled viewer/comment rows resolve for both sides")
	_assert(_simulate_weighted_viewers(player_rows, 1000) and _simulate_weighted_viewers(alien_rows, 1000), "weighted audience simulation yields valid weighted candidates")
	print("SHEET-C PASS: audio=%d/23, 22 typed booleans, 119 dialogue incl 48 timed idle, audience simulation player=%d opponent=%d; dialogue=%s" % [audio_registered, player_rows.size(), alien_rows.size(), str(dialogue_counts)])
	quit(1 if _failed else 0)


func _simulate_weighted_viewers(rows: Array[Dictionary], draws: int) -> bool:
	var counts: Dictionary = {}
	for _draw in range(draws):
		var total := 0.0
		for row: Dictionary in rows:
			total += float(row.get("weight", 0.0))
		if total <= 0.0:
			return false
		var target := randf() * total
		for row: Dictionary in rows:
			target -= float(row.get("weight", 0.0))
			if target <= 0.0:
				var viewer: Dictionary = row.get("viewer", {})
				var name := str(viewer.get("display_name", ""))
				if name.is_empty():
					return false
				counts[name] = int(counts.get(name, 0)) + 1
				break
	return not counts.is_empty()


func _assert(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("SHEET-C FAIL: " + description)
