extends Control

## A 的场景组装根：注入 B/C 到 Host，再将唯一状态源交给 D 展示。

const BATTLE_UI_SCENE: PackedScene = preload("res://ui/plan_b/plan_b_battle_ui.tscn")
const CONTENT_CATALOG_SCRIPT: Script = preload("res://systems/plan_b/content/plan_b_content_catalog.gd")
const FERMI_DIRECTOR_SCRIPT: Script = preload("res://systems/plan_b/opponent/fermi_opponent_director.gd")
const BATTLE_WORLD_BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(900.0, 490.0))

var _tier_music: TierMusicPresenter
var _host: PlanBBattleHost
var _simulation: Node
var _content_catalog: Object
var _fermi_director: Object
var _battle_ui: Control
var _start_button: Button
var _pause_button: Button
var _restart_button: Button
var _lifecycle_status: Label
var _ui_sync_elapsed: float = 0.0


func _ready() -> void:
	# A 拥有跨模块生命周期；B 持有棋子，C 持有静态话语和费米请求，D 只消费事实。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host = $BattleHost
	_tier_music = TierMusicPresenter.new()
	add_child(_tier_music)
	_tier_music.bind_host(_host)
	_simulation = $BattleHost/Simulation
	_content_catalog = CONTENT_CATALOG_SCRIPT.new()
	_fermi_director = FERMI_DIRECTOR_SCRIPT.new()
	if not _host.configure_modules(_simulation, _content_catalog, _fermi_director):
		push_error("PB-01 无法加载 B/C 模块。请检查 Plan B TEST_ONLY 表和公开接口。")
	_build_lifecycle_bar()
	var battle_region := Control.new()
	battle_region.position = Vector2(0.0, 96.0)
	battle_region.size = Vector2(1920.0, 984.0)
	battle_region.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(battle_region)
	_battle_ui = BATTLE_UI_SCENE.instantiate()
	_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_region.add_child(_battle_ui)
	_battle_ui.call("bind_sources", _host, _simulation, _content_catalog)
	_battle_ui.call("set_word_definitions", _host.get_word_definitions("player"))
	_battle_ui.call("set_world_bounds", BATTLE_WORLD_BOUNDS)
	_battle_ui.call("set_published_word_ids", _host.get_used_word_ids())
	_battle_ui.call("set_publish_cooldown_remaining", _host.get_publish_cooldown_remaining("player"))
	_battle_ui.call("set_battle_tier", _host.get_current_tier())
	_battle_ui.call("set_review_source_label", "PB-01 · 正式 B/C/D 接线")
	_host.publish_result.connect(_on_publish_result)
	_host.battle_state_changed.connect(_on_battle_state_changed)
	_host.counterattack_windup_started.connect(_on_counterattack_windup_started)
	_host.counterattack_resolved.connect(_on_counterattack_resolved)
	_refresh_lifecycle_buttons()


func _process(delta: float) -> void:
	if _battle_ui == null:
		return
	_ui_sync_elapsed += delta
	if _ui_sync_elapsed < 0.1:
		return
	_ui_sync_elapsed = 0.0
	# D 的已发表状态和冷却均由 A 提供，UI 不维护第二份权威状态。
	_battle_ui.call("set_published_word_ids", _host.get_used_word_ids())
	_battle_ui.call("set_publish_cooldown_remaining", _host.get_publish_cooldown_remaining("player"))
	_refresh_lifecycle_buttons()


func _build_lifecycle_bar() -> void:
	# A 负责顶层场景生命周期入口；D 专注战斗操作界面与可视化。
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071018")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := Label.new()
	title.text = "费米直播间 · Plan B"
	title.position = Vector2(28.0, 18.0)
	title.size = Vector2(420.0, 52.0)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f1f4fa"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_lifecycle_status = Label.new()
	_lifecycle_status.text = "等待开播"
	_lifecycle_status.position = Vector2(520.0, 30.0)
	_lifecycle_status.size = Vector2(520.0, 32.0)
	_lifecycle_status.add_theme_font_size_override("font_size", 15)
	_lifecycle_status.add_theme_color_override("font_color", Color("#aeb8ca"))
	_lifecycle_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lifecycle_status)
	_start_button = _make_lifecycle_button("开始战斗", Rect2(1390.0, 18.0, 150.0, 54.0))
	_pause_button = _make_lifecycle_button("暂停", Rect2(1550.0, 18.0, 150.0, 54.0))
	_restart_button = _make_lifecycle_button("重开", Rect2(1710.0, 18.0, 150.0, 54.0))
	_start_button.pressed.connect(_on_start_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)


