extends Node

const SETTINGS_FILE_PATH: String = "user://settings.cfg"

const AUDIO_SECTION: String = "audio"
const DISPLAY_SECTION: String = "display"

const MASTER_VOLUME_KEY: String = "master_volume"
const MUSIC_VOLUME_KEY: String = "music_volume"
const SFX_VOLUME_KEY: String = "sfx_volume"
const UI_VOLUME_KEY: String = "ui_volume"
const FULLSCREEN_KEY: String = "fullscreen"

const MASTER_BUS_NAME: StringName = &"Master"
const MUSIC_BUS_NAME: StringName = &"Music"
const SFX_BUS_NAME: StringName = &"SFX"
const UI_BUS_NAME: StringName = &"UI"

const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0
const DEFAULT_UI_VOLUME: float = 1.0
const DEFAULT_FULLSCREEN: bool = false

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var ui_volume: float = DEFAULT_UI_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN

var _config: ConfigFile = ConfigFile.new()
var _settings_need_save: bool = false


func _ready() -> void:
	# 启动时读取配置、应用设置，并为首次启动创建配置文件。
	load_settings()
	apply_settings()
	if _settings_need_save:
		var save_error: Error = save_settings()
		if save_error != OK:
			return


func load_settings() -> void:
	# 读取五项设置；文件或字段异常时仅回退对应默认值。
	_config = ConfigFile.new()
	_set_default_values()
	_settings_need_save = false

	var load_error: Error = _config.load(SETTINGS_FILE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		_settings_need_save = true
		return
	if load_error != OK:
		push_warning("SettingsManager: settings file could not be loaded; using defaults.")
		_settings_need_save = true
		return

	master_volume = _read_volume_setting(MASTER_VOLUME_KEY, DEFAULT_MASTER_VOLUME)
	music_volume = _read_volume_setting(MUSIC_VOLUME_KEY, DEFAULT_MUSIC_VOLUME)
	sfx_volume = _read_volume_setting(SFX_VOLUME_KEY, DEFAULT_SFX_VOLUME)
	ui_volume = _read_volume_setting(UI_VOLUME_KEY, DEFAULT_UI_VOLUME)
	fullscreen = _read_fullscreen_setting()


func save_settings() -> Error:
	# 将当前运行时设置写入 user://settings.cfg，并回传保存错误。
	_config.set_value(AUDIO_SECTION, MASTER_VOLUME_KEY, master_volume)
	_config.set_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, music_volume)
	_config.set_value(AUDIO_SECTION, SFX_VOLUME_KEY, sfx_volume)
	_config.set_value(AUDIO_SECTION, UI_VOLUME_KEY, ui_volume)
	_config.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, fullscreen)

	var save_error: Error = _config.save(SETTINGS_FILE_PATH)
	if save_error != OK:
		push_error("SettingsManager: failed to save settings.cfg: %s" % error_string(save_error))
		return save_error

	_settings_need_save = false
	return OK


func apply_settings() -> void:
	# 将当前五项设置应用到音频 Bus 和窗口模式。
	_apply_bus_volume(MASTER_BUS_NAME, master_volume)
	_apply_bus_volume(MUSIC_BUS_NAME, music_volume)
	_apply_bus_volume(SFX_BUS_NAME, sfx_volume)
	_apply_bus_volume(UI_BUS_NAME, ui_volume)
	_apply_fullscreen()


func reset_to_defaults() -> void:
	# 恢复所有默认值，立即应用并同步写入配置文件。
	_set_default_values()
	apply_settings()
	var save_error: Error = save_settings()
	if save_error != OK:
		return


func set_master_volume(value: float) -> void:
	# 限制主音量范围并立即应用到 Master Bus。
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MASTER_BUS_NAME, master_volume)


func set_music_volume(value: float) -> void:
	# 限制音乐音量范围并立即应用到 Music Bus。
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MUSIC_BUS_NAME, music_volume)


func set_sfx_volume(value: float) -> void:
	# 限制音效音量范围并立即应用到 SFX Bus。
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS_NAME, sfx_volume)


func set_ui_volume(value: float) -> void:
	# 限制 UI 音效音量范围并立即应用到 UI Bus。
	ui_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(UI_BUS_NAME, ui_volume)


func set_fullscreen(enabled: bool) -> void:
	# 更新全屏状态并立即切换窗口模式。
	fullscreen = enabled
	_apply_fullscreen()


func _set_default_values() -> void:
	# 集中设置五项运行时默认值，避免默认值散落在读取和重置逻辑中。
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	ui_volume = DEFAULT_UI_VOLUME
	fullscreen = DEFAULT_FULLSCREEN


func _read_volume_setting(key: String, default_value: float) -> float:
	# 读取并校验音量字段，缺失、类型错误和越界值回退默认值。
	if not _config.has_section_key(AUDIO_SECTION, key):
		_settings_need_save = true
		return default_value

	var raw_value: Variant = _config.get_value(AUDIO_SECTION, key, default_value)
	if raw_value is int or raw_value is float:
		var numeric_value: float = float(raw_value)
		if numeric_value >= 0.0 and numeric_value <= 1.0:
			return numeric_value

	push_warning("SettingsManager: audio setting '%s' is out of range; using default." % key)
	_settings_need_save = true
	return default_value

	push_warning("SettingsManager: invalid audio setting '%s'; using default." % key)
	_settings_need_save = true
	return default_value


func _read_fullscreen_setting() -> bool:
	# 读取并校验全屏字段，缺失或类型错误时使用窗口模式默认值。
	if not _config.has_section_key(DISPLAY_SECTION, FULLSCREEN_KEY):
		_settings_need_save = true
		return DEFAULT_FULLSCREEN

	var raw_value: Variant = _config.get_value(DISPLAY_SECTION, FULLSCREEN_KEY, DEFAULT_FULLSCREEN)
	if raw_value is bool:
		return bool(raw_value)

	push_warning("SettingsManager: invalid fullscreen setting; using default.")
	_settings_need_save = true
	return DEFAULT_FULLSCREEN


func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	# 查找目标 Bus；缺失时告警并跳过，避免阻断其他设置的应用。
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("SettingsManager: Audio Bus '%s' not found; skipped." % str(bus_name))
		return

	var normalized_value: float = clampf(value, 0.0, 1.0)
	if normalized_value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		return

	AudioServer.set_bus_volume_db(bus_index, linear_to_db(normalized_value))
	AudioServer.set_bus_mute(bus_index, false)


func _apply_fullscreen() -> void:
	# 只在窗口与全屏两种模式之间切换，不处理其他显示设置。
	var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)
