extends Control

signal publish_result(word_id: String, unit_id: String, succeeded: bool)

const UnitFieldScript = preload("res://ui/plan_b/plan_b_unit_field.gd")
const COLOR_PLAYER := Color("#50c7ff")
const COLOR_OPPONENT := Color("#ff9f68")
const COLOR_NEUTRAL := Color("#92a2ad")
const COLOR_TEXT := Color("#eef5f6")
const COLOR_MUTED := Color("#91a4ae")
const COLOR_PANEL := Color("#101f29")

class TouchReviewOverlay:
	extends Control

	func _draw() -> void:
		# 只在 20:9 审核场景显示拇指落点，标出潜在遮挡，不进入正式游戏界面。
		var tint := Color(1.0, 0.67, 0.28, 0.15)
		var border := Color(1.0, 0.73, 0.38, 0.56)
		var left := Vector2(90.0, size.y - 78.0)
		var right := Vector2(size.x - 90.0, size.y - 78.0)
		for center in [left, right]:
			draw_circle(center, 48.0, tint)
			draw_arc(center, 48.0, 0.0, TAU, 36, border, 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(24.0, size.y - 16.0), "触控热区示意", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffd6aa"))

var _battle_host: Object
var _unit_source: Object
var _word_catalog: Object
var _event_source: Object
var _word_definitions: Array = []
var _word_text_by_id: Dictionary = {}
var _used_word_ids: Dictionary = {}
var _counts: Dictionary = {"player": 0, "opponent": 0, "neutral": 0}
var _snapshots: Array = []
var _selected_word_id := ""
var _battle_over := false
var _pk_value := 50.0
var _tier_label := "T—"
var _cooldown_remaining := 0.0
var _status_text := "先选一句，再点击场内中立观众。"
var _status_kind := "info"
var _event_lines: Array[String] = []
var _density_profile := "clear"
var _review_source_label := "实时战斗"
var _touch_overlay: Control

var _field
var _word_list: VBoxContainer
var _word_scroll: ScrollContainer
var _selected_phrase_label: Label
var _selected_word_meta: Label
var _status_label: Label
var _step_label: Label
var _pk_value_label: Label
var _tier_value_label: Label
var _pk_bar: ProgressBar
var _player_count_label: Label
var _opponent_count_label: Label
var _neutral_count_label: Label
var _left_total_label: Label
var _arena_total_label: Label
var _player_phrase_chip: Label
var _opponent_phrase_chip: Label
var _player_phrase_summary: Label
var _opponent_phrase_summary: Label
var _event_label: Label
var _word_buttons: Dictionary = {}
var _density_clear_button: Button
var _density_compact_button: Button
var _source_label: Label


func _ready() -> void:
	# 本组件只呈现战斗所有者提供的事实，并把玩家输入交给 A 的统一发表入口。
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_view()
	_refresh_sources()
	_refresh_view()


func _process(_delta: float) -> void:
	_refresh_sources()
	_refresh_view()


func bind_sources(battle_host: Object, unit_source: Object, word_catalog: Object = null) -> void:
	# A 拥有发表/PK；B 拥有棋子与人数；C 只读查询词条。UI 不复制业务真相。
	_disconnect_sources()
	_battle_host = battle_host
	_unit_source = unit_source
	_word_catalog = word_catalog
	_event_source = _battle_host if _has_signal(_battle_host, "unit_changed") else _unit_source
	_connect_signal(_battle_host, "pk_changed", Callable(self, "_on_pk_changed"))
	_connect_signal(_battle_host, "tier_changed", Callable(self, "_on_tier_changed"))
	_connect_signal(_battle_host, "battle_ended", Callable(self, "_on_battle_ended"))
	_connect_signal(_event_source, "unit_changed", Callable(self, "_on_unit_changed"))
	_connect_signal(_event_source, "unit_spawned", Callable(self, "_on_unit_spawned"))
	_connect_signal(_event_source, "unit_despawned", Callable(self, "_on_unit_despawned"))
	_connect_signal(_unit_source, "contact_resolved", Callable(self, "_on_contact_resolved"))
	_refresh_sources()
	_refresh_view()


func set_word_definitions(definitions: Array) -> void:
	# C 交付只读词条快照；界面不从正式词库自行拼装原型句子。
	_word_definitions.clear()
	_word_text_by_id.clear()
	for value in definitions:
		if not value is Dictionary:
			continue
		var definition: Dictionary = value.duplicate(true)
		var word_id := str(definition.get("word_id", ""))
		if word_id.is_empty():
			continue
		_word_definitions.append(definition)
		_word_text_by_id[word_id] = str(definition.get("text", ""))
	if _field != null:
		_field.set_word_texts(_word_text_by_id)
	_rebuild_word_list()
	_refresh_view()


func set_world_bounds(bounds: Rect2) -> void:
	if _field != null:
		_field.set_world_bounds(bounds)


func set_battle_tier(tier: int) -> void:
	# 档位只接受 A 提供的临时事实；UI 不按 PK 阈值自行计算。
	_tier_label = "T%d" % tier
	_refresh_view()


func set_published_word_ids(word_ids: Array) -> void:
	# 允许 A 用其权威记录刷新已发表状态；本地成功回执只用于即时反馈。
	var next_used_ids: Dictionary = {}
	for value in word_ids:
		next_used_ids[str(value)] = true
	var changed := next_used_ids.size() != _used_word_ids.size()
	if not changed:
		for word_id in next_used_ids:
			if not _used_word_ids.has(word_id):
				changed = true
				break
	if not changed:
		return
	_used_word_ids = next_used_ids
	if _used_word_ids.has(_selected_word_id):
		_selected_word_id = ""
		if _field != null:
			_field.set_selected_unit("")
	_rebuild_word_list()
	_refresh_view()


func set_publish_cooldown_remaining(seconds: float) -> void:
	# 冷却时间来自 A；UI 不维护第二套游戏计时。
	_cooldown_remaining = maxf(0.0, seconds)
	_refresh_view()


func set_review_source_label(value: String) -> void:
	_review_source_label = value
	if _source_label != null:
		_source_label.text = _review_source_label


func set_density_profile(profile: String) -> void:
	_on_density_pressed(profile)


func set_touch_review_mode(enabled: bool) -> void:
	if enabled and not is_instance_valid(_touch_overlay):
		_touch_overlay = TouchReviewOverlay.new()
		_touch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_touch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_touch_overlay.z_index = 20
		add_child(_touch_overlay)
	elif not enabled and is_instance_valid(_touch_overlay):
		_touch_overlay.queue_free()
		_touch_overlay = null

func _build_view() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071018")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24 if side == "left" or side == "right" else 18)
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(outer)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	outer.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_columns())
	page.add_child(_build_footer())


