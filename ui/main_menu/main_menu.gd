extends Control


func _ready() -> void:
	# 连接主菜单按钮，保持菜单只负责输入与场景入口。
	%StartButton.pressed.connect(_on_start_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)


func _on_start_button_pressed() -> void:
	# 通过 SceneRouter 进入当前项目的游戏入口场景。
	var error: Error = SceneRouter.goto_game()
	if error != OK:
		push_error("MainMenu: 无法进入 Game，Error: %s" % error_string(error))


func _on_quit_button_pressed() -> void:
	# 退出行为由主菜单按钮明确触发。
	get_tree().quit()
