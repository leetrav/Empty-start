extends Control

signal unit_clicked(unit_id: String, team: String)
signal empty_field_clicked

const TEAM_COLORS := {
	"neutral": Color("#92a2ad"),
	"player": Color("#50c7ff"),
	"opponent": Color("#ff9f68"),
}

var world_bounds := Rect2(Vector2.ZERO, Vector2(900.0, 490.0))
var density_profile := "clear"

var _snapshots: Array = []
var _word_texts: Dictionary = {}
var _team_textures: Dictionary = {}
var _selected_unit_id := ""
var _hovered_unit_id := ""
var _unit_layer_visible := true
var _feedback_pulses: Dictionary = {}
var _previous_points: Dictionary = {}
var _movement_segments: Dictionary = {}
var _contact_feedback: Array[Dictionary] = []

func _ready() -> void:
	# 场地只消费只读快照；鼠标和触控都按现有棋子的可见位置做命中。
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_world_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		world_bounds = bounds
	queue_redraw()


func set_unit_snapshots(snapshots: Array) -> void:
	if not _unit_layer_visible:
		_snapshots.clear()
		for value in snapshots:
			if value is Dictionary:
				_snapshots.append(value)
		_previous_points.clear()
		_movement_segments.clear()
		return
	var next_points: Dictionary = {}
	_movement_segments.clear()
	_snapshots.clear()
	for value in snapshots:
		if not value is Dictionary:
			continue
		var snapshot: Dictionary = value
		var unit_id := str(snapshot.get("unit_id", ""))
		if unit_id.is_empty():
			continue
		_snapshots.append(snapshot)
		next_points[unit_id] = _world_to_local(_unit_position(snapshot))
		if _previous_points.has(unit_id):
			var previous: Vector2 = _previous_points[unit_id]
			var current: Vector2 = next_points[unit_id]
			if previous.distance_squared_to(current) > 0.5:
				_movement_segments[unit_id] = {"from": previous, "to": current}
			_previous_points[unit_id] = current
		else:
			_previous_points[unit_id] = next_points[unit_id]
	for old_id in _previous_points.keys():
		if not next_points.has(old_id):
			_previous_points.erase(old_id)
	queue_redraw()


func set_word_texts(word_texts: Dictionary) -> void:
	_word_texts = word_texts.duplicate(true)
	queue_redraw()


func set_team_textures(neutral_texture: Texture2D, player_texture: Texture2D, opponent_texture: Texture2D) -> void:
	# 美术资源由 A/策划注入；当前仓库无独立观众棋子贴图时使用无字母的阵营色形状。
	_team_textures = {
		"neutral": neutral_texture,
		"player": player_texture,
		"opponent": opponent_texture,
	}
	queue_redraw()


func set_selected_unit(unit_id: String) -> void:
	_selected_unit_id = unit_id
	queue_redraw()


func set_unit_layer_visible(visible: bool) -> void:
	# 矛盾阶段隐藏普通棋子与接触提示，保留棋盘底板给蓄力准星使用。
	if _unit_layer_visible == visible:
		return
	_unit_layer_visible = visible
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	_hovered_unit_id = ""
	_movement_segments.clear()
	_previous_points.clear()
	if not visible:
		_selected_unit_id = ""
		_feedback_pulses.clear()
		_contact_feedback.clear()
	queue_redraw()


func set_density_profile(profile: String) -> void:
	density_profile = "compact" if profile == "compact" else "clear"
	queue_redraw()


func show_unit_feedback(unit_id: String, reason: String) -> void:
	if not unit_id.is_empty():
		_feedback_pulses[unit_id] = {"reason": reason, "time": Time.get_ticks_msec()}
	queue_redraw()


func show_contact_feedback(first_unit_id: String, second_unit_id: String, outcome: String) -> void:
	# 接触对来自 B 的裁决事件；线段只提示位置与结果，不影响模拟状态。
	_contact_feedback.push_front({
		"first_id": first_unit_id,
		"second_id": second_unit_id,
		"outcome": outcome,
		"time": Time.get_ticks_msec(),
	})
	while _contact_feedback.size() > 5:
		_contact_feedback.pop_back()
	queue_redraw()