func _build_header() -> Control:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 68.0
	header.add_theme_stylebox_override("panel", _panel_style(Color("#0d1a24"), Color("#28414d"), 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	var mark := _label("LIVE", 14, Color("#73e2ff"))
	mark.custom_minimum_size = Vector2(52.0, 0.0)
	row.add_child(mark)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 1)
	row.add_child(heading)
	heading.add_child(_label("PLAN B  ·  观众复读战", 25, COLOR_TEXT))
	heading.add_child(_label("选一句话，点中立观众；看阵营和话语沿场地扩散。", 14, COLOR_MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_source_label = _label(_review_source_label, 14, Color("#b6c7cf"))
	_source_label.name = "SourceLabel"
	row.add_child(_source_label)
	return header


func _build_columns() -> Control:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 292.0
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	_build_pk_card(left)
	_build_counts_card(left)
	_build_faction_card(left)
	_build_events_card(left)

	var middle := _build_arena_column()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(middle)

	var right := _build_word_column()
	right.custom_minimum_size.x = 405.0
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	return columns


func _build_pk_card(parent: Container) -> void:
	var body := _card(parent, 0.0, Color("#132734"), Color("#2a5160"))
	body.add_child(_label("PK · 矛盾势能", 15, COLOR_MUTED))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 8)
	body.add_child(values)
	_pk_value_label = _label("50%", 37, COLOR_TEXT)
	values.add_child(_pk_value_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_child(spacer)
	_tier_value_label = _label("T—", 22, Color("#ffd59b"))
	values.add_child(_tier_value_label)
	_pk_bar = ProgressBar.new()
	_pk_bar.custom_minimum_size.y = 18.0
	_pk_bar.min_value = 0.0
	_pk_bar.max_value = 100.0
	_pk_bar.show_percentage = false
	_pk_bar.add_theme_stylebox_override("background", _panel_style(Color("#243640"), Color("#243640"), 8, 0))
	_pk_bar.add_theme_stylebox_override("fill", _panel_style(Color("#3ebbd9"), Color("#3ebbd9"), 8, 0))
	body.add_child(_pk_bar)
	body.add_child(_label("PK 只读 A 的结算值；临时档位由 A 提供。", 12, COLOR_MUTED))


func _build_counts_card(parent: Container) -> void:
	var body := _card(parent, 0.0, COLOR_PANEL, Color("#233943"))
	body.add_child(_label("场内人数 · 来自棋子快照", 15, COLOR_MUTED))
	_player_count_label = _add_count_row(body, "煲煲信徒", COLOR_PLAYER)
	_opponent_count_label = _add_count_row(body, "费米粉丝", COLOR_OPPONENT)
	_neutral_count_label = _add_count_row(body, "中立观众", COLOR_NEUTRAL)
	_left_total_label = _label("场内合计 0 / 96", 13, Color("#b8c8ce"))
	body.add_child(_left_total_label)


func _add_count_row(parent: Container, title: String, tint: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var dot := _label("●", 13, tint)
	row.add_child(dot)
	var name := _label(title, 14, COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var value := _label("0", 18, COLOR_TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _build_faction_card(parent: Container) -> void:
	var body := _card(parent, 0.0, COLOR_PANEL, Color("#233943"))
	body.add_child(_label("正在复读", 15, COLOR_MUTED))
	body.add_child(_label("煲煲阵营", 12, COLOR_PLAYER))
	_player_phrase_summary = _label("暂无玩家话语", 15, COLOR_TEXT)
	_player_phrase_summary.custom_minimum_size.y = 42.0
	_player_phrase_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_player_phrase_summary)
	body.add_child(_label("费米阵营", 12, COLOR_OPPONENT))
	_opponent_phrase_summary = _label("暂无费米话语", 15, COLOR_TEXT)
	_opponent_phrase_summary.custom_minimum_size.y = 42.0
	_opponent_phrase_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_opponent_phrase_summary)


func _build_events_card(parent: Container) -> void:
	var body := _card(parent, 0.0, COLOR_PANEL, Color("#233943"))
	body.add_child(_label("最近战况", 15, COLOR_MUTED))
	_event_label = _label("等待棋子事件…", 13, Color("#c0d0d5"))
	_event_label.custom_minimum_size.y = 84.0
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_event_label)


func _build_arena_column() -> Control:
	var body := _card(null, 0.0, COLOR_PANEL, Color("#29414c"))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	heading.add_child(_label("实时直播间", 21, COLOR_TEXT))
	_arena_total_label = _label("点击场内有色圆点本身", 13, COLOR_MUTED)
	heading.add_child(_arena_total_label)
	header.add_child(heading)
	_density_clear_button = _density_button("清晰 · 有阵营字母")
	_density_clear_button.pressed.connect(_on_density_pressed.bind("clear"))
	header.add_child(_density_clear_button)
	_density_compact_button = _density_button("紧凑 · 看分布")
	_density_compact_button.pressed.connect(_on_density_pressed.bind("compact"))
	header.add_child(_density_compact_button)

	var phrases := HBoxContainer.new()
	phrases.add_theme_constant_override("separation", 10)
	body.add_child(phrases)
	_player_phrase_chip = _phrase_chip(phrases, "煲煲", COLOR_PLAYER)
	_opponent_phrase_chip = _phrase_chip(phrases, "费米", COLOR_OPPONENT)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	legend.add_child(_label("● N 中立", 13, COLOR_NEUTRAL))
	legend.add_child(_label("● B 煲煲", 13, COLOR_PLAYER))
	legend.add_child(_label("● F 费米", 13, COLOR_OPPONENT))
	var legend_spacer := Control.new()
	legend_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(legend_spacer)
	legend.add_child(_label("细线为上一帧移动", 12, COLOR_MUTED))
	body.add_child(legend)

	_field = UnitFieldScript.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.set_density_profile(_density_profile)
	_field.unit_clicked.connect(_on_unit_clicked)
	_field.empty_field_clicked.connect(_on_empty_field_clicked)
	body.add_child(_field)

	var note := _label("播种 / 转化 / 接力会在目标棋子上分别脉冲；悬停或选中棋子可读当前话语。", 12, COLOR_MUTED)
	body.add_child(note)
	_on_density_pressed(_density_profile)
	return body.get_parent() as Control


func _phrase_chip(parent: Container, team_name: String, tint: Color) -> Label:
	var label := _label(team_name + " · 暂无复读", 13, tint)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 34.0
	parent.add_child(label)
	return label


func _density_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_font_size_override("font_size", 12)
	_style_button(button, false)
	return button


func _build_word_column() -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	header.add_child(_label("① 选一句话", 21, COLOR_TEXT))
	header.add_child(_label("本局每条预制话语只能主动发表一次", 13, COLOR_MUTED))
	body.add_child(header)

	var word_frame := PanelContainer.new()
	word_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	word_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_frame.add_theme_stylebox_override("panel", _panel_style(Color("#0d1922"), Color("#243943"), 14))
	body.add_child(word_frame)
	_word_scroll = ScrollContainer.new()
	_word_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_word_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	word_frame.add_child(_word_scroll)
	_word_list = VBoxContainer.new()
	_word_list.add_theme_constant_override("separation", 8)
	_word_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_word_scroll.add_child(_word_list)

	var selected := _card(body, 0.0, Color("#122633"), Color("#326173"))
	selected.add_child(_label("已选话语", 12, Color("#8ab9c6")))
	_selected_phrase_label = _label("尚未选择", 15, COLOR_TEXT)
	_selected_phrase_label.custom_minimum_size.y = 52.0
	_selected_phrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected.add_child(_selected_phrase_label)
	_selected_word_meta = _label("从上方选一条未发表话语。", 12, COLOR_MUTED)
	selected.add_child(_selected_word_meta)
	var expand_button := Button.new()
	expand_button.text = "展开全文"
	expand_button.custom_minimum_size.y = 40.0
	_style_button(expand_button, false)
	expand_button.pressed.connect(_open_selected_full_text)
	selected.add_child(expand_button)

	var next := _card(body, 0.0, Color("#101e28"), Color("#263b46"))
	_step_label = _label("② 点中立观众", 16, Color("#ffd59b"))
	next.add_child(_step_label)
	_status_label = _label(_status_text, 13, Color("#c2d2d8"))
	_status_label.custom_minimum_size.y = 48.0
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next.add_child(_status_label)
	return body


func _build_footer() -> Control:
	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 42.0
	footer.add_theme_stylebox_override("panel", _panel_style(Color("#0c1720"), Color("#243741"), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	footer.add_child(row)
	row.add_child(_label("操作顺序", 13, Color("#74d6ee")))
	row.add_child(_label("选句 → 点击中立棋子；点空白或已感染棋子会收到原因提示。", 13, COLOR_MUTED))
	return footer


func _card(parent: Container, min_height: float, fill: Color, border: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = min_height
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(fill, border, 13))
	if parent != null:
		parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	return box


func _panel_style(fill: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 15.0
	style.content_margin_top = 12.0
	style.content_margin_right = 15.0
	style.content_margin_bottom = 12.0
	return style


func _label(text_value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style_button(button: Button, selected: bool) -> void:
	var base := Color("#19313d") if selected else Color("#12232d")
	var edge := Color("#65d8f2") if selected else Color("#2b424c")
	button.add_theme_stylebox_override("normal", _panel_style(base, edge, 11))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#203c49"), Color("#71dcf2"), 11))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#244a5a"), Color("#a0edff"), 11))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#141e25"), Color("#29343a"), 11))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#829098"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))


func _rebuild_word_list() -> void:
	if _word_list == null:
		return
	for child in _word_list.get_children():
		_word_list.remove_child(child)
		child.queue_free()
	_word_buttons.clear()
	if _word_definitions.is_empty():
		var empty := _card(_word_list, 80.0, Color("#12232d"), Color("#2b424c"))
		empty.add_child(_label("等待 C 提供预制话语。", 14, COLOR_MUTED))
		return

	for definition in _word_definitions:
		var word_id := str(definition.get("word_id", ""))
		var full_text := str(definition.get("text", ""))
		var strength := int(definition.get("strength", 1))
		var battle_type := str(definition.get("battle_type", ""))
		var used := _used_word_ids.has(word_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 78.0)
		button.tooltip_text = full_text if not used else full_text + "\n已发表：本局不可再次主动使用。"
		button.disabled = used or _battle_over
		_style_button(button, word_id == _selected_word_id and not used)
		var content_margin := MarginContainer.new()
		content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "top", "right", "bottom"]:
			content_margin.add_theme_constant_override("margin_" + side, 12 if side == "left" or side == "right" else 8)
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 3)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var meta := "%s  ·  强度 %d  ·  %s" % ["已发表" if used else "可发表", strength, battle_type if not battle_type.is_empty() else "原型话语"]
		var meta_label := _label(meta, 11, Color("#9aaeb7") if not used else Color("#79888e"))
		contents.add_child(meta_label)
		var text_label := _label(full_text, 15, COLOR_TEXT if not used else Color("#7f8d93"))
		text_label.custom_minimum_size.y = 38.0
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(text_label)
		content_margin.add_child(contents)
		button.add_child(content_margin)
		button.pressed.connect(_on_word_pressed.bind(word_id))
		_word_list.add_child(button)
		_word_buttons[word_id] = button


func _refresh_sources() -> void:
	if is_instance_valid(_battle_host) and _battle_host.has_method("get_pk"):
		_pk_value = clampf(float(_battle_host.call("get_pk")), 0.0, 100.0)
	if _has_method(_battle_host, "get_used_word_ids"):
		var used_ids: Variant = _battle_host.call("get_used_word_ids")
		if used_ids is Array:
			set_published_word_ids(used_ids)
	if _has_method(_battle_host, "get_publish_cooldown_remaining"):
		_cooldown_remaining = maxf(float(_battle_host.call("get_publish_cooldown_remaining", "player")), 0.0)
	if _has_method(_battle_host, "get_current_tier"):
		_tier_label = "T%d" % int(_battle_host.call("get_current_tier"))
	var counts_source: Object = _battle_host if _has_method(_battle_host, "get_faction_counts") else _unit_source
	if is_instance_valid(counts_source) and counts_source.has_method("get_faction_counts"):
		var counts: Variant = counts_source.call("get_faction_counts")
		if counts is Dictionary:
			_counts = counts.duplicate(true)
	var snapshot_source: Object = _battle_host if _has_method(_battle_host, "get_unit_snapshots") else _unit_source
	if is_instance_valid(snapshot_source) and snapshot_source.has_method("get_unit_snapshots"):
		var snapshots: Variant = snapshot_source.call("get_unit_snapshots")
		if snapshots is Array:
			_snapshots = snapshots
			_refresh_missing_word_texts()
		if _field != null:
			_field.set_unit_snapshots(_snapshots)
			_field.set_word_texts(_word_text_by_id)


func _refresh_missing_word_texts() -> void:
	if not is_instance_valid(_word_catalog) or not _word_catalog.has_method("get_word_definition"):
		return
	for unit in _snapshots:
		if not unit is Dictionary:
			continue
		var word_id := str(unit.get("word_id", ""))
		if word_id.is_empty() or _word_text_by_id.has(word_id):
			continue
		var definition: Variant = _word_catalog.call("get_word_definition", word_id)
		if definition is Dictionary:
			_word_text_by_id[word_id] = str(definition.get("text", ""))


func _refresh_view() -> void:
	if _pk_value_label == null:
		return
	_pk_value_label.text = "%.0f%%" % _pk_value
	_pk_bar.value = _pk_value
	_tier_value_label.text = _tier_label
	_player_count_label.text = str(int(_counts.get("player", 0)))
	_opponent_count_label.text = str(int(_counts.get("opponent", 0)))
	_neutral_count_label.text = str(int(_counts.get("neutral", 0)))
	var total := int(_counts.get("player", 0)) + int(_counts.get("opponent", 0)) + int(_counts.get("neutral", 0))
	_left_total_label.text = "场内合计 %d / 96" % total
	_arena_total_label.text = "%d 名观众 · 点击有色圆点本身" % total
	_update_faction_phrases()
	_update_selection_view()
	_update_status_view()
	_update_event_view()


func _update_faction_phrases() -> void:
	var player_phrases := _most_common_words("player", 2)
	var opponent_phrases := _most_common_words("opponent", 2)
	var player_text := "煲煲 · 暂无复读" if player_phrases.is_empty() else "煲煲 · " + _format_phrase_list(player_phrases)
	var opponent_text := "费米 · 暂无复读" if opponent_phrases.is_empty() else "费米 · " + _format_phrase_list(opponent_phrases)
	_player_phrase_summary.text = "暂无玩家话语" if player_phrases.is_empty() else _format_phrase_list(player_phrases)
	_opponent_phrase_summary.text = "暂无费米话语" if opponent_phrases.is_empty() else _format_phrase_list(opponent_phrases)
	_player_phrase_summary.tooltip_text = _format_full_phrase_list(player_phrases)
	_opponent_phrase_summary.tooltip_text = _format_full_phrase_list(opponent_phrases)
	_player_phrase_chip.text = player_text
	_opponent_phrase_chip.text = opponent_text
	_player_phrase_chip.tooltip_text = _format_full_phrase_list(player_phrases)
	_opponent_phrase_chip.tooltip_text = _format_full_phrase_list(opponent_phrases)


func _most_common_words(team: String, limit: int) -> Array:
	var counts: Dictionary = {}
	for unit in _snapshots:
		if not unit is Dictionary or str(unit.get("team", "neutral")) != team:
			continue
		var word_id := str(unit.get("word_id", ""))
		if word_id.is_empty():
			continue
		counts[word_id] = int(counts.get(word_id, 0)) + 1
	var phrases: Array = []
	for _entry_index in range(limit):
		var best_id := ""
		var best_count := 0
		for word_id in counts:
			if int(counts[word_id]) > best_count:
				best_id = str(word_id)
				best_count = int(counts[word_id])
		if best_id.is_empty():
			break
		var fallback := ""
		for unit in _snapshots:
			if str(unit.get("team", "neutral")) == team and str(unit.get("word_id", "")) == best_id:
				fallback = str(unit.get("text", ""))
				break
		var full_text := str(_word_text_by_id.get(best_id, fallback))
		phrases.append({"text": _clip_text(full_text, 14), "full_text": full_text, "count": best_count})
		counts.erase(best_id)
	return phrases


func _format_phrase_list(phrases: Array) -> String:
	var parts: Array[String] = []
	for phrase in phrases:
		parts.append("「%s」×%d" % [str(phrase.get("text", "")), int(phrase.get("count", 0))])
	return "\n".join(parts)


func _format_full_phrase_list(phrases: Array) -> String:
	var parts: Array[String] = []
	for phrase in phrases:
		parts.append("「%s」×%d" % [str(phrase.get("full_text", "")), int(phrase.get("count", 0))])
	return "\n".join(parts)


func _update_selection_view() -> void:
	if _selected_word_id.is_empty():
		_selected_phrase_label.text = "尚未选择"
		_selected_word_meta.text = "从上方选一条未发表话语。"
		return
	var definition := _definition_for(_selected_word_id)
	_selected_phrase_label.text = str(definition.get("text", _selected_word_id))
	_selected_phrase_label.tooltip_text = str(definition.get("text", ""))
	_selected_word_meta.text = "强度 %d · %s · 点击棋子播种" % [int(definition.get("strength", 1)), str(definition.get("battle_type", "原型话语"))]
	if _word_buttons.has(_selected_word_id):
		_style_button(_word_buttons[_selected_word_id], true)


func _update_status_view() -> void:
	if _battle_over:
		_step_label.text = "战斗已结束"
	elif _selected_word_id.is_empty():
		_step_label.text = "① 先选择一句未发表的话"
	elif int(_counts.get("neutral", 0)) <= 0:
		_step_label.text = "② 暂无中立观众"
	else:
		_step_label.text = "② 点击灰色 N 中立观众"
	var text_value := _status_text
	if _cooldown_remaining > 0.0:
		text_value += "  ·  冷却 %.1f 秒" % _cooldown_remaining
	_status_label.text = text_value
	var tint := Color("#c2d2d8")
	match _status_kind:
		"success":
			tint = Color("#85e7c0")
		"error":
			tint = Color("#ff9c83")
		"warning":
			tint = Color("#ffd38e")
	_status_label.add_theme_color_override("font_color", tint)


func _update_event_view() -> void:
	_event_label.text = "等待棋子事件…" if _event_lines.is_empty() else "\n".join(_event_lines.slice(0, 4))


func _on_word_pressed(word_id: String) -> void:
	if _battle_over:
		_set_status("战斗已经结束，无法继续发表。", "warning")
		return
	if _used_word_ids.has(word_id):
		_set_status("这句话已发表，本局不能再次主动使用。", "warning")
		return
	_selected_word_id = word_id
	_status_kind = "info"
	_status_text = "已选中。下一步点击场地里的灰色 N 中立观众。"
	_rebuild_word_list()
	_refresh_view()


func _on_unit_clicked(unit_id: String, team: String) -> void:
	if _battle_over:
		_set_status("战斗已经结束，无法继续播种。", "warning")
		return
	if _selected_word_id.is_empty():
		_set_status("先从右侧选择一句尚未发表的话。", "warning")
		return
	if team != "neutral":
		_set_status("目标 %s 已属于%s；请点灰色 N 中立观众。" % [unit_id, "煲煲阵营" if team == "player" else "费米阵营"], "error")
		return
	if int(_counts.get("neutral", 0)) <= 0:
		_set_status("当前没有中立观众可供播种；请等待场内变化。", "warning")
		return
	if _battle_host == null or not is_instance_valid(_battle_host) or not _battle_host.has_method("publish_word"):
		_set_status("战斗主控尚未提供 publish_word() 入口。", "error")
		return

	# 只向 A 提交稳定 ID；A 再校验冷却、词条和目标并唯一提交播种。
	var result: Variant = _battle_host.call("publish_word", "player", _selected_word_id, unit_id)
	var succeeded := false
	var reason := ""
	var word_order := 0
	if result is Dictionary:
		succeeded = bool(result.get("ok", false))
		reason = str(result.get("reason", ""))
		word_order = int(result.get("word_order", 0))
	else:
		succeeded = bool(result)
	if not succeeded:
		_set_status(_friendly_failure_reason(reason), "error")
		publish_result.emit(_selected_word_id, unit_id, false)
		return

	var used_id := _selected_word_id
	_used_word_ids[used_id] = true
	_selected_word_id = ""
	_field.set_selected_unit("")
	var published_text := str(_word_text_by_id.get(used_id, used_id))
	var order_suffix := " · 顺序 #%d" % word_order if word_order > 0 else ""
	_set_status("播种成功：%s 已复读「%s」。冷却由战斗主控判定%s" % [unit_id, _clip_text(published_text, 32), order_suffix], "success")
	_field.show_unit_feedback(unit_id, "seed")
	_rebuild_word_list()
	_refresh_view()
	publish_result.emit(used_id, unit_id, true)


func _on_empty_field_clicked() -> void:
	if not _selected_word_id.is_empty():
		_set_status("这里没有中立棋子；请点有色圆点，空白位置不会生成新棋子。", "warning")


func _on_density_pressed(profile: String) -> void:
	_density_profile = "compact" if profile == "compact" else "clear"
	_field.set_density_profile(_density_profile)
	_style_button(_density_clear_button, _density_profile == "clear")
	_style_button(_density_compact_button, _density_profile == "compact")


func _open_selected_full_text() -> void:
	if _selected_word_id.is_empty():
		_set_status("先选中一条话语，再展开全文。", "warning")
		return
	var definition := _definition_for(_selected_word_id)
	var popup := PopupPanel.new()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 300.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#10222c"), Color("#4d8999"), 18, 2))
	popup.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	content.add_child(_label("话语全文 · %s" % _selected_word_id, 16, Color("#75d9f0")))
	var full_text := _label(str(definition.get("text", "")), 22, COLOR_TEXT)
	full_text.custom_minimum_size.y = 180.0
	full_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(full_text)
	var close := Button.new()
	close.text = "返回战场"
	close.custom_minimum_size.y = 46.0
	_style_button(close, false)
	close.pressed.connect(popup.hide)
	content.add_child(close)
	add_child(popup)
	popup.popup_centered(Vector2i(600, 340))
	popup.popup_hide.connect(popup.queue_free, CONNECT_ONE_SHOT)


func _connect_signal(source: Object, signal_name: String, callback: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _has_signal(source: Object, signal_name: String) -> bool:
	return source != null and is_instance_valid(source) and source.has_signal(signal_name)


func _has_method(source: Object, method_name: String) -> bool:
	return source != null and is_instance_valid(source) and source.has_method(method_name)


func _disconnect_sources() -> void:
	_disconnect_signal(_battle_host, "pk_changed", Callable(self, "_on_pk_changed"))
	_disconnect_signal(_battle_host, "tier_changed", Callable(self, "_on_tier_changed"))
	_disconnect_signal(_battle_host, "battle_ended", Callable(self, "_on_battle_ended"))
	_disconnect_signal(_event_source, "unit_changed", Callable(self, "_on_unit_changed"))
	_disconnect_signal(_event_source, "unit_spawned", Callable(self, "_on_unit_spawned"))
	_disconnect_signal(_event_source, "unit_despawned", Callable(self, "_on_unit_despawned"))
	_disconnect_signal(_unit_source, "contact_resolved", Callable(self, "_on_contact_resolved"))
	_event_source = null


func _disconnect_signal(source: Object, signal_name: String, callback: Callable) -> void:
	if source != null and is_instance_valid(source) and source.has_signal(signal_name) and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _on_pk_changed(value: float) -> void:
	_pk_value = clampf(value, 0.0, 100.0)
	_refresh_view()


func _on_tier_changed(current_tier: int) -> void:
	set_battle_tier(current_tier)


func _on_battle_ended(result: Variant) -> void:
	_battle_over = true
	_selected_word_id = ""
	_field.set_selected_unit("")
	var result_text := str(result)
	if result is Dictionary:
		result_text = str(result.get("message", result.get("result", result_text)))
	_set_status("战斗结束 · %s" % result_text, "warning")
	_rebuild_word_list()
	_refresh_view()


func show_counterattack_windup(request: Dictionary) -> void:
	var target_id := str(request.get("target_unit_id", ""))
	var skill_id := str(request.get("skill_id", request.get("effect_id", "费米反击")))
	var windup := float(request.get("pre_windup_seconds", 0.0))
	if not target_id.is_empty():
		_field.show_unit_feedback(target_id, "counterattack")
	_add_event("[费米反击前摇] %s · 目标 %s · %.1f 秒" % [skill_id, target_id, windup])
	_set_status("费米正在准备反击；请留意棋子上的紫色脉冲。", "warning")


func show_counterattack_result(result: Dictionary) -> void:
	var target_id := str(result.get("target_unit_id", ""))
	var skill_id := str(result.get("skill_id", result.get("effect_id", "费米反击")))
	var applied := bool(result.get("applied", false))
	if not target_id.is_empty():
		_field.show_unit_feedback(target_id, "counterattack")
	_add_event("[%s] %s · %s" % ["费米反击生效" if applied else "费米反击未生效", skill_id, target_id])
	_set_status("费米反击已结算：%s。" % ("生效" if applied else "未生效"), "warning" if applied else "info")


func _on_contact_resolved(first_unit_id: Variant, second_unit_id: Variant, outcome: StringName) -> void:
	var first_id := str(first_unit_id)
	var second_id := str(second_unit_id)
	var outcome_text := ""
	match outcome:
		&"neutral_bounce":
			outcome_text = "中立观众弹开"
		&"same_team_bounce":
			outcome_text = "同阵营弹开"
		&"same_type_bounce":
			outcome_text = "同属性弹开"
		&"no_counter_bounce":
			outcome_text = "无克制，双方弹开"
		&"converted":
			outcome_text = "感染成功"
		&"infection_failed":
			outcome_text = "感染未成功"
		_:
			outcome_text = str(outcome)
	_field.show_contact_feedback(first_id, second_id, str(outcome))
	_add_event("[碰撞] %s ↔ %s · %s" % [first_id, second_id, outcome_text])


func _on_unit_changed(unit_id: String, reason: String) -> void:
	var message := ""
	match reason:
		"seed":
			message = "[播种] %s 开始复读" % unit_id
		"convert":
			message = "[碰撞·阵营转化] %s 加入新阵营" % unit_id
		"relay":
			message = "[碰撞·同阵营接力] %s 接过较新的话" % unit_id
		_:
			message = "[棋子更新] %s · %s" % [unit_id, reason]
	_field.show_unit_feedback(unit_id, reason)
	_add_event(message)
	_refresh_sources()
	_refresh_view()


func _on_unit_spawned(unit_id: String) -> void:
	_add_event("[入场] 新观众 %s 加入" % unit_id)


func _on_unit_despawned(unit_id: String) -> void:
	_add_event("[离场] 观众 %s 离开" % unit_id)


func _add_event(message: String) -> void:
	_event_lines.push_front(message)
	while _event_lines.size() > 4:
		_event_lines.pop_back()
	_update_event_view()


func _set_status(message: String, kind: String) -> void:
	_status_text = message
	_status_kind = kind
	_update_status_view()


func _friendly_failure_reason(reason: String) -> String:
	var normalized := reason.to_lower()
	if normalized.contains("cool"):
		return "还在发言冷却中；请稍候再点，失败不会消耗话语。"
	if normalized.contains("used") or normalized.contains("published"):
		return "这句话已经发表，本局不能再次主动使用。"
	if normalized.contains("neutral") or normalized.contains("target"):
		return "目标已经改变或不再中立；请选择场上另一名中立观众。"
	if normalized.contains("battle") or normalized.contains("ended"):
		return "当前战斗无法发表；请等待战斗主控状态更新。"
	return "发表未完成：%s" % reason if not reason.is_empty() else "发表未完成；请重新选择目标。"


func _definition_for(word_id: String) -> Dictionary:
	for definition in _word_definitions:
		if str(definition.get("word_id", "")) == word_id:
			return definition
	return {}


func _clip_text(value: String, max_characters: int) -> String:
	return value if value.length() <= max_characters else value.left(max_characters - 1) + "…"
