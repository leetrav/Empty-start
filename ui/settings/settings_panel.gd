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


func _on_reset_button_pressed() -> void:
	# 复用 SettingsManager 的默认值、应用和保存逻辑，再刷新界面。
	SettingsManager.reset_to_defaults()
	_sync_from_manager()
	_master_slider.grab_focus()


func _on_back_button_pressed() -> void:
	# 返回动作只关闭面板，具体恢复哪个宿主界面由父级处理。
	close()