func _process(_delta: float) -> void:
	# 只保留短暂提示；棋子位置仍由每帧的新快照决定。
	var now := Time.get_ticks_msec()
	var had_transient_feedback := not _feedback_pulses.is_empty() or not _contact_feedback.is_empty()
	for unit_id in _feedback_pulses.keys():
		if now - int(_feedback_pulses[unit_id].get("time", now)) > 1500:
			_feedback_pulses.erase(unit_id)
	for index in range(_contact_feedback.size() - 1, -1, -1):
		if now - int(_contact_feedback[index].get("time", now)) > 1200:
			_contact_feedback.remove_at(index)
	if had_transient_feedback or not _feedback_pulses.is_empty() or not _contact_feedback.is_empty():
		queue_redraw()


func _draw() -> void:
	var arena := _arena_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07121b"), true)
	draw_rect(arena, Color("#0b1c27"), true)
	draw_rect(arena, Color("#25404c"), false, 1.5)
	for column in range(1, 8):
		var x := arena.position.x + arena.size.x * float(column) / 8.0
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), Color(0.25, 0.42, 0.49, 0.18), 1.0)
	for row in range(1, 5):
		var y := arena.position.y + arena.size.y * float(row) / 5.0
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color(0.25, 0.42, 0.49, 0.18), 1.0)
	if not _unit_layer_visible:
		return

	# 移动尾迹来自前一帧只读位置，用低对比度避免遮住密集棋子。
	for segment in _movement_segments.values():
		draw_line(segment["from"], segment["to"], Color(0.60, 0.78, 0.83, 0.22), 1.2)
	_draw_contact_feedback()

	for snapshot in _snapshots:
		_draw_unit(snapshot)
	_draw_speech_bubble(_snapshot_for_id(_hovered_unit_id))
	if _selected_unit_id != _hovered_unit_id:
		_draw_speech_bubble(_snapshot_for_id(_selected_unit_id))


