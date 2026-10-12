## 复用正式 Sandbox Scene 与 BattleHud，演示 PA-20 的真实 Resource 数据入口。
extends Control

const ASSETS: PresentationAssetConfig = preload("res://data/shared/presentation_asset_config.tres")
const FIRST_LEVEL: LevelProfile = preload("res://data/level_configuration/level_001.tres")
const SECOND_LEVEL: LevelProfile = preload("res://data/level_configuration/level_002.tres")
const PREVIEW_DIR: String = "res://docs/Shared/PresentationAssets/previews"

@onready var _battle_hud: Control = $BattleHud

var _save_data: SaveData
var _first_profile: LevelProfile
var _second_profile: LevelProfile
var _capture_resolution: Vector2i = Vector2i.ZERO


# 使用 Godot 窗口实际请求尺寸；无边框只用于让两种验收分辨率精确落到客户区。
func _ready() -> void:
	_capture_resolution = Vector2i(1280, 720) if get_window().size.x < 1600 else Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().min_size = Vector2i(800, 450)
		get_window().size = _capture_resolution
	_save_data = SaveData.new()
	_save_data.streamer_name = "小满"
	_save_data.fan_group_name = "月光邮局"
	_first_profile = _make_test_profile(
		FIRST_LEVEL, "kiwi", "Kiwi", "星尘旅团", "res://assets/characters/opponents/kiwi/kiwi_idle.png",
		"res://assets/environment/live/kiwi/background.png"
	)
	_second_profile = _make_test_profile(
		SECOND_LEVEL, "alien", "银河主播", "星际信号站", "res://assets/characters/opponents/alien/alien_idle.png",
		"res://assets/environment/live/alien/background.png"
	)
	_apply_level_context(_first_profile, "开播 · 第一关")
	call_deferred("_run_preview_sequence")


# 复制当前真实关卡 Resource，只在预览进程内覆盖展示文本与角色图。
func _make_test_profile(
		base_profile: LevelProfile, streamer_id: String, streamer_name: String, fan_group_name: String,
		portrait_path: String, background_path: String
	) -> LevelProfile:
	var profile: LevelProfile = base_profile.duplicate(true) as LevelProfile
	profile.streamer_id = streamer_id
	profile.streamer_name = streamer_name
	profile.fan_group_name = fan_group_name
	profile.streamer_portrait = load(portrait_path) as Texture2D
	profile.streamer_live_background = load(background_path) as Texture2D
	# 该纹理留在 LevelProfile 供 LD-15；顶部仅由 fan_group_name 绘制。
	profile.fan_badge_texture = ASSETS.player_fan_badge
	return profile


# 每个上下文都从同一 SaveData / LevelProfile 字段重配正式 HUD 入口。
func _apply_level_context(profile: LevelProfile, state_label: String) -> void:
	_battle_hud.reset_for_attempt()
	_battle_hud.configure_streamers(_save_data.streamer_name, profile.streamer_name)
	_battle_hud.configure_fan_group_names(_save_data.fan_group_name, profile.fan_group_name)
	_battle_hud.configure_portrait_character(profile.streamer_id)
	_battle_hud.configure_streamer_assets(
		ASSETS.player_streamer_portrait, ASSETS.player_live_background, ASSETS.player_fan_badge,
		profile.streamer_portrait, profile.streamer_live_background, profile.fan_badge_texture
	)
	_battle_hud.refresh_pk(0.52, 1)
	_battle_hud.show_battle_state("PA-20 预览 · %s" % state_label)


# 按时间顺序展示开播、切关、长名与重开；图片由实际 Godot viewport 渲染。
func _run_preview_sequence() -> void:
	await _wait_for_presentation()
	await _capture_state("01_start")
	await get_tree().create_timer(1.2).timeout
	_apply_level_context(_second_profile, "切关 · 第二关")
	await _wait_for_presentation()
	await _capture_state("02_level_switch")
	await get_tree().create_timer(1.2).timeout
	_save_data.streamer_name = "夜航慢慢走的小满"
	_save_data.fan_group_name = "月光邮局守夜应援团"
	_second_profile.streamer_name = "银河深处的Kiwi主播"
	_second_profile.fan_group_name = "仓鼠星际信号观察团"
	_apply_level_context(_second_profile, "长名布局 · 第二关")
	await _wait_for_presentation()
	await _capture_state("03_long_names")
	await get_tree().create_timer(1.2).timeout
	_apply_level_context(_second_profile, "重开 · 保留当前周目团名")
	await _wait_for_presentation()
	await _capture_state("04_restart")
	await get_tree().create_timer(1.2).timeout
	print("PA20_DEMO_PASS resolution=%s player_group=%s opponent_group=%s" % [
		_capture_resolution, _save_data.fan_group_name, _second_profile.fan_group_name
	])
	get_tree().quit(0)


# 低分辨率运行只落盘长名与重开两张图，保持交付预览在 3～6 张范围内。
func _capture_state(state_id: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var image_size: Vector2i = image.get_size()
	if image_size.x <= 1400 and state_id not in ["03_long_names", "04_restart"]:
		return
	var resolution_id: String = "%dx%d" % [image_size.x, image_size.y]
	var file_path: String = "%s/pa20_fan_group_name_%s_%s.png" % [PREVIEW_DIR, resolution_id, state_id]
	var output_path: String = ProjectSettings.globalize_path(file_path)
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("PA20_CAPTURE_FAIL %s error=%d" % [state_id, save_error])
		get_tree().quit(1)
		return
	print("PA20_CAPTURE %s size=%s file=%s" % [state_id, image_size, file_path])


# 等待尺寸、动态字体与最后一帧绘制稳定后再取真实 viewport。
func _wait_for_presentation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
