extends Node


func _ready() -> void:
	# 延后到当前场景完成挂载后再进入主菜单。
	call_deferred("_enter_main_menu")


func _enter_main_menu() -> void:
	# 启动始终进入菜单，剧情漫画由身份流程的动机分镜步骤启动。
	var error := SceneRouter.goto_main_menu()
	if error != OK:
		push_error("Boot: 无法进入启动页面，Error: %s" % error_string(error))