func _draw_unit(snapshot: Dictionary) -> void:
	var unit_id := str(snapshot.get("unit_id", ""))
	var team := str(snapshot.get("team", "neutral"))
	var center := _world_to_local(_unit_position(snapshot))
	var tint: Color = TEAM_COLORS.get(team, TEAM_COLORS["neutral"])
	var radius := _visual_radius(snapshot)
	var is_neutral := team == "neutral"
	var is_selected := unit_id == _selected_unit_id
	var is_hovered := unit_id == _hovered_unit_id

	if is_selected or is_hovered:
		draw_circle(center, radius + 8.0, Color(tint.r, tint.g, tint.b, 0.22))
	var token_texture: Texture2D = _team_textures.get(team) as Texture2D
	if token_texture != null:
		draw_texture_rect(token_texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	else:
		draw_circle(center, radius + 2.0, Color("#07121b"))
		draw_circle(center, radius, tint)

	if _feedback_pulses.has(unit_id):
		var feedback: Dictionary = _feedback_pulses[unit_id]
		var age := float(Time.get_ticks_msec() - int(feedback.get("time", 0))) / 1500.0
		var pulse_color := _feedback_color(str(feedback.get("reason", "")))
		draw_arc(center, radius + 12.0 + 8.0 * age, 0.0, TAU, 32, Color(pulse_color.r, pulse_color.g, pulse_color.b, 1.0 - age), 2.0, true)


func _draw_speech_bubble(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var word_id := str(snapshot.get("word_id", ""))
	if word_id.is_empty():
		return
	var phrase := str(_word_texts.get(word_id, snapshot.get("text", "")))
	if phrase.is_empty():
		return
	var center := _world_to_local(_unit_position(snapshot))
	var shown := phrase.left(20)
	if phrase.length() > 20:
		shown += "…"
	var bubble_width := minf(280.0, maxf(180.0, size.x - 28.0))
	var bubble_height := 36.0
	var bubble := Rect2(center + Vector2(18.0, -bubble_height - 6.0), Vector2(bubble_width, bubble_height))
	if bubble.end.x > size.x - 8.0:
		bubble.position.x = center.x - bubble_width - 18.0
	if bubble.position.y < 8.0:
		bubble.position.y = center.y + 16.0
	draw_rect(bubble, Color("#132632"), true)
	draw_rect(bubble, Color("#51717e"), false, 1.0)
	draw_string(ThemeDB.fallback_font, bubble.position + Vector2(10.0, 23.0), shown, HORIZONTAL_ALIGNMENT_LEFT, bubble_width - 20.0, 15, Color("#f1f7f8"))


func _draw_contact_feedback() -> void:
	var now := Time.get_ticks_msec()
	for contact in _contact_feedback:
		var first := _snapshot_for_id(str(contact.get("first_id", "")))
		var second := _snapshot_for_id(str(contact.get("second_id", "")))
		if first.is_empty() or second.is_empty():
			continue
		var age := clampf(float(now - int(contact.get("time", now))) / 1200.0, 0.0, 1.0)
		var tint := _contact_color(str(contact.get("outcome", "")))
		var alpha := (1.0 - age) * 0.72
		var first_point := _world_to_local(_unit_position(first))
		var second_point := _world_to_local(_unit_position(second))
		draw_line(first_point, second_point, Color(tint.r, tint.g, tint.b, alpha), 2.5)
		draw_arc(first_point, 23.0 + age * 7.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, alpha), 1.7, true)
		draw_arc(second_point, 23.0 + age * 7.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, alpha), 1.7, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover: Dictionary = _hit_unit(event.position, 25.0)
		var next_hover := str(hover.get("unit_id", ""))
		if next_hover != _hovered_unit_id:
			_hovered_unit_id = next_hover
			queue_redraw()
		return

	var click_position := Vector2.ZERO
	var hit_radius := 26.0
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		click_position = event.position
		hit_radius = 48.0
		pressed = true
	if not pressed:
		return

	if not _arena_rect().grow(8.0).has_point(click_position):
		return
	var target := _hit_unit(click_position, hit_radius)
	if target.is_empty():
		empty_field_clicked.emit()
	else:
		unit_clicked.emit(str(target.get("unit_id", "")), str(target.get("team", "neutral")))
	accept_event()


func _hit_unit(point: Vector2, hit_radius: float) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := hit_radius * hit_radius
	for snapshot in _snapshots:
		var unit_point := _world_to_local(_unit_position(snapshot))
		var distance := point.distance_squared_to(unit_point)
		if distance <= nearest_distance:
			nearest = snapshot
			nearest_distance = distance
	return nearest


func _arena_rect() -> Rect2:
	var available := Rect2(Vector2.ZERO, size)
	if available.size.x <= 0.0 or available.size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var world_ratio := world_bounds.size.x / world_bounds.size.y
	var width := available.size.x
	var height := width / world_ratio
	if height > available.size.y:
		height = available.size.y
		width = height * world_ratio
	return Rect2(available.position + (available.size - Vector2(width, height)) * 0.5, Vector2(width, height))


func _visual_radius(snapshot: Dictionary) -> float:
	var radius := maxf(1.0, float(snapshot.get("collision_radius", 13.0)))
	return radius * 0.82 if density_profile == "compact" else radius


func _world_to_local(world_position: Vector2) -> Vector2:
	var arena := _arena_rect()
	var relative := Vector2(
		(world_position.x - world_bounds.position.x) / world_bounds.size.x,
		(world_position.y - world_bounds.position.y) / world_bounds.size.y
	)
	return arena.position + Vector2(relative.x * arena.size.x, relative.y * arena.size.y)


func _unit_position(snapshot: Dictionary) -> Vector2:
	var value: Variant = snapshot.get("position", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _snapshot_for_id(unit_id: String) -> Dictionary:
	if unit_id.is_empty():
		return {}
	for snapshot in _snapshots:
		if str(snapshot.get("unit_id", "")) == unit_id:
			return snapshot
	return {}


func _feedback_color(reason: String) -> Color:
	match reason:
		"seed":
			return Color("#74e2ff")
		"convert":
			return Color("#ff806e")
		"relay":
			return Color("#d7a8ff")
		"counterattack":
			return Color("#f17de3")
		_:
			return Color("#d7edf3")


func _contact_color(outcome: String) -> Color:
	match outcome:
		"converted":
			return Color("#ff806e")
		"infection_failed":
			return Color("#ffc77d")
		"same_team_bounce":
			return Color("#d7a8ff")
		"same_type_bounce":
			return Color("#79c9e8")
		"no_counter_bounce":
			return Color("#a1adbc")
		_:
			return Color("#91a4ae")
