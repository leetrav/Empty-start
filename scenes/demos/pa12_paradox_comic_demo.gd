extends Control

const SANDBOX_SCENE: PackedScene = preload("res://scenes/sandbox/sandbox.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://systems/presentation/paradox_comic_transition.tscn")
const ASSET_CONFIG: PresentationAssetConfig = preload("res://data/shared/presentation_asset_config.tres")
const SAMPLE_LEVEL: LevelProfile = preload("res://tests/fixtures/contradiction_break/test_cb_13_six_candidates_level.tres")
const NORMAL_SAMPLE_LEVEL: LevelProfile = preload("res://data/level_configuration/level_001.tres")
const WINDOW_CONFIG: ContradictionWindowConfig = preload("res://systems/contradiction_break/contradiction_window_config.tres")
const KIWI_PORTRAIT: Texture2D = preload("res://assets/characters/opponents/kiwi/kiwi_idle.png")
const PREVIEW_DIR: String = "user://pa12_previews"

var _sandbox: Control
var _hud: Control
var _area: BarrageArea
var _transition: ParadoxComicTransition
var _contradiction_system: ContradictionBreakSystem
var _demo_level: LevelProfile
var _normal_demo_level: LevelProfile
var _demo_window_config: ContradictionWindowConfig
var _capture_mode: bool = false
var _capture_720: bool = false
var _window_started: bool = false


# 读取复播模式并按目标尺寸启动独立预览。
func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_capture_mode = arguments.has("--capture-pa12") or arguments.has("--capture-pa12-720")
	_capture_720 = arguments.has("--capture-pa12-720")
	if _capture_mode:
		_set_capture_window_size(Vector2i(1280, 720) if _capture_720 else Vector2i(1920, 1080))
	call_deferred("_setup_demo")


# 复用正式 Sandbox HUD 与生成视图，不运行 Sandbox 周目流程。
func _setup_demo() -> void:
	# 重用 Sandbox 的实际左右主播、中央 1024px 战斗区与正式视图，不启动周目业务流程。
	_sandbox = SANDBOX_SCENE.instantiate() as Control
	_sandbox.set_script(null)
	_sandbox.name = "ParadoxPreviewSandbox"
	var attack_input: Node = _sandbox.get_node_or_null("AttackChargeInput")
	if attack_input != null:
		attack_input.set_script(null)
	add_child(_sandbox)
	move_child(_sandbox, 0)
	_sandbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame

	_hud = _sandbox.get_node("BattleHud") as Control
	_area = _sandbox.get_node("BattleHud/BattleArea/BarrageArea") as BarrageArea
	_hud.call("configure_streamers", "仓鼠主播", "Kiwi")
	_hud.call("configure_streamer_assets",
		ASSET_CONFIG.player_streamer_portrait,
		ASSET_CONFIG.player_live_background,
		ASSET_CONFIG.player_fan_badge,
		KIWI_PORTRAIT,
		null,
		null
	)
	_hud.call("refresh_pk", 0.98, 5)
	_hud.call("show_battle_state", "普通战斗 · PK 即将满值")
	var reticle: AimReticle = _sandbox.get_node("BattleHud/AimReticle") as AimReticle
	reticle.set_process_input(false)
	reticle.restore_mouse_aim(Vector2(960.0, 560.0))

	_demo_level = SAMPLE_LEVEL.duplicate(true) as LevelProfile
	# 仅为演示注入预览速度和生成节奏；TEST_ONLY fixture 与正式关卡数据保持只读。
	_demo_level.base_move_speed_pixels_per_second = 58.0
	_normal_demo_level = NORMAL_SAMPLE_LEVEL.duplicate(true) as LevelProfile
	_normal_demo_level.base_move_speed_pixels_per_second = 58.0
	_normal_demo_level.base_batch_count = 3
	_normal_demo_level.base_spawn_interval_seconds = 0.35
	_normal_demo_level.normal_barrage_screen_cap = 6
	_demo_window_config = WINDOW_CONFIG.duplicate(true) as ContradictionWindowConfig
	_contradiction_system = ContradictionBreakSystem.new()
	_contradiction_system.name = "PreviewContradictionState"
	add_child(_contradiction_system)
	await get_tree().process_frame
	if not _contradiction_system.load_level_content(_demo_level):
		push_error("PA12_DEMO_LEVEL_LOAD_FAILED")
		get_tree().quit(2)
		return
	if not _area.start_normal_generation(_normal_demo_level):
		push_error("PA12_DEMO_NORMAL_GENERATION_FAILED")
		get_tree().quit(4)
		return

	_transition = TRANSITION_SCENE.instantiate() as ParadoxComicTransition
	_area.add_child(_transition)
	_transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition.transition_finished.connect(_on_transition_finished)
	if _capture_mode:
		call_deferred("_capture_sequence")
	else:
		call_deferred("_play_demo_after_normal_battle")


# 窗口启动后展示 CB 真实倒计时与剩余发射机会。
func _process(_delta: float) -> void:
	if _window_started and _contradiction_system != null:
		_hud.call("show_battle_state", "矛盾击破：%.1f 秒 · 剩余 %d 发" % [
			_contradiction_system.get_remaining_seconds(),
			_contradiction_system.get_remaining_shots(),
		])


