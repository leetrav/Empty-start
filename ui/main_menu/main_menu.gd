extends Control

@onready var save_state_label: Label = %SaveStateLabel
@onready var save_data_label: Label = %SaveDataLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	# 连接验收按钮并显示当前磁盘存档与内存数据状态。
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%GameButton.pressed.connect(_on_game_pressed)
	%ReloadButton.pressed.connect(_on_reload_pressed)
	_refresh_save_status()
	_set_status("主菜单已加载。请选择一个操作开始验收。")


func _on_new_game_pressed() -> void:
	# 创建确定性的测试数据，方便随后保存并验证读取结果。
	SaveManager.new_game()
	SaveManager.data.current_scene = "sandbox"
	SaveManager.data.checkpoint_id = "checkpoint_test"
	SaveManager.data.play_time = 123.0
	_refresh_save_status()
	_set_status("已创建新的 SaveData，当前数据只在内存中。")


func _on_save_pressed() -> void:
	# 显式保存当前运行时数据，并把真实错误反馈到界面。
	var save_error: Error = SaveManager.save_game()
	if save_error == OK:
		_set_status("保存成功：user://savegame.res")
	else:
		_set_status("保存失败：%s" % error_string(save_error))
	_refresh_save_status()


func _on_load_pressed() -> void:
	# 按需加载存档，验证磁盘数据能够恢复到 SaveManager.data。
	var load_error: Error = SaveManager.load_game()
	if load_error == OK:
		_set_status("读取成功：已恢复存档字段。")
	else:
		_set_status("读取失败：%s" % error_string(load_error))
	_refresh_save_status()


func _on_delete_pressed() -> void:
	# 删除单存档并刷新当前状态，便于重复验证完整生命周期。
	var delete_error: Error = SaveManager.delete_save()
	if delete_error == OK:
		_set_status("删除完成：当前没有磁盘存档。")
	else:
		_set_status("删除失败：%s" % error_string(delete_error))
	_refresh_save_status()


func _on_game_pressed() -> void:
	# 通过 SceneRouter 进入真实游戏入口 Sandbox 场景。
	var change_error: Error = SceneRouter.goto_game()
	if change_error != OK:
		_set_status("进入 Sandbox 失败：%s" % error_string(change_error))


func _on_reload_pressed() -> void:
	# 通过 SceneRouter 调用 Godot 原生的当前场景重载能力。
	var reload_error: Error = SceneRouter.reload_current_scene()
	if reload_error != OK:
		_set_status("重载主场景失败：%s" % error_string(reload_error))


func _refresh_save_status() -> void:
	# 只读取 SaveManager 的公开状态，不在 UI 中复制存档数据。
	var has_save: bool = SaveManager.has_save()
	save_state_label.text = "磁盘存档：%s" % ("存在" if has_save else "不存在")

	if SaveManager.data == null:
		save_data_label.text = "当前内存数据：null"
		return

	save_data_label.text = (
		"当前内存数据：scene=%s | checkpoint=%s | play_time=%.1f"
		% [
			SaveManager.data.current_scene,
			SaveManager.data.checkpoint_id,
			SaveManager.data.play_time,
		]
	)


func _set_status(message: String) -> void:
	# 将每次验收操作的结果集中显示在界面底部。
	status_label.text = message
