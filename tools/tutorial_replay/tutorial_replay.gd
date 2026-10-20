extends Node

## 本地独立试玩入口；由启动脚本隔离user://，不读取或清除玩家正式存档。
func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	# 防止直接F6运行此场景时把试玩结果写入玩家正式user://。
	var isolated_root := ProjectSettings.globalize_path("res://.godot/tutorial-replay-userdata").replace("\\", "/")
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(isolated_root + "/"):
		push_error("请使用tools/tutorial_replay/launch_tutorial.ps1打开隔离教程，避免影响正式进度。")
		get_tree().quit(1)
		return
	get_window().title = "首关新教程试玩（独立存档）"
	SceneRouter.game_scene_override = load("res://scenes/sandbox/sandbox_plan_b.tscn")
	SaveManager.new_game()
	var error := SaveManager.confirm_opening_identity("教程试玩", IdentityOptions.CARDS[0], "试玩团", IdentityConfirmationState.new())
	print("TUTORIAL_REPLAY_START isolated_save=", OS.get_user_data_dir())
	if error == OK:
		error = SceneRouter.goto_game()
	if error != OK:
		push_error("教程试玩启动失败：%s" % error_string(error))
		get_tree().quit(1)

		return