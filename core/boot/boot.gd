extends Node


func _ready() -> void:
	# 延后到当前场景完成挂载后再进入主菜单。
	call_deferred("_enter_main_menu")


func _enter_main_menu() -> void:
	# 此时全局 Autoload 已完成初始化，交由 SceneRouter 切换场景。
	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		push_error("Boot: 无法进入 MainMenu，Error: %s" % error_string(error))
