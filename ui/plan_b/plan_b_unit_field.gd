extends Control

signal unit_clicked(unit_id: String, team: String)
signal empty_field_clicked
signal board_position_clicked(spawn_position: Vector2)

const TEAM_COLORS := {
	"neutral": Color("#92a2ad"),
	"player": Color("#50c7ff"),
	"opponent": Color("#ff9f68"),
}

var world_bounds := Rect2(Vector2.ZERO, Vector2(900.0, 490.0))
var density_profile := "clear"

var _snapshots: Array = []
var _snapshots_by_id: Dictionary = {}
var _word_texts: Dictionary = {}
var _unit_sprite_textures: Dictionary = {}
var _active_opponent_sprite_id := "alien"
var _word_groups: Array = []
var _active_group_bubble_ids: Dictionary = {}
var _group_bubble_layouts: Dictionary = {}
var _group_bubble_styles: Dictionary = {}
var _word_group_signature := ""
var _selected_unit_id := ""
var _hovered_unit_id := ""
var _unit_layer_visible := true
var _feedback_pulses: Dictionary = {}
var _previous_points: Dictionary = {}
var _previous_physics_positions: Dictionary = {}
var _current_physics_positions: Dictionary = {}
var _render_interpolation_fraction := 0.0
var _movement_segments: Dictionary = {}
var _contact_feedback: Array[Dictionary] = []
var _word_batch_bursts: Array[Dictionary] = []

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
		_snapshots_by_id.clear()
		for value in snapshots:
			if value is Dictionary:
				_snapshots.append(value)
				var unit_id := str(value.get("unit_id", ""))
				if not unit_id.is_empty():
					_snapshots_by_id[unit_id] = value
		_previous_points.clear()
		_movement_segments.clear()
		return
	var next_points: Dictionary = {}
	_movement_segments.clear()
	_snapshots.clear()
	_snapshots_by_id.clear()
	for value in snapshots:
		if not value is Dictionary:
			continue
		var snapshot: Dictionary = value
		var unit_id := str(snapshot.get("unit_id", ""))
		if unit_id.is_empty():
			continue
		_snapshots.append(snapshot)
		_snapshots_by_id[unit_id] = snapshot
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


func set_physics_tick_positions(positions: Dictionary) -> void:
	# 每个物理 tick 只保存 unit_id 和 Vector2；渲染帧用引擎插值比例平滑显示。
	var next_positions: Dictionary = {}
	for unit_id_value in positions:
		var position := _position_value(positions[unit_id_value])
		if position != Vector2.ZERO:
			next_positions[str(unit_id_value)] = position
	var previous_positions: Dictionary = {}
	for unit_id in next_positions:
		var current: Vector2 = next_positions[unit_id]
		var previous: Vector2 = _current_physics_positions.get(unit_id, current)
		if previous.distance_to(current) > 96.0:
			previous = current
		previous_positions[unit_id] = previous
	_current_physics_positions = next_positions
	_previous_physics_positions = previous_positions
	queue_redraw()


func set_physics_tick_position_arrays(unit_ids: Variant, previous_positions: Variant, current_positions: Variant) -> void:
	# B 按相同索引传递 ID、上一 tick 位置和当前 tick 位置，不带话语文本或单位字典。
	var next_previous: Dictionary = {}
	var next_current: Dictionary = {}
	var item_count: int = mini(int(unit_ids.size()), mini(int(previous_positions.size()), int(current_positions.size())))
	for index in item_count:
		var unit_id := str(unit_ids[index])
		var previous: Vector2 = _position_value(previous_positions[index])
		var current: Vector2 = _position_value(current_positions[index])
		if previous.distance_to(current) > 96.0:
			previous = current
		next_previous[unit_id] = previous
		next_current[unit_id] = current
	_previous_physics_positions = next_previous
	_current_physics_positions = next_current
	queue_redraw()


