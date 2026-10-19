extends Control

@onready var _canvas: Control = $CoverCanvas
@onready var _menu_actions: Control = %MenuActions
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _replays: Control = %ReplayActions
var _title_time: float = 0.0
var _titles: Array[Control] = []
var _title_origins: Array[Vector2] = []

# 主菜单组合既有路由与纯文字表现，不新增存档或音频服务。
func _ready() -> void:
	_continue_button.disabled = not SaveManager.has_save()
	_continue_button.call("refresh_state")
	_continue_button.tooltip_text = "" if not _continue_button.disabled else "暂无存档，请先开始游戏"
	_continue_button.pressed.connect(_on_continue_button_pressed)
	%StartButton.pressed.connect(_on_start_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	%ReplayToggleButton.pressed.connect(_toggle_replays)
	%ReplayFullOpeningButton.pressed.connect(_replay_comic.bind(&"intro"))
	%ReplayOpeningButton.pressed.connect(_replay_comic.bind(&"opening"))
	%ReplayEndingButton.pressed.connect(_replay_comic.bind(&"ending"))
	%ReplayBackButton.pressed.connect(_close_replays)
	_settings_panel.closed.connect(_on_settings_panel_closed)
	for group: Control in [_menu_actions, _replays]:
		for child: Node in group.get_children():
			if child is Button:
				AudioManager.bind_ui_button(child)
	for title: Control in [$CoverCanvas/Titles/Bo, $CoverCanvas/Titles/Lai, $CoverCanvas/Titles/Shu]:
		_titles.append(title)
		_title_origins.append(title.position)
	resized.connect(_fit_cover)
	_fit_cover()

# 完整画布等比适配，非16:9窗口留边而不裁剪菜单与标题。
func _fit_cover() -> void:
	var factor: float = minf(size.x / 1920.0, size.y / 1080.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5

# 标题错开相位轻微浮动，保留原背景和仓鼠构图。
func _process(delta: float) -> void:
	_title_time += delta
	for index: int in range(_titles.size()):
		var phase := _title_time * 1.1 + float(index) * 1.7
		_titles[index].position = _title_origins[index] + Vector2(sin(phase * 0.7) * 2.0, sin(phase) * 4.0)

# 原存档只读后交给原路由，不重复奖励；失败时恢复入口。
func _on_continue_button_pressed() -> void:
	_continue_button.disabled = true
	var error := SaveManager.load_game()
	if error == OK:
		if not SaveManager.data.ending_display_data.is_empty():
			error = SceneRouter.goto_saved_ending(SaveManager.data.ending_display_data)
		elif not SaveManager.data.identity_id.is_empty():
			error = SceneRouter.goto_opening_room()
		else:
			error = SceneRouter.goto_identity_setup()
	if error != OK:
		_continue_button.disabled = false
		push_error("MainMenu: 载入游戏失败：%s" % error_string(error))

func _on_start_button_pressed() -> void:
	# 开始新周目沿用现有身份创建流程。
	SaveManager.new_game()
	var error: Error = SceneRouter.goto_identity_setup()
	if error != OK:
		push_error("MainMenu: 无法进入身份设置：%s" % error_string(error))

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	_menu_actions.hide()
	_replays.hide()
	_settings_panel.open()

func _on_settings_panel_closed() -> void:
	_menu_actions.show()
	_settings_button.grab_focus()

# 回看集中到次级菜单，保留原路由及不改周目的语义。
func _toggle_replays() -> void:
	_menu_actions.hide()
	_replays.show()
	%ReplayFullOpeningButton.grab_focus()

func _close_replays() -> void:
	_replays.hide()
	_menu_actions.show()
	%ReplayToggleButton.grab_focus()

func _replay_comic(kind: StringName) -> void:
	var error: Error = SceneRouter.goto_comic(kind)
	if error != OK:
		push_error("MainMenu: 无法播放漫画：%s" % error_string(error))
