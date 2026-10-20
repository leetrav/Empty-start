class_name SettingsPanel
extends Control

signal closed

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SFXSlider
@onready var _ui_slider: HSlider = %UISlider
@onready var _fullscreen_check: CheckButton = %FullscreenCheck


func _ready() -> void:
	# 设置面板在任意上下文中都必须能操作，包含暂停状态。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_artwork_style()
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_ui_slider.value_changed.connect(_on_ui_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	%ResetButton.pressed.connect(_on_reset_button_pressed)
	%BackButton.pressed.connect(_on_back_button_pressed)
	hide()


func open() -> void:
	# 每次打开都从 SettingsManager 同步真实值，避免复用实例时显示旧状态。
	_sync_from_manager()
	show()
	_master_slider.grab_focus()


func close() -> void:
	# 关闭前保存当前设置，并通过信号让宿主恢复自己的界面。
	var error: Error = SettingsManager.save_settings()
	if error != OK:
		push_error("SettingsPanel: 保存设置失败，Error: %s" % error_string(error))
	hide()
	closed.emit()


func _sync_from_manager() -> void:
	# 初始化控件时抑制信号，避免同步过程重复写入 SettingsManager。
	_master_slider.set_value_no_signal(SettingsManager.master_volume)
	_music_slider.set_value_no_signal(SettingsManager.music_volume)
	_sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_ui_slider.set_value_no_signal(SettingsManager.ui_volume)
	_fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
	_refresh_fullscreen_text()
	_refresh_percentages()


# 复用暂停菜单底图和快乐字体，保留原生滑块/键盘/触屏及原设置接口。
func _apply_artwork_style() -> void:
	var style := Theme.new()
	style.default_font = preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
	style.default_font_size = 36
	style.set_color("font_color", "Label", Color("#dfad51"))
	theme = style
	$CenterContainer/PanelContainer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer
	content.add_theme_constant_override("separation", 18)
	content.get_node("SettingsTitle").add_theme_font_size_override("font_size", 54)
	content.get_node("SettingsTitle").custom_minimum_size.y = 90
	for info in [["Master", "主音量"], ["Music", "音乐音量"], ["SFX", "音效音量"], ["UI", "界面音量"]]:
		var key: String = info[0]
		var row: HBoxContainer = content.get_node(key + "Row")
		var label: Label = row.get_node(key + "Label")
		label.text = info[1]
		label.custom_minimum_size.x = 224
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var slider: HSlider = row.get_node(key + "Slider")
		slider.custom_minimum_size = Vector2(350, 78)
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color("#62502d")
		rail.set_corner_radius_all(4)
		rail.content_margin_top = 4
		rail.content_margin_bottom = 4
		var fill := rail.duplicate() as StyleBoxFlat
		fill.bg_color = Color("#dfad51")
		slider.add_theme_stylebox_override("slider", rail)
		for state in ["grabber_area", "grabber_area_highlight"]:
			slider.add_theme_stylebox_override(state, fill)
		var value := Label.new()
		value.name = "Percentage"
		value.custom_minimum_size.x = 100
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		slider.value_changed.connect(func(_value: float): _refresh_percentages())
	# 用清晰文字替代默认小图标；保留原生CheckButton的触屏和键盘切换。
	var empty_icon := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored"]:
		_fullscreen_check.add_theme_icon_override(icon_name, empty_icon)
	_fullscreen_check.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for button: BaseButton in [_fullscreen_check, %ResetButton, %BackButton]:
		button.custom_minimum_size.y = 78
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("#ef534e") if button == %BackButton else Color("#dfad51"))
		button.add_theme_color_override("font_hover_color", Color("#f3d89c"))
		button.add_theme_color_override("font_focus_color", Color("#f3d89c"))


func _refresh_fullscreen_text() -> void:
	_fullscreen_check.text = "全屏显示：" + ("开启" if SettingsManager.fullscreen else "关闭")


func _refresh_percentages() -> void:
	var content: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer
	for key: String in ["Master", "Music", "SFX", "UI"]:
		var slider: HSlider = content.get_node(key + "Row/" + key + "Slider")
		content.get_node(key + "Row/Percentage").text = "%d%%" % roundi(slider.value * 100.0)


func _on_master_volume_changed(value: float) -> void:
	# 音量值交由 SettingsManager 限制并立即应用。
	SettingsManager.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	# 音量值交由 SettingsManager 限制并立即应用。
	SettingsManager.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	# 音量值交由 SettingsManager 限制并立即应用。
	SettingsManager.set_sfx_volume(value)


func _on_ui_volume_changed(value: float) -> void:
	# 音量值交由 SettingsManager 限制并立即应用。
	SettingsManager.set_ui_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	# 全屏切换统一交给 SettingsManager，面板不直接操作窗口 API。
	SettingsManager.set_fullscreen(enabled)
	_refresh_fullscreen_text()


func _on_reset_button_pressed() -> void:
	# 复用 SettingsManager 的默认值、应用和保存逻辑，再刷新界面。
	SettingsManager.reset_to_defaults()
	_sync_from_manager()
	_master_slider.grab_focus()


func _on_back_button_pressed() -> void:
	# 返回动作只关闭面板，具体恢复哪个宿主界面由父级处理。
	close()
