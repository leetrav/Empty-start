extends CanvasLayer

## UI 发出重开请求；本场清理与初始化由战斗场景负责。
signal restart_requested
## 根场景只据此取消指针捕获，暂停计时仍由 SceneTree 统一处理。
signal paused_changed(paused: bool)
var _previous_focus: Control

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


func _input(event: InputEvent) -> void:
	# 所有暂停输入统一使用 Input Map 的 pause Action，不硬编码具体键位。
	if SceneRouter.is_transitioning() or not event.is_action_pressed("pause") or event.is_echo():
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
	if get_tree().paused or SceneRouter.is_transitioning():
		return

	_previous_focus = get_viewport().gui_get_focus_owner()
	# 通关片尾可暂停和设置，但不能通过返回按钮跳过片尾。
	%MainMenuButton.disabled = SceneRouter.is_ending_performance_active()
	_pause_actions.show()
	_overlay.show()
	get_tree().paused = true
	paused_changed.emit(true)
	_resume_button.grab_focus()


func resume_game() -> void:
	# 关闭设置和暂停遮罩，再恢复游戏处理。
	_settings_panel.close()
	_overlay.hide()
	var was_paused := get_tree().paused
	get_tree().paused = false
	if was_paused:
		paused_changed.emit(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


## 房间与结果页只提供继续、设置和返回；只有普通战斗允许重开。
func set_restart_available(available: bool) -> void:
	%ReloadButton.visible = available
	%ReloadButton.disabled = not available


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
	if SceneRouter.is_ending_performance_active():
		return
	# 切换顶层场景前先解除暂停；失败时恢复可操作的暂停状态。
	# 统一发出恢复事实，避免音乐/漫画仍保留暂停标记而带入下一页。
	resume_game()
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