func forget_unit_position(unit_id: String) -> void:
	# 离场后清除插值历史，重开时复用 ID 也不会从旧位置拖出残影。
	_previous_physics_positions.erase(unit_id)
	_current_physics_positions.erase(unit_id)
	queue_redraw()


func reset_physics_interpolation_history() -> void:
	_previous_physics_positions.clear()
	_current_physics_positions.clear()
	queue_redraw()


func set_word_texts(word_texts: Dictionary) -> void:
	# 詞文字典只在內容變更時替換；渲染幀保留同一個只讀引用。
	_word_texts = word_texts
	_group_bubble_layouts.clear()
	queue_redraw()


func set_word_groups(groups: Array, active_bubble_ids: Dictionary) -> void:
	# D 只消費 B 已算好的连通团体，不在显示层重复做邻近扫描。
	var signature := _build_word_group_signature(groups)
	if signature != _word_group_signature:
		_word_group_signature = signature
		_group_bubble_layouts.clear()
	_word_groups = groups
	_active_group_bubble_ids = active_bubble_ids
	queue_redraw()


func set_team_textures(neutral_texture: Texture2D, player_texture: Texture2D, opponent_texture: Texture2D) -> void:
	# 兼容旧接线；正式头像映射由 set_unit_sprite_textures 提供。
	_unit_sprite_textures["npc"] = neutral_texture
	_unit_sprite_textures["ham"] = player_texture
	_unit_sprite_textures[_active_opponent_sprite_id] = opponent_texture
	queue_redraw()


func set_unit_sprite_textures(textures: Dictionary) -> void:
	# 静态头像表由 UI 注入；本函数只保存只读引用，避免每帧复制纹理字典。
	_unit_sprite_textures = textures
	queue_redraw()


func set_active_opponent_sprite_id(streamer_id: String) -> void:
	_active_opponent_sprite_id = streamer_id if _unit_sprite_textures.has(streamer_id) else "alien"
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
	reset_physics_interpolation_history()
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


func show_word_batch_burst(batch: Dictionary) -> void:
	# 发表事实只负责约半秒的扇形入场提示；棋子位置仍取 B 的实时快照。
	var visual: Dictionary = batch.duplicate(false)
	visual["started_at_msec"] = Time.get_ticks_msec()
	_word_batch_bursts.push_front(visual)
	while _word_batch_bursts.size() > 6:
		_word_batch_bursts.pop_back()
	queue_redraw()


func _process(_delta: float) -> void:
	# 只保留短暂提示；棋子位置仍由每帧的新快照决定。
	var now := Time.get_ticks_msec()
	var had_transient_feedback := not _feedback_pulses.is_empty() or not _contact_feedback.is_empty() or not _word_batch_bursts.is_empty()
	for unit_id in _feedback_pulses.keys():
		if now - int(_feedback_pulses[unit_id].get("time", now)) > 1500:
			_feedback_pulses.erase(unit_id)
	for index in range(_contact_feedback.size() - 1, -1, -1):
		if now - int(_contact_feedback[index].get("time", now)) > 1200:
			_contact_feedback.remove_at(index)
	for index in range(_word_batch_bursts.size() - 1, -1, -1):
		if now - int(_word_batch_bursts[index].get("started_at_msec", now)) > 650:
			_word_batch_bursts.remove_at(index)
	if had_transient_feedback or not _feedback_pulses.is_empty() or not _contact_feedback.is_empty():
		queue_redraw()


func _draw() -> void:
	_render_interpolation_fraction = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
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
	_draw_word_batch_bursts()

	for snapshot in _snapshots:
		_draw_unit(snapshot)
	_draw_group_bubbles()


