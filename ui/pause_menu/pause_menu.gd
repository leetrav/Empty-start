extends CanvasLayer

## UI 发出重开请求；本场清理与初始化由战斗场景负责。
signal restart_requested

@onready var _overlay: Control = %Overlay
@onready var _pause_actions: VBoxContainer = %PauseActions
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	# PauseMenu 必须在暂停状态下继续处理输入和按钮。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.hide()
	_settings_panel.hide()
	_resume_button.pressed.connect(resume_game)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	%ReloadButton.pressed.connect(_on_reload_button_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	_settings_panel.closed.connect(_on_settings_panel_closed)


func _unhandled_input(event: InputEvent) -> void:
	# 所有暂停输入统一使用 Input Map 的 pause Action，不硬编码具体键位。
	if not event.is_action_pressed("pause"):
		return

	if _settings_panel.visible:
		# 设置打开时 Escape 只关闭设置，保持游戏暂停。
		_settings_panel.close()
	else:
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	# 打开暂停界面、暂停 SceneTree，并把焦点交给继续按钮。
	if get_tree().paused:
		return

	_pause_actions.show()
	_overlay.show()
	get_tree().paused = true
	_resume_button.grab_focus()


func resume_game() -> void:
	# 关闭设置和暂停遮罩，再恢复游戏处理。
	_settings_panel.close()
	_overlay.hide()
	get_tree().paused = false


func _on_settings_button_pressed() -> void:
	# 设置面板在暂停期间打开，暂停状态保持不变。
	_pause_actions.hide()
	_settings_panel.open()


func _on_settings_panel_closed() -> void:
	# 设置关闭后恢复暂停菜单主按钮区域，仍然保持暂停。
	if _overlay.visible and get_tree().paused:
		_pause_actions.show()
		_settings_button.grab_focus()


func _on_main_menu_button_pressed() -> void:
	# 切换顶层场景前先解除暂停；失败时恢复可操作的暂停状态。
	_settings_panel.close()
	get_tree().paused = false

	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		get_tree().paused = true
		_overlay.show()
		_pause_actions.show()
		push_error("PauseMenu: 返回 MainMenu 失败，Error: %s" % error_string(error))


func _on_reload_button_pressed() -> void:
	# 先恢复场景处理，交给战斗场景执行本关重开，避免复制系统清理逻辑。
	resume_game()
	restart_requested.emit()