func _make_lifecycle_button(caption: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = bounds.position
	button.size = bounds.size
	button.add_theme_font_size_override("font_size", 17)
	add_child(button)
	return button


func _refresh_lifecycle_buttons() -> void:
	if _host == null or _start_button == null:
		return
	var state: StringName = _host.get_battle_state()
	_start_button.disabled = state == &"running" or state == &"paused"
	_start_button.text = "再开一局" if state == &"ended" else "开始战斗"
	_pause_button.disabled = state != &"running" and state != &"paused"
	_pause_button.text = "继续" if state == &"paused" else "暂停"
	_restart_button.disabled = state == &"idle"


func _on_publish_result(_team: String, _word_id: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)) or _battle_ui == null:
		return
	_battle_ui.call("set_published_word_ids", _host.get_used_word_ids())
	_battle_ui.call("set_publish_cooldown_remaining", _host.get_publish_cooldown_remaining("player"))


func _on_start_pressed() -> void:
	_host.start_battle(BATTLE_WORLD_BOUNDS.size, BATTLE_WORLD_BOUNDS.position)
	_refresh_lifecycle_buttons()


func _on_pause_pressed() -> void:
	if _host.get_battle_state() == &"running":
		_host.pause_battle()
	else:
		_host.resume_battle()
	_refresh_lifecycle_buttons()


func _on_restart_pressed() -> void:
	_host.restart_battle(BATTLE_WORLD_BOUNDS.size, BATTLE_WORLD_BOUNDS.position)
	_refresh_lifecycle_buttons()


func _on_battle_state_changed(state: StringName) -> void:
	if _battle_ui == null:
		return
	_refresh_lifecycle_buttons()
	_lifecycle_status.text = "等待开播" if state == &"idle" else "已暂停" if state == &"paused" else "本场结束" if state == &"ended" else "实时交战"
	match state:
		&"idle":
			_battle_ui.call("set_review_source_label", "PB-01 · 等待开播")
		&"running":
			_battle_ui.call("set_review_source_label", "PB-01 · 正式 B/C/D 接线")
		&"paused":
			_battle_ui.call("set_review_source_label", "PB-01 · 已暂停")
		&"ended":
			_battle_ui.call("set_review_source_label", "PB-01 · 本场结束")


func _on_counterattack_windup_started(request: Dictionary) -> void:
	# A 把 C 的蓄力请求事实转交 D；D 可订阅 Host 信号并展示细节。
	var skill_id: String = str(request.get("skill_id", ""))
	var parameters: Dictionary = request.get("effect_parameters", {})
	var child_count: int = int(parameters.get("child_count", 0))
	_lifecycle_status.text = "费米蓄力：%s ×%d" % [skill_id, child_count]
	if _battle_ui != null and _battle_ui.has_method("show_counterattack_windup"):
		_battle_ui.call("show_counterattack_windup", request.duplicate(true))
	elif _battle_ui != null:
		_battle_ui.call("set_review_source_label", "费米反击蓄力 · %s" % skill_id)


func _on_counterattack_resolved(result: Dictionary) -> void:
	# A 把 C 的结算快照转交 D，界面按 applied 显示实际结果。
	if _battle_ui != null and _battle_ui.has_method("show_counterattack_result"):
		_battle_ui.call("show_counterattack_result", result.duplicate(true))
	elif _battle_ui != null:
		var label: String = "费米反击成功" if bool(result.get("applied", false)) else "费米反击未执行"
		_lifecycle_status.text = label
		_battle_ui.call("set_review_source_label", label)

