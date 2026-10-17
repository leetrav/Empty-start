extends Control

## D 的真实联调入口：实例化 A Host、B 棋子模拟、C 词库/费米决策与 PB-04 UI。

const BATTLE_HOST_SCRIPT: Script = preload("res://systems/plan_b/battle/plan_b_battle_host.gd")
const UNIT_SIMULATION_SCRIPT: Script = preload("res://systems/plan_b/simulation/plan_b_unit_simulation.gd")
const CONTENT_CATALOG_SCRIPT: Script = preload("res://systems/plan_b/content/plan_b_content_catalog.gd")
const OPPONENT_DIRECTOR_SCRIPT: Script = preload("res://systems/plan_b/opponent/fermi_opponent_director.gd")
const BATTLE_UI_SCENE: PackedScene = preload("res://ui/plan_b/plan_b_battle_ui.tscn")
const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2(900.0, 490.0))

@export var review_window_size := Vector2i(1280, 720)
@export var review_content_size := Vector2i(1920, 1080)
@export var touch_review_overlay := false


func _ready() -> void:
	# 只用可见窗口尺寸呈现审核比例；游戏设计视口仍为 1920×1080。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_window().size = review_window_size
	get_window().content_scale_size = review_content_size
	get_window().title = "PB-04 · 真实 A/B/C · %s" % ("移动 20:9" if touch_review_overlay else "PC 16:9")

	# A Host 仍是战斗状态、PK、词消耗和生命周期的唯一拥有者。
	var battle_host = BATTLE_HOST_SCRIPT.new()
	var unit_simulation = UNIT_SIMULATION_SCRIPT.new()
	unit_simulation.name = "Simulation"
	battle_host.add_child(unit_simulation)
	add_child(battle_host)
	if unit_simulation.has_method("set_random_seed"):
		unit_simulation.call("set_random_seed", 20261017)

	var content_catalog = CONTENT_CATALOG_SCRIPT.new()
	var opponent_director = OPPONENT_DIRECTOR_SCRIPT.new()
	var configured := bool(battle_host.call(
		"configure_modules", unit_simulation, content_catalog, opponent_director
	))
	if not configured:
		push_error("真实 A/B/C 模块配置失败；请检查 Godot 输出。")

	var battle_ui = BATTLE_UI_SCENE.instantiate()
	battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(battle_ui)
	battle_ui.set_world_bounds(WORLD_BOUNDS)
	battle_ui.set_review_source_label("真实模块 · A Host / B Simulation / C Catalog")
	battle_ui.bind_sources(battle_host, unit_simulation, content_catalog)
	battle_ui.set_word_definitions(battle_host.call("get_word_definitions", "player"))
	battle_ui.set_published_word_ids(battle_host.call("get_used_word_ids"))
	battle_ui.set_publish_cooldown_remaining(
		float(battle_host.call("get_publish_cooldown_remaining", "player"))
	)
	battle_ui.set_battle_tier(int(battle_host.call("get_current_tier")))
	battle_ui.set_touch_review_mode(touch_review_overlay)
	if battle_host.has_signal("counterattack_windup_started"):
		battle_host.connect("counterattack_windup_started", Callable(battle_ui, "show_counterattack_windup"))
	if battle_host.has_signal("counterattack_resolved"):
		battle_host.connect("counterattack_resolved", Callable(battle_ui, "show_counterattack_result"))
	if configured:
		# 审核场景自动开播，正式演示场景的开始/暂停/重开由 A root 控制。
		battle_host.call_deferred("start_battle", WORLD_BOUNDS.size, WORLD_BOUNDS.position)
