extends Node

# 统一维护主菜单和游戏入口的目标路径，避免 UI 分散保存场景路径。
const MAIN_MENU_SCENE_PATH: String = "res://ui/main_menu/main_menu.tscn"
const IDENTITY_SETUP_SCENE_PATH: String = "res://ui/identity_setup/identity_setup.tscn"
const GAME_SCENE_PATH: String = "res://scenes/sandbox/sandbox.tscn"


func goto_main_menu() -> Error:
	# 加载并切换到项目约定的主菜单场景。
	var scene: PackedScene = _load_scene(MAIN_MENU_SCENE_PATH)
	if scene == null:
		return ERR_FILE_NOT_FOUND
	return _change_scene(scene)


func goto_identity_setup() -> Error:
	# 新周目的身份设置作为顶层页面统一通过 SceneRouter 切换。
	var scene: PackedScene = _load_scene(IDENTITY_SETUP_SCENE_PATH)
	if scene == null:
		return ERR_FILE_NOT_FOUND
	return _change_scene(scene)


func goto_game() -> Error:
	# 加载并切换到项目约定的游戏入口场景。
	var scene: PackedScene = _load_scene(GAME_SCENE_PATH)
	if scene == null:
		return ERR_FILE_NOT_FOUND
	return _change_scene(scene)


func reload_current_scene() -> Error:
	# 直接委托 Godot 重载当前场景，保留引擎原生生命周期行为。
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("SceneRouter: reload_current_scene failed: %s" % error_string(error))
	return error


func _load_scene(scene_path: String) -> PackedScene:
	# 空场景或损坏资源不能进入切换流程，统一在这里留下可定位的错误。
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("SceneRouter: scene resource not found: %s" % scene_path)
		return null

	var resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
	if resource == null or not resource is PackedScene:
		push_error("SceneRouter: scene resource is not a valid PackedScene: %s" % scene_path)
		return null
	return resource as PackedScene


func _change_scene(scene: PackedScene) -> Error:
	# 固定目标场景统一通过 Godot 原生 PackedScene 接口切换并回传错误。
	if scene == null:
		var invalid_error: Error = ERR_INVALID_PARAMETER
		push_error("SceneRouter: cannot change to a null PackedScene")
		return invalid_error

	var error: Error = get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("SceneRouter: change_scene_to_packed failed: %s" % error_string(error))
	return error