# R 重播转场，1/2 预览两种结果漫画字。
func _unhandled_key_input(event: InputEvent) -> void:
	if _capture_mode or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_transition.reset_for_attempt()
			if _window_started:
				_transition.play_transition()
			else:
				_begin_transition()
		KEY_1:
			if not _window_started:
				return
			_transition.play_result_feedback(true)
		KEY_2:
			if not _window_started:
				return
			_transition.play_result_feedback(false)
		_:
			return
	get_viewport().set_input_as_handled()


# 完成揭幕后才启动正式候选生成和 CB 窗口。
func _on_transition_finished() -> void:
	_hud.call("set_paradox_stage_active", true, 5)
	if not _window_started:
		var candidates: Array[LevelContradiction] = _contradiction_system.get_fixed_paradox_candidates()
		if candidates.size() != ContradictionWindowConfig.PARADOX_CANDIDATE_COUNT:
			push_error("PA12_DEMO_CANDIDATE_COUNT=%d" % candidates.size())
			return
		var true_lines: Array[LevelContradiction] = [candidates[0]]
		var false_lines: Array[LevelContradiction] = []
		for index: int in range(1, candidates.size()):
			false_lines.append(candidates[index])
		if not _area.start_contradiction_generation(_demo_level, true_lines, false_lines, _demo_window_config):
			push_error("PA12_DEMO_GENERATION_FAILED")
			return
		_hud.call("show_battle_state", "矛盾击破 · 窗口从画面完全揭开后开始")
		# 演示通过 CB 的真实窗口入口验证计时从揭幕完成后开始。
		_window_started = _contradiction_system.start_window(_demo_window_config)
		if not _window_started:
			push_error("PA12_DEMO_WINDOW_START_FAILED")
	else:
		_hud.call("show_battle_state", "矛盾击破 · 视觉转场已复播")


# 截图验收使用精确 16:9 无边框窗口。
func _set_capture_window_size(target_size: Vector2i) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(target_size)


# 让普通弹幕先实际出现，再进入漫画转场。
func _play_demo_after_normal_battle() -> void:
	await get_tree().create_timer(0.65).timeout
	_begin_transition()


# 清理普通弹幕后从空战场开始转场。
func _begin_transition() -> void:
	# 普通弹幕在静音镜头前由 BarrageArea 清理，六句候选留到转场完成后生成。
	_area.stop_normal_generation()
	_area.clear_barrages()
	_transition.play_transition()


# 顺序截取普通战斗、转场、揭幕及成败结果的真实视口帧。
func _capture_sequence() -> void:
	var output_directory: String = ProjectSettings.globalize_path(PREVIEW_DIR)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		push_error("PA12_CAPTURE_DIRECTORY_ERROR")
		get_tree().quit(5)
		return

	await get_tree().create_timer(0.38).timeout
	if not _capture_720:
		await _capture_frame("pa12_00_normal_battle")
	_begin_transition()
	if _capture_720:
		await _transition.transition_finished
		await get_tree().create_timer(0.08).timeout
		await _capture_frame("pa12_720_battle_revealed")
		_transition.play_result_feedback(true)
		await get_tree().create_timer(0.22).timeout
		await _capture_frame("pa12_720_breakthrough")
		await _transition.result_feedback_finished
		print("PA12_CAPTURE_DONE size=1280x720; transition_finished=1; window_started=%s" % _window_started)
		get_tree().quit(0)
		return

	await get_tree().create_timer(0.22).timeout
	await _capture_frame("pa12_01_silence")
	await get_tree().create_timer(1.08).timeout
	await _capture_frame("pa12_02_crossflash")
	await get_tree().create_timer(1.65).timeout
	await _capture_frame("pa12_03_torn_opening")
	await _transition.transition_finished
	await get_tree().create_timer(0.08).timeout
	await _capture_frame("pa12_04_battle_revealed")

	_transition.play_result_feedback(true)
	print("PA12_RESULT_TEXT success=%s" % str(_transition.get_node("Title").text))
	await get_tree().create_timer(0.22).timeout
	await _capture_frame("pa12_05_breakthrough")
	await _transition.result_feedback_finished
	await get_tree().create_timer(0.12).timeout
	_transition.play_result_feedback(false)
	print("PA12_RESULT_TEXT unbroken=%s" % str(_transition.get_node("Title").text))
	await get_tree().create_timer(0.22).timeout
	await _capture_frame("pa12_06_not_broken")
	await _transition.result_feedback_finished
	print("PA12_CAPTURE_DONE frames=7; transition_finished=1; window_started=%s; outcomes=breakthrough,not_broken" % _window_started)
	get_tree().quit(0)


# 直接保存当前 Godot GPU 视口帧，不后处理画面。
func _capture_frame(file_stem: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var resolution_tag: String = "1280" if _capture_720 else "1920"
	var filename: String = file_stem + "_" + resolution_tag + ".png"
	var path: String = ProjectSettings.globalize_path(PREVIEW_DIR.path_join(filename))
	var error: Error = screenshot.save_png(path)
	print("PA12_SCREEN %s saved=%d size=%s" % [filename, error, screenshot.get_size()])
	var expected_size: Vector2i = Vector2i(1280, 720) if _capture_720 else Vector2i(1920, 1080)
	if error != OK or screenshot.get_size() != expected_size:
		push_error("PA12_CAPTURE_FAILED %s expected=%s actual=%s error=%d" % [filename, expected_size, screenshot.get_size(), error])
		get_tree().quit(6)
