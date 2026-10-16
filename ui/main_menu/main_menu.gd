extends Control

@onready var _menu_actions: VBoxContainer = %MenuActions
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
var _continue_button: Button


func _ready() -> void:
	# 有存档时提供独立继续入口，保留原开始按钮的新周目语义。
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "继续游戏"
	_continue_button.visible = SaveManager.has_save()
	_menu_actions.add_child(_continue_button)
	_menu_actions.move_child(_continue_button, 0)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	# 原菜单按钮点击消费已提前注册的正式声音，路由仍由原回调负责。
	for button: BaseButton in [%StartButton, %ReplayOpeningButton, %ReplayEndingButton, %SettingsButton, %QuitButton, _continue_button]:
		AudioManager.bind_ui_button(button)
	# 首次启动演出已由 Boot 处理，主菜单始终提供前后两部分回放。
	%ReplayOpeningButton.show()
	%ReplayEndingButton.show()
	# 此资源是开场P5/P6，正式Ending使用独立的结局页面和结果快照。
	%ReplayEndingButton.text = "回看开场后两幕"
	# 连接主菜单按钮与可复用设置面板。
	%StartButton.pressed.connect(_on_start_button_pressed)
	%ReplayOpeningButton.pressed.connect(_replay_comic.bind(&"opening"))
	%ReplayEndingButton.pressed.connect(_replay_comic.bind(&"ending"))
	_settings_button.pressed.connect(_on_settings_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	_settings_panel.closed.connect(_on_settings_panel_closed)
	%StartButton.grab_focus()
	if _continue_button.visible:
		_continue_button.grab_focus()
	for button: Node in _menu_actions.get_children():
		if button is Button:
			AudioManager.bind_ui_button(button, &"ui_confirm")


## 恢复已确认周目到房间；已完成终局则使用保存的只读显示快照。
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
		push_error("MainMenu: 继续游戏失败：%s" % error_string(error))


func _on_start_button_pressed() -> void:
	# 新建本周目数据后进入身份设置；Game 入口留给确认后的身份页面。
	SaveManager.new_game()
	var error: Error = SceneRouter.goto_identity_setup()
	if error != OK:
		push_error("MainMenu: 无法进入身份设置页，Error: %s" % error_string(error))


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

# 回看只调用漫画路由，不创建或修改周目。
func _replay_comic(kind: StringName) -> void:
	var error: Error = SceneRouter.goto_comic(kind)
	if error != OK:
		push_error("MainMenu: 无法播放漫画，Error: %s" % error_string(error))
