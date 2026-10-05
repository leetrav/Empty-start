extends Node

const SAVE_PATH: String = "user://savegame.res"

var data: SaveData = null


func _ready() -> void:
	# 只初始化运行时状态，存档由主菜单或游戏流程按需加载。
	data = null


func new_game() -> void:
	# 创建新的运行时存档数据，不主动覆盖磁盘中的旧存档。
	data = SaveData.new()


# 将身份系统确认后的姓名和身份 ID 写入当前周目数据。
func set_identity_data(streamer_name: String, identity_id: StringName) -> Error:
	if data == null:
		push_error("SaveManager: cannot set identity because current SaveData is null.")
		return ERR_UNCONFIGURED

	data.streamer_name = streamer_name
	data.identity_id = identity_id
	return OK


func save_game() -> Error:
	# 将当前 SaveData 写入固定用户存档路径，并返回 ResourceSaver 的结果。
	if data == null:
		push_error("SaveManager: cannot save because data is null.")
		return ERR_UNCONFIGURED

	var save_error: Error = ResourceSaver.save(data, SAVE_PATH)
	if save_error != OK:
		push_error("SaveManager: failed to save '%s': %s" % [SAVE_PATH, error_string(save_error)])
	return save_error


func load_game() -> Error:
	# 忽略 Resource 缓存读取存档，并验证资源类型与版本后再替换当前数据。
	if not FileAccess.file_exists(SAVE_PATH):
		data = null
		push_warning("SaveManager: save file '%s' was not found." % SAVE_PATH)
		return ERR_FILE_NOT_FOUND

	var loaded_resource: Resource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_resource == null:
		data = null
		push_error("SaveManager: failed to load save file '%s'." % SAVE_PATH)
		return ERR_FILE_CANT_READ

	var loaded_data: SaveData = loaded_resource as SaveData
	if loaded_data == null:
		data = null
		push_error("SaveManager: save file '%s' is not a SaveData resource." % SAVE_PATH)
		return ERR_INVALID_DATA

	if loaded_data.save_version != SaveData.CURRENT_VERSION:
		data = null
		push_warning(
			"SaveManager: unsupported save version %d; expected %d."
			% [loaded_data.save_version, SaveData.CURRENT_VERSION]
		)
		return ERR_INVALID_DATA

	data = loaded_data
	return OK


func has_save() -> bool:
	# 只检查固定存档文件是否存在，不加载或修复存档内容。
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> Error:
	# 删除成功后才清空内存数据；文件不存在时视为已无存档。
	if not FileAccess.file_exists(SAVE_PATH):
		data = null
		return OK

	var delete_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if delete_error != OK:
		push_error("SaveManager: failed to delete '%s': %s" % [SAVE_PATH, error_string(delete_error)])
		return delete_error

	data = null
	return OK
