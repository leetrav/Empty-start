extends Node


func _ready() -> void:
	# 延后到当前场景完成挂载后再进入主菜单。
	call_deferred("_enter_main_menu")


func _enter_main_menu() -> void:
	# 全局初始化后按应用观看记录进入开场漫画或主菜单。
	var error: Error
	if SettingsManager.opening_comic_seen:
		error = SceneRouter.goto_main_menu()
	else:
		error = SceneRouter.goto_comic(&"opening", true)
	if error != OK:
		push_error("Boot: 无法进入启动页面，Error: %s" % error_string(error))