func _draw_unit(snapshot: Dictionary) -> void:
	var unit_id := str(snapshot.get("unit_id", ""))
	var team := str(snapshot.get("team", "neutral"))
	var center := _display_local_position(unit_id, snapshot)
	var tint: Color = TEAM_COLORS.get(team, TEAM_COLORS["neutral"])
	var radius := _visual_radius(snapshot)
	var is_neutral := team == "neutral"
	var is_selected := unit_id == _selected_unit_id
	var is_hovered := unit_id == _hovered_unit_id

	if is_selected or is_hovered:
		draw_circle(center, radius + 8.0, Color(tint.r, tint.g, tint.b, 0.22))
	var sprite_id := _sprite_id_for(snapshot, team)
	var token_texture: Texture2D = _unit_sprite_textures.get(sprite_id) as Texture2D
	if token_texture != null:
		draw_texture_rect(token_texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	else:
		draw_circle(center, radius + 2.0, Color("#07121b"))
		draw_circle(center, radius, tint)
	draw_arc(center, radius + 1.8, 0.0, TAU, 20, tint, 2.0, true)
	var attribute_color := _battle_type_color(str(snapshot.get("battle_type", "")))
	var badge_center := center + Vector2(radius * 0.68, radius * 0.68)
	draw_circle(badge_center, 5.0, Color("#07121b"))
	draw_circle(badge_center, 3.0, attribute_color)

	if _feedback_pulses.has(unit_id):
		var feedback: Dictionary = _feedback_pulses[unit_id]
		var age := float(Time.get_ticks_msec() - int(feedback.get("time", 0))) / 1500.0
		var pulse_color := _feedback_color(str(feedback.get("reason", "")))
		draw_arc(center, radius + 12.0 + 8.0 * age, 0.0, TAU, 32, Color(pulse_color.r, pulse_color.g, pulse_color.b, 1.0 - age), 2.0, true)


func _draw_group_bubbles() -> void:
	# 每帧只取可见团体成员的当前显示位置；文本测量和尾巴成员选择由布局缓存复用。
	if not _unit_layer_visible or _active_group_bubble_ids.is_empty():
		return
	for group_value in _word_groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value
		var group_id := _group_id(group)
		if group_id.is_empty() or not _active_group_bubble_ids.has(group_id):
			continue
		var member_ids := _group_member_ids(group)
		if member_ids.is_empty():
			continue
		var word_id := str(group.get("word_id", ""))
		var phrase := _group_text(group, word_id)
		if word_id.is_empty() or phrase.is_empty() or str(group.get("team", "neutral")) == "neutral":
			continue
		var layout := _get_group_bubble_layout(group, group_id, member_ids, phrase)
		var positions_by_id := _group_member_positions(group, member_ids)
		if positions_by_id.is_empty():
			continue
		var center := Vector2.ZERO
		for position_value in positions_by_id.values():
			center += position_value
		center /= float(positions_by_id.size())
		var bubble_width := float(layout.get("width", 100.0))
		var bubble_height := float(layout.get("height", 48.0))
		var bubble_rect := Rect2(Vector2(center.x - bubble_width * 0.5, center.y - bubble_height - 38.0), Vector2(bubble_width, bubble_height))
		if bubble_rect.position.y < 8.0:
			bubble_rect.position.y = center.y + 38.0
		bubble_rect.position.x = clampf(bubble_rect.position.x, 8.0, maxf(8.0, size.x - bubble_width - 8.0))
		bubble_rect.position.y = clampf(bubble_rect.position.y, 8.0, maxf(8.0, size.y - bubble_height - 8.0))
		var style: StyleBoxFlat = _get_group_bubble_style(str(group.get("team", "player")))
		_draw_group_bubble_tails(bubble_rect, layout, positions_by_id, style.bg_color, style.border_color, center.y)
		draw_style_box(style, bubble_rect)
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		var padding := 12.0
		draw_multiline_string(
			font,
			bubble_rect.position + Vector2(padding, padding + 8.0),
			phrase,
			HORIZONTAL_ALIGNMENT_CENTER,
			bubble_width - padding * 2.0,
			int(layout.get("font_size", 20)),
			-1,
			Color("#36252f")
		)


func _get_group_bubble_layout(group: Dictionary, group_id: String, member_ids: Array, phrase: String) -> Dictionary:
	var signature := "%s|%d|%s|%d|%d" % [str(group.get("team", "")), member_ids.size(), phrase, int(size.x), int(size.y)]
	var cached: Dictionary = _group_bubble_layouts.get(group_id, {})
	if str(cached.get("signature", "")) == signature:
		return cached
	var bubble_width := minf(_bubble_base_width(member_ids.size()), maxf(100.0, size.x - 24.0))
	var padding := 12.0
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := 26
	var measured := Vector2.ZERO
	for candidate_size in range(26, 15, -1):
		measured = font.get_multiline_string_size(phrase, HORIZONTAL_ALIGNMENT_CENTER, bubble_width - padding * 2.0, candidate_size)
		font_size = candidate_size
		if measured.y <= size.y - 72.0:
			break
	var bubble_height := clampf(measured.y + padding * 2.0 + 8.0, 54.0, maxf(54.0, size.y - 16.0))
	var layout := {
		"signature": signature,
		"width": bubble_width,
		"height": bubble_height,
		"font_size": font_size,
		"tail_ids": _choose_tail_member_ids(group, member_ids),
	}
	_group_bubble_layouts[group_id] = layout
	return layout


func _choose_tail_member_ids(group: Dictionary, member_ids: Array) -> Array:
	var positions_value: Variant = group.get("member_positions", {})
	var positions: Dictionary = positions_value if positions_value is Dictionary else {}
	if positions_value is Array:
		for index in mini(member_ids.size(), positions_value.size()):
			positions[str(member_ids[index])] = _position_value(positions_value[index])
	var sorted_ids: Array = member_ids.duplicate()
	sorted_ids.sort_custom(func(first: Variant, second: Variant) -> bool:
		var first_position: Vector2 = _position_value(positions.get(str(first), positions.get(first, Vector2.ZERO)))
		var second_position: Vector2 = _position_value(positions.get(str(second), positions.get(second, Vector2.ZERO)))
		if not first_position.is_zero_approx() or not second_position.is_zero_approx():
			return first_position.x < second_position.x
		return str(first) < str(second)
	)
	var tail_count := _bubble_tail_count(sorted_ids.size())
	var selected: Array = []
	if tail_count <= 1:
		selected.append(sorted_ids[sorted_ids.size() / 2])
		return selected
	for tail_index in tail_count:
		var sample_index := roundi(float(tail_index) * float(sorted_ids.size() - 1) / float(tail_count - 1))
		selected.append(sorted_ids[sample_index])
	return selected


func _draw_group_bubble_tails(
	bubble_rect: Rect2,
	layout: Dictionary,
	positions_by_id: Dictionary,
	fill_color: Color,
	border_color: Color,
	group_center_y: float
) -> void:
	var tail_ids: Array = layout.get("tail_ids", [])
	if tail_ids.is_empty():
		return
	var point_down := bubble_rect.get_center().y < group_center_y
	for tail_index in tail_ids.size():
		var member_id := str(tail_ids[tail_index])
		if not positions_by_id.has(member_id):
			continue
		var target: Vector2 = positions_by_id[member_id]
		var spread := bubble_rect.size.x / float(tail_ids.size() + 1)
		var root := Vector2(bubble_rect.position.x + spread * float(tail_index + 1), bubble_rect.end.y if point_down else bubble_rect.position.y)
		var target_tip := target + (Vector2(0.0, -12.0) if point_down else Vector2(0.0, 12.0))
		var half_width := 6.0
		var triangle := PackedVector2Array([root + Vector2(-half_width, 0.0), root + Vector2(half_width, 0.0), target_tip])
		draw_colored_polygon(triangle, fill_color)
		draw_line(triangle[0], triangle[2], border_color, 1.6)
		draw_line(triangle[1], triangle[2], border_color, 1.6)


func _get_group_bubble_style(team: String) -> StyleBoxFlat:
	if _group_bubble_styles.has(team):
		return _group_bubble_styles[team] as StyleBoxFlat
	var border: Color = TEAM_COLORS.get(team, Color("#d887ab"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4f7")
	style.border_color = border.lightened(0.2)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_group_bubble_styles[team] = style
	return style

func _bubble_base_width(member_count: int) -> float:
	if member_count <= 1:
		return 100.0
	if member_count == 2:
		return 150.0
	if member_count >= 8:
		return 500.0
	return 150.0 + float(member_count - 2) * 350.0 / 6.0


func _bubble_tail_count(member_count: int) -> int:
	if member_count <= 1:
		return 1
	if member_count == 2:
		return 2
	if member_count == 3:
		return 3
	if member_count == 4:
		return 3
	if member_count <= 6:
		return 4
	return 5


func _group_id(group: Dictionary) -> String:
	return str(group.get("group_id", group.get("id", "")))


func _group_member_ids(group: Dictionary) -> Array:
	var values: Variant = group.get("member_ids", group.get("unit_ids", group.get("members", [])))
	if not values is Array:
		return []
	var result: Array = []
	for value in values:
		if value is Dictionary:
			var member_id := str(value.get("unit_id", value.get("id", "")))
			if not member_id.is_empty():
				result.append(member_id)
		else:
			result.append(str(value))
	return result


func _group_text(group: Dictionary, word_id: String) -> String:
	var direct_text := str(group.get("text", group.get("word_text", "")))
	if not direct_text.is_empty():
		return direct_text
	var word_snapshot: Variant = group.get("word_snapshot", {})
	if word_snapshot is Dictionary and not str(word_snapshot.get("text", "")).is_empty():
		return str(word_snapshot.get("text", ""))
	return str(_word_texts.get(word_id, ""))


func _group_member_positions(group: Dictionary, member_ids: Array) -> Dictionary:
	var positions: Dictionary = {}
	var provided: Variant = group.get("member_positions", {})
	for member_index in member_ids.size():
		var member_id := str(member_ids[member_index])
		var snapshot: Dictionary = _snapshots_by_id.get(member_id, {})
		var position := _unit_position(snapshot) if not snapshot.is_empty() else Vector2.ZERO
		if position.is_zero_approx():
			position = _provided_member_position(provided, member_id, member_index)
		if not position.is_zero_approx():
			var previous_position: Vector2 = _previous_physics_positions.get(member_id, position)
			var current_position: Vector2 = _current_physics_positions.get(member_id, position)
			positions[member_id] = _world_to_local(previous_position.lerp(current_position, _render_interpolation_fraction))
	if positions.is_empty():
		var center: Vector2 = _position_value(group.get("center_position", Vector2.ZERO))
		if not center.is_zero_approx():
			positions["__center__"] = _world_to_local(center)
	return positions


func _provided_member_position(value: Variant, member_id: String, index: int) -> Vector2:
	if value is Dictionary:
		var position_value: Variant = value.get(member_id, Vector2.ZERO)
		if position_value == Vector2.ZERO and member_id.is_valid_int():
			position_value = value.get(member_id.to_int(), Vector2.ZERO)
		return _position_value(position_value)
	if value is Array and index < value.size():
		return _position_value(value[index])
	return Vector2.ZERO


func _position_value(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var position_value: Variant = value.get("position", Vector2.ZERO)
		return position_value if position_value is Vector2 else Vector2.ZERO
	return Vector2.ZERO


func _build_word_group_signature(groups: Array) -> String:
	var parts: Array[String] = []
	for group_value in groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value
		var members := _group_member_ids(group)
		members.sort_custom(func(first: Variant, second: Variant) -> bool: return str(first) < str(second))
		var member_parts: Array[String] = []
		for member_id in members:
			member_parts.append(str(member_id))
		parts.append("%s:%s:%s:%s" % [
			_group_id(group),
			str(group.get("team", "")),
			str(group.get("word_id", "")),
			",".join(member_parts),
		])
	return "|".join(parts)


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
		var first_point := _display_local_position(str(first.get("unit_id", "")), first)
		var second_point := _display_local_position(str(second.get("unit_id", "")), second)
		draw_line(first_point, second_point, Color(tint.r, tint.g, tint.b, alpha), 2.5)
		draw_arc(first_point, 23.0 + age * 7.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, alpha), 1.7, true)
		draw_arc(second_point, 23.0 + age * 7.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, alpha), 1.7, true)


func _draw_word_batch_bursts() -> void:
	# 环与短线强调同一次发表产生的完整批次，不参与感染或碰撞。
	var now := Time.get_ticks_msec()
	for batch in _word_batch_bursts:
		var age := clampf(float(now - int(batch.get("started_at_msec", now))) / 520.0, 0.0, 1.0)
		var alpha := 1.0 - age
		var team := str(batch.get("team", "player"))
		var color: Color = TEAM_COLORS.get(team, TEAM_COLORS["player"])
		var origin := _world_to_local(_vector_from_variant(batch.get("spawn_position", Vector2.ZERO)))
		draw_arc(origin, 14.0 + age * 76.0, 0.0, TAU, 40, Color(color.r, color.g, color.b, alpha * 0.9), 2.4, true)
		var unit_ids: Array = batch.get("unit_ids", [])
		for unit_id in unit_ids:
			var snapshot := _snapshot_for_id(str(unit_id))
			if snapshot.is_empty():
				continue
			var target := _display_local_position(str(unit_id), snapshot)
			draw_line(origin.lerp(target, age), target, Color(color.r, color.g, color.b, alpha * 0.75), 1.8)


func _sprite_id_for(snapshot: Dictionary, team: String) -> String:
	if team == "neutral":
		return "npc"
	if team == "player":
		return "ham"
	var streamer_id := str(snapshot.get("streamer_id", _active_opponent_sprite_id))
	return streamer_id if _unit_sprite_textures.has(streamer_id) else _active_opponent_sprite_id


func _battle_type_color(battle_type: String) -> Color:
	match battle_type:
		"type_a":
			return Color("#70def5")
		"type_b":
			return Color("#d5a2ff")
		"type_c":
			return Color("#ffd477")
		_:
			return Color("#e4eef2")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not _hovered_unit_id.is_empty():
			_hovered_unit_id = ""
			queue_redraw()
		return

	var click_position := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		click_position = event.position
		pressed = true
	if not pressed:
		return

	if not _arena_rect().has_point(click_position):
		return
	board_position_clicked.emit(_local_to_world(click_position))
	accept_event()


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


func _local_to_world(local_position: Vector2) -> Vector2:
	var arena := _arena_rect()
	var relative := Vector2(
		(local_position.x - arena.position.x) / arena.size.x,
		(local_position.y - arena.position.y) / arena.size.y
	)
	return world_bounds.position + Vector2(relative.x * world_bounds.size.x, relative.y * world_bounds.size.y)


func _unit_position(snapshot: Dictionary) -> Vector2:
	var value: Variant = snapshot.get("position", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _display_local_position(unit_id: String, snapshot: Dictionary) -> Vector2:
	if _current_physics_positions.has(unit_id):
		var current: Vector2 = _current_physics_positions[unit_id]
		var previous: Vector2 = _previous_physics_positions.get(unit_id, current)
		return _world_to_local(previous.lerp(current, _render_interpolation_fraction))
	return _world_to_local(_unit_position(snapshot))


func _actual_local_position(unit_id: String, snapshot: Dictionary) -> Vector2:
	var actual: Vector2 = _current_physics_positions.get(unit_id, _unit_position(snapshot))
	return _world_to_local(actual)


func _vector_from_variant(value: Variant) -> Vector2:
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
