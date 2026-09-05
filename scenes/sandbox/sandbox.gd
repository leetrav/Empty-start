extends Control


func _ready() -> void:
	# 连接 Sandbox 的两个技术验证入口。
	%ReloadButton.pressed.connect(_on_reload_button_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_button_pressed)


func _on_reload_button_pressed() -> void:
	# 通过 SceneRouter 重新加载当前 Sandbox 场景。
	var error: Error = SceneRouter.reload_current_scene()
	if error != OK:
		push_error("Sandbox: 当前场景重新加载失败，Error: %s" % error_string(error))


func _on_main_menu_button_pressed() -> void:
	# 通过 SceneRouter 返回主菜单。
	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		push_error("Sandbox: 无法返回 MainMenu，Error: %s" % error_string(error))
