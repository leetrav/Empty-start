extends SceneTree

var _audio: Node
var _save: Node
var _router: Node
var _full_seen: bool = false
var _started_count: int = 0
var _start_count_before: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _music_changed(event_id: StringName) -> void:
	if event_id == &"music_ending_tendoh":
		_started_count += 1


# 消费真实Flow阶段，不伪造phase_changed或completed信号。
func _phase_changed(phase: StringName, _prompt: String, progress: float) -> void:
	if phase in [&"emphasis", &"completed"] and progress >= 1.0:
		_full_seen = true
		assert(_audio.get_music_event_id() == &"music_ending_tendoh")
	else:
		assert(_audio.get_music_event_id() != &"music_ending_tendoh")


func _divine_entered(_session: DivineDescentSession) -> void:
	current_scene.get_divine_descent_flow().phase_changed.connect(_phase_changed)


# 仅在隔离APPDATA准备已到末关的RAM夹具，不声称实际打通四关或提交奖励。
func _prepare_last_rest(with_history: bool) -> void:
	_save.new_game()
	assert(_save.confirm_opening_identity("结尾音乐测试", IdentityOptions.CARDS[0], "测试团", IdentityConfirmationState.new()) == OK)
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	_save.data.next_normal_level_order = 4
	for index in range(3):
		_save.data.completed_normal_level_ids.append(catalog.profiles[index].level_id)
	if with_history:
		for speech: LevelSpeech in catalog.profiles[0].get_normal_speech_pool():
			if speech.tendency_id in ["orthodox", "heretical", "absurd"]:
				_save.data.committed_normal_hit_history.append({
					"original_sentence_id": speech.original_sentence_id,
					"original_sentence_text": speech.text,
					"tendency": speech.tendency_id, "hit_count": 1,
					"first_committed_hit_order": 1,
				})
				break
		assert(not _save.data.committed_normal_hit_history.is_empty())
	assert(_router.goto_game() == OK)
	await process_frame
	await process_frame
	var game := current_scene
	game.divine_descent_entered.connect(_divine_entered)
	var rest := RestSession.new()
	assert(rest.open_result({"level_id": catalog.profiles[3].level_id, "result_kind": "pk_win_unbroken"}))
	game.get_contradiction_oracle_flow().rest_ready.emit(rest)
	await process_frame
	await process_frame
	assert(_audio.get_music_event_id() == &"music_rest_after_pk")
	_full_seen = false
	_start_count_before = _started_count
	game.get_rest_result_view().get_node("%ContinueButton").pressed.emit()


func _run() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	_audio = root.get_node("AudioManager")
	_save = root.get_node("SaveManager")
	_router = root.get_node("SceneRouter")
	_audio.music_changed.connect(_music_changed)
	await _prepare_last_rest(true)
	var game := current_scene
	var remaining: float = 65.0
	while not _full_seen and remaining > 0.0:
		await create_timer(0.05).timeout
		remaining -= 0.05
	assert(_full_seen)
	assert(_started_count == _start_count_before + 1)
	# 进度满后的真实强调期间暂停，音乐和演出应一起冻结。
	assert(is_instance_valid(game) and current_scene == game)
	var pause := game.get_node("PauseMenu")
	pause.pause_game()
	await create_timer(0.1).timeout
	var position: float = _audio.get_music_position()
	await create_timer(0.3).timeout
	assert(absf(_audio.get_music_position() - position) < 0.05)
	pause.resume_game()
	remaining = 5.0
	while current_scene == game and remaining > 0.0:
		await create_timer(0.05).timeout
		remaining -= 0.05
	assert(current_scene.scene_file_path.ends_with("ending_page.tscn"))
	assert(_audio.get_music_event_id() == &"music_ending_tendoh")
	assert(_audio.get_music_position() > position)
	assert(_started_count == _start_count_before + 1)
	var display: Dictionary = _save.data.ending_display_data.duplicate(true)
	assert(not display.is_empty())
	print("PASS 真实神降临进度满起曲/暂停/强调完成/结局同曲续播")
	assert(_router.goto_main_menu() == OK)
	await process_frame
	await create_timer(0.8).timeout
	assert(_audio.get_music_event_id() == &"")
	assert(_router.goto_saved_ending(display) == OK)
	await process_frame
	await process_frame
	assert(_audio.get_music_event_id() == &"music_ending_tendoh")
	assert(_router.goto_main_menu() == OK)
	await process_frame
	await create_timer(0.8).timeout
	await _prepare_last_rest(false)
	remaining = 3.0
	while not current_scene.scene_file_path.ends_with("ending_page.tscn") and remaining > 0.0:
		await create_timer(0.05).timeout
		remaining -= 0.05
	assert(current_scene.scene_file_path.ends_with("ending_page.tscn") and _full_seen)
	assert(_audio.get_music_event_id() == &"music_ending_tendoh")
	assert(_started_count == _start_count_before + 1)
	print("PASS 结局离开淡出/保存快照回看/空历史完成兜底")
	assert(_router.goto_main_menu() == OK)
	await process_frame
	await create_timer(0.8).timeout
	print("AU03_ENDING_MUSIC_PASS")
	quit(0)
