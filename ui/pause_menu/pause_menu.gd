extends CanvasLayer

## 暂停菜单 V2：美术全屏底图 + 纯文字入口，内页以文字控制真实音量。
signal restart_requested
signal paused_changed(paused: bool)

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
var _display_settings_button: Button
var _main_menu_button: Button
var _reload_button: Button
var _volume_values: Dictionary = {}

@onready var _overlay: Control = %Overlay
@onready var _main_page: Control = %MainPage
@onready var _main_actions: VBoxContainer = %PauseActions
@onready var _audio_page: Control = %AudioPage
@onready var _audio_actions: VBoxContainer = %AudioActions
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	# 场景层级90高于结算/历史层30、低于加载层100；暂停时继续处理输入和按钮。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_main_page()
	_build_audio_page()
	_settings_panel.closed.connect(_on_display_settings_closed)
	_main_page.show()
	_audio_page.hide()
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


func _build_audio_page() -> void:
	_audio_actions.add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "音量设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", MENU_FONT)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.custom_minimum_size = Vector2(0, 92)
	_audio_actions.add_child(title)
	for info in [
		["master", "主音量"],
		["music", "音乐音量"],
		["sfx", "音效音量"],
		["ui", "界面音量"]
	]:
		_add_volume_row(String(info[0]), String(info[1]))
	_display_settings_button = _make_text_button("更多设置", COLOR_GOLD, 36, 65, _open_display_settings)
	_audio_actions.add_child(_display_settings_button)
	_audio_actions.add_child(_make_text_button("返回", COLOR_EXIT, 49, 95, _leave_audio_page))


# 保留新版美术音量内页，并复用设置面板提供全屏和光效档位，避免丢失已验收功能。
func _open_display_settings() -> void:
	_audio_page.hide()
	_settings_panel.open()


func _on_display_settings_closed() -> void:
	_refresh_volumes()
	_audio_page.show()
	_display_settings_button.grab_focus()


func _add_volume_row(key: String, display_name: String) -> void:
	var row := HBoxContainer.new()
	row.name = key + "_volume_row"
	row.custom_minimum_size = Vector2(0, 78)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	_audio_actions.add_child(row)

	var heading := Label.new()
	heading.text = display_name
	heading.custom_minimum_size = Vector2(224, 0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", MENU_FONT)
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", COLOR_GOLD)
	row.add_child(heading)

	var minus := _make_text_button("－", COLOR_GOLD, 40, 75, _change_volume.bind(key, -VOLUME_STEP))
	minus.custom_minimum_size.x = 63
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)

	var value := Label.new()
	value.name = key + "_volume_value"
	value.custom_minimum_size = Vector2(130, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", MENU_FONT)
	value.add_theme_font_size_override("font_size", 35)
	value.add_theme_color_override("font_color", Color("#f3d89c"))
	row.add_child(value)
	_volume_values[key] = value

	var plus := _make_text_button("＋", COLOR_GOLD, 40, 75, _change_volume.bind(key, VOLUME_STEP))
	plus.custom_minimum_size.x = 63
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)


func _read_volume(key: String) -> float:
	match key:
		"master": return SettingsManager.master_volume
		"music": return SettingsManager.music_volume
		"sfx": return SettingsManager.sfx_volume
		"ui": return SettingsManager.ui_volume
	return 0.0


func _change_volume(key: String, delta: float) -> void:
	# 四条 Audio Bus 使用已有 SettingsManager；步进 5% 即时生效。
	var next_value := clampf(roundf((_read_volume(key) + delta) / VOLUME_STEP) * VOLUME_STEP, 0.0, 1.0)
	match key:
		"master": SettingsManager.set_master_volume(next_value)
		"music": SettingsManager.set_music_volume(next_value)
		"sfx": SettingsManager.set_sfx_volume(next_value)
		"ui": SettingsManager.set_ui_volume(next_value)
	_refresh_volumes()


func _refresh_volumes() -> void:
	for key in _volume_values:
		(_volume_values[key] as Label).text = "%d%%" % roundi(_read_volume(key) * 100.0)


func _open_audio_page() -> void:
	_feedback_label.text = ""
	_refresh_volumes()
	_main_page.hide()
	_audio_page.show()
	# 首行减号可键盘聚焦。
	(_audio_actions.get_child(1) as HBoxContainer).get_child(1).grab_focus()


func _leave_audio_page() -> void:
	# 和旧 SettingsPanel 一样：修改立即生效，离开页面时持久化配置。
	var result: Error = SettingsManager.save_settings()
	_audio_page.hide()
	_main_page.show()
	if result != OK:
		_feedback_label.text = "音量设置保存失败，请重试"
	else:
		_feedback_label.text = ""
	_settings_button.grab_focus()


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
	if get_tree().paused:
		if _settings_panel.visible:
			_settings_panel.close()
		elif _audio_page.visible:
			_leave_audio_page()
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
	# 通关片尾可暂停和设置，但不能通过返回按钮跳过片尾。
	_main_menu_button.disabled = SceneRouter.is_ending_performance_active()
	_feedback_label.text = ""
	_settings_panel.hide()
	_audio_page.hide()
	_main_page.show()
	_overlay.show()
	get_tree().paused = true
	paused_changed.emit(true)
	_resume_button.grab_focus()


func resume_game() -> void:
	if _settings_panel.visible:
		_settings_panel.close()
	if _audio_page.visible:
		# 兼容来自外部系统的直接恢复调用。
		SettingsManager.save_settings()
		_audio_page.hide()
	_main_page.show()
	_overlay.hide()
	var was_paused := get_tree().paused
	get_tree().paused = false
	if was_paused:
		paused_changed.emit(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


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
