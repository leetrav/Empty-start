extends Node


func _ready() -> void:
	# 延后到当前场景完成挂载后再进入主菜单。
	call_deferred("_enter_main_menu")


func _enter_main_menu() -> void:
	# 首次启动完整六幕，观看后启动直接进入菜单。
	var error := SceneRouter.goto_main_menu() if SettingsManager.opening_comic_seen else SceneRouter.goto_comic(&"intro", true)
	if error != OK:
		push_error("Boot: 无法进入启动页面，Error: %s" % error_string(error))
