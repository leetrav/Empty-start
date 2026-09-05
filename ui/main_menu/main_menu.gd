extends Control

@onready var _menu_actions: VBoxContainer = %MenuActions
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	# 连接主菜单按钮与可复用设置面板。
	%StartButton.pressed.connect(_on_start_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	_settings_panel.closed.connect(_on_settings_panel_closed)
	%StartButton.grab_focus()


func _on_start_button_pressed() -> void:
	# 通过 SceneRouter 进入当前项目的游戏入口场景。
	var error: Error = SceneRouter.goto_game()
	if error != OK:
		push_error("MainMenu: 无法进入 Game，Error: %s" % error_string(error))


func _on_quit_button_pressed() -> void:
	# 退出行为由主菜单按钮明确触发。
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	# 隐藏主菜单操作区，再打开共享设置面板。
	_menu_actions.hide()
	_settings_panel.open()


func _on_settings_panel_closed() -> void:
	# 设置关闭后恢复主菜单操作区。
	_menu_actions.show()
	_settings_button.grab_focus()
