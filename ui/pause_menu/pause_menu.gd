extends CanvasLayer

## 暂停菜单：美术底图与统一滑块设置页，标题和战斗复用相同实例。
signal restart_requested
signal paused_changed(paused: bool)
signal settings_closed

const MENU_FONT: Font = preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
const COLOR_CONTINUE := Color("#64cf5c")
const COLOR_GOLD := Color("#dfad51")
const COLOR_EXIT := Color("#ef534e")
const COLOR_HINT := Color("#b4a482")
const VOLUME_STEP := 0.05

var _previous_focus: Control
var _restart_available := true
var _resume_button: Button
var _settings_button: Button
var _main_menu_button: Button
var _reload_button: Button
var _settings_only := false

@onready var _overlay: Control = %Overlay
@onready var _main_page: Control = %MainPage
@onready var _main_actions: VBoxContainer = %PauseActions
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	# 场景层级90高于结算/历史层30、低于加载层100；暂停时继续处理输入和按钮。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_main_page()
	_settings_panel.closed.connect(_on_settings_closed)
	_main_page.show()
	_overlay.hide()


func _make_text_button(text: String, color: Color, font_size: int, height: float, action: Callable) -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.28))
	button.add_theme_color_override("font_pressed_color", color.darkened(0.12))
	button.add_theme_color_override("font_focus_color", color.lightened(0.25))
	button.add_theme_color_override("font_disabled_color", COLOR_HINT.darkened(0.25))
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(action)
	return button


func _build_main_page() -> void:
	_main_actions.add_theme_constant_override("separation", 23)
	_resume_button = _make_text_button("继续游戏", COLOR_CONTINUE, 58, 87, resume_game)
	_main_actions.add_child(_resume_button)
	_main_actions.add_child(_make_text_button("保存进度", COLOR_GOLD, 48, 82, _save_completed_progress))
	_settings_button = _make_text_button("音量设置", COLOR_GOLD, 48, 82, _open_audio_page)
	_main_actions.add_child(_settings_button)
	_reload_button = _make_text_button("重新开始", COLOR_GOLD, 48, 82, _on_reload_button_pressed)
	_main_actions.add_child(_reload_button)
	_main_menu_button = _make_text_button("返回主菜单", COLOR_EXIT, 53, 92, _on_main_menu_button_pressed)
	_main_actions.add_child(_main_menu_button)
	set_restart_available(_restart_available)


# 标题和暂停入口共享唯一美术滑块页，不再叠加“更多设置”二级旧面板。
func _open_audio_page() -> void:
	_feedback_label.text = ""
	_main_page.hide()
	$Overlay/ArtworkBackground.hide()
	_settings_panel.open()


func _on_settings_closed() -> void:
	$Overlay/ArtworkBackground.show()
	if _settings_only:
		resume_game()
	else:
		_main_page.show()
		_settings_button.grab_focus()

# 标题选项直接显示同一音量内页，以遮罩和隐藏标题按钮阻止穿透，不暂停音乐。
func open_settings() -> void:
	if get_tree().paused or SceneRouter.is_transitioning():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_settings_only = true
	_overlay.show()
	_open_audio_page()


func _save_completed_progress() -> void:
	# 只序列化已提交的关卡进度；不会写入当前战斗的弹幕、PK、Tier 和场面。
	if SaveManager.data == null:
		_feedback_label.text = "尚无可保存的周目进度"
		return
	var result: Error = SaveManager.save_game()
	if result == OK:
		_feedback_label.text = "已保存完成关卡的进度，下次从休息房间继续"
	else:
		_feedback_label.text = "保存失败：%s" % error_string(result)


func _input(event: InputEvent) -> void:
	# 所有暂停输入统一使用 Input Map 的 pause Action，不硬编码具体键位。
	if SceneRouter.is_transitioning() or not event.is_action_pressed("pause") or event.is_echo():
		return
	if _settings_only:
		if _settings_panel.visible:
			_settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		if _settings_panel.visible:
			_settings_panel.close()
		else:
			resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	# 打开暂停界面、暂停 SceneTree，并把焦点交给继续按钮。
	if get_tree().paused or SceneRouter.is_transitioning():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_settings_only = false
	# 通关片尾可暂停和设置，但不能通过返回按钮跳过片尾。
	_main_menu_button.disabled = SceneRouter.is_ending_performance_active()
	_feedback_label.text = ""
	_settings_panel.hide()
	_main_page.show()
	_overlay.show()
	get_tree().paused = true
	paused_changed.emit(true)
	_resume_button.grab_focus()


func resume_game() -> void:
	var was_settings_only := _settings_only
	_settings_only = false
	if _settings_panel.visible:
		_settings_panel.close()
	_main_page.show()
	_overlay.hide()
	var was_paused := get_tree().paused
	get_tree().paused = false
	if was_paused:
		paused_changed.emit(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	if was_settings_only:
		settings_closed.emit()


## 休息房间只允许继续、存档、音量、返回；重开仅在战斗阶段显示。
func set_restart_available(available: bool) -> void:
	_restart_available = available
	if is_instance_valid(_reload_button):
		_reload_button.visible = available
		_reload_button.disabled = not available


func _on_main_menu_button_pressed() -> void:
	if SceneRouter.is_ending_performance_active():
		return
	# 切换顶层场景前先解除暂停；失败时恢复可操作的暂停状态。
	# 统一发出恢复事实，避免音乐/漫画仍保留暂停标记而带入下一页。
	resume_game()
	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		pause_game()
		_feedback_label.text = "返回主菜单失败：%s" % error_string(error)
		push_error("PauseMenu: goto_main_menu failed: %s" % error_string(error))


func _on_reload_button_pressed() -> void:
	resume_game()
	restart_requested.emit()
