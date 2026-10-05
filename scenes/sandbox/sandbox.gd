extends Control

const SAMPLE_LEVEL_CATALOG: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")

@onready var _barrage_area: BarrageArea = %BarrageArea
var _speech_selector: NormalSpeechSelector = NormalSpeechSelector.new()


func _ready() -> void:
	# 连接 Sandbox 的两个技术验证入口，并显示一条当前关普通话语。
	%ReloadButton.pressed.connect(_on_reload_button_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	_spawn_sample_barrage()


func _spawn_sample_barrage() -> void:
	# Sandbox 是当前游戏入口；用正式关卡与选择器管线生成一条可见样例。
	var run_state: LevelRunState = LevelRunState.new(SAMPLE_LEVEL_CATALOG)
	var current_level: LevelProfile = run_state.get_current_level_profile()
	if current_level == null:
		push_error("Sandbox: 当前没有普通关卡配置。")
		return
	var speech: LevelSpeech = _speech_selector.select_next_normal_speech(current_level)
	if speech == null:
		push_error("Sandbox: 当前关没有可生成的普通话语。")
		return
	var barrage_view: BarrageView = _barrage_area.spawn_normal_barrage(current_level, speech)
	if barrage_view == null:
		push_error("Sandbox: 单条普通弹幕生成失败。")


func _on_reload_button_pressed() -> void:
	# 通过 SceneRouter 重新加载当前 Sandbox 场景。
	var error: Error = SceneRouter.reload_current_scene()
	if error != OK:
		push_error("Sandbox: 当前场景重新加载失败，Error: %s" % error_string(error))


func _on_main_menu_button_pressed() -> void:
	# 通过 SceneRouter 返回主菜单。
	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		push_error("Sandbox: 无法返回 MainMenu，Error: %s" % error_string(error))
