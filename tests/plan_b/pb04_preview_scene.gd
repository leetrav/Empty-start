extends Control

const BattleUIScene = preload("res://ui/plan_b/plan_b_battle_ui.tscn")
const SimulationScript = preload("res://tests/plan_b/pb04_preview_simulation.gd")
const BattleHostScript = preload("res://tests/plan_b/pb04_preview_battle_host.gd")
const WordCatalogScript = preload("res://tests/plan_b/pb04_preview_word_catalog.gd")
const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2(900.0, 490.0))

@export var review_window_size := Vector2i(1280, 720)
@export var density_profile := "clear"
@export var show_touch_review_overlay := false

var _simulation
var _battle_host
var _word_catalog
var _battle_ui


func _ready() -> void:
	# 预览只用本地内存适配器，供 PB-01/02/03 接入前做 UI 与鼠标验收。
	if review_window_size.x > 0 and review_window_size.y > 0:
		get_window().size = review_window_size
	_simulation = SimulationScript.new()
	add_child(_simulation)
	var definitions := _fixture_word_definitions()
	_word_catalog = WordCatalogScript.new()
	_word_catalog.set_definitions(definitions)
	add_child(_word_catalog)
	_battle_host = BattleHostScript.new()
	_battle_host.configure(_simulation, definitions)
	add_child(_battle_host)
	_battle_ui = BattleUIScene.instantiate()
	_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battle_ui)
	_battle_ui.bind_sources(_battle_host, _simulation, _word_catalog)
	_battle_ui.set_word_definitions(definitions)
	_battle_ui.set_world_bounds(WORLD_BOUNDS)
	_battle_ui.set_published_word_ids(_battle_host.get_published_word_ids())
	_battle_ui.set_publish_cooldown_remaining(_battle_host.get_display_cooldown())
	_battle_ui.set_battle_tier(_battle_host.get_demo_tier())
	_battle_ui.set_density_profile(density_profile)
	_battle_ui.set_review_source_label("PB-04 审核预览 · 内存夹具")
	_battle_ui.set_touch_review_mode(show_touch_review_overlay)
	if show_touch_review_overlay:
		get_window().title = "PB-04 移动触控排版预览 · 20:9"
	else:
		get_window().title = "PB-04 PC 鼠标交互预览 · 16:9"
	set_process(true)


func _process(_delta: float) -> void:
	if is_instance_valid(_battle_ui) and is_instance_valid(_battle_host):
		_battle_ui.set_publish_cooldown_remaining(_battle_host.get_display_cooldown())


func _fixture_word_definitions() -> Array:
	return [
		{"word_id": "pb04_demo_used", "text": "观众越多，越容易把一句话说成所有人的想法。", "battle_type": "type_a", "strength": 2, "traits": [], "tendency": "absurd", "available_level": 1},
		{"word_id": "pb04_demo_old", "text": "先别急着相信标题，看看是谁在重复它。", "battle_type": "type_b", "strength": 1, "traits": [], "tendency": "heresy", "available_level": 1},
		{"word_id": "pb04_demo_foe", "text": "每次复读都让这个说法看起来更像真的。", "battle_type": "type_c", "strength": 2, "traits": [], "tendency": "orthodox", "available_level": 1},
		{"word_id": "pb04_demo_04", "text": "我只是路过，怎么已经会背这句话了？", "battle_type": "type_a", "strength": 1, "traits": [], "tendency": "absurd", "available_level": 1},
		{"word_id": "pb04_demo_05", "text": "人群最擅长把猜测说成亲眼所见。", "battle_type": "type_b", "strength": 2, "traits": [], "tendency": "heresy", "available_level": 1},
		{"word_id": "pb04_demo_06", "text": "有人记得第一位开口的人吗？", "battle_type": "type_c", "strength": 3, "traits": [], "tendency": "absurd", "available_level": 1},
		{"word_id": "pb04_demo_07", "text": "如果所有人都在重复同一句话，谁还记得最初的意思？这条话语故意写得更长，用来检查选中后展开全文的排版。", "battle_type": "type_a", "strength": 3, "traits": [], "tendency": "heresy", "available_level": 1},
		{"word_id": "pb04_demo_08", "text": "越是整齐的声音，越需要有人问一句为什么。", "battle_type": "type_b", "strength": 2, "traits": [], "tendency": "absurd", "available_level": 1},
		{"word_id": "pb04_demo_09", "text": "相信之前，先看看这条消息从哪里来。", "battle_type": "type_c", "strength": 1, "traits": [], "tendency": "orthodox", "available_level": 1},
	]
