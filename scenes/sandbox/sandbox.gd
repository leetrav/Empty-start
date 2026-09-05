extends Control

@onready var data_label: Label = %DataLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	# 连接 Sandbox 验收按钮并显示当前 SaveManager 数据。
	%UpdateCheckpointButton.pressed.connect(_on_update_checkpoint_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%ReloadButton.pressed.connect(_on_reload_pressed)
	_refresh_data()
	_set_status("Sandbox 游戏入口已加载。")


func _on_update_checkpoint_pressed() -> void:
	# 修改一组确定的运行时字段，模拟游戏内检查点更新。
	if SaveManager.data == null:
		_set_status("当前没有内存存档，请先回主菜单新建或读取存档。")
		return

	SaveManager.data.current_scene = "sandbox"
	SaveManager.data.checkpoint_id = "sandbox_checkpoint"
	SaveManager.data.play_time = 456.0
	_refresh_data()
	_set_status("已修改当前检查点，尚未写入磁盘。")


func _on_save_pressed() -> void:
	# 显式保存 Sandbox 中的当前进度，并显示实际错误结果。
	var save_error: Error = SaveManager.save_game()
	if save_error == OK:
		_set_status("Sandbox 进度保存成功。")
	else:
		_set_status("Sandbox 保存失败：%s" % error_string(save_error))
	_refresh_data()


func _on_main_menu_pressed() -> void:
	# 通过 SceneRouter 返回主菜单，保存动作由单独按钮负责。
	var change_error: Error = SceneRouter.goto_main_menu()
	if change_error != OK:
		_set_status("返回主菜单失败：%s" % error_string(change_error))


func _on_reload_pressed() -> void:
	# 通过 SceneRouter 重载当前 Sandbox 场景。
	var reload_error: Error = SceneRouter.reload_current_scene()
	if reload_error != OK:
		_set_status("重载 Sandbox 失败：%s" % error_string(reload_error))


func _refresh_data() -> void:
	# 直接显示 SaveManager.data，确保场景间共享同一份运行时数据。
	if SaveManager.data == null:
		data_label.text = "当前内存数据：null"
		return

	data_label.text = (
		"当前内存数据：scene=%s | checkpoint=%s | play_time=%.1f"
		% [
			SaveManager.data.current_scene,
			SaveManager.data.checkpoint_id,
			SaveManager.data.play_time,
		]
	)


func _set_status(message: String) -> void:
	# 将 Sandbox 操作结果集中显示。
	status_label.text = message
