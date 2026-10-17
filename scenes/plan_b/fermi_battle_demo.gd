extends Control

## PB-01 独立试玩界面：组合战斗 Host、临时词库、棋子模拟与点击棋盘。

const ARENA_SCRIPT: Script = preload("res://scenes/plan_b/fermi_battle_arena.gd")
const PANEL_COLOR: Color = Color("#222a39")
const PANEL_HIGHLIGHT: Color = Color("#2d394d")
const TEXT_COLOR: Color = Color("#f1f4fa")
const MUTED_TEXT_COLOR: Color = Color("#aeb8ca")
const PLAYER_COLOR: Color = Color("#54d7b0")
const OPPONENT_COLOR: Color = Color("#ff876f")
const NEUTRAL_COLOR: Color = Color("#b6bfd1")

var _host: PlanBBattleHost
var _arena: PlanBFermiBattleArena
var _player_count_label: Label
var _opponent_count_label: Label
var _neutral_count_label: Label
var _total_count_label: Label
var _pk_label: Label
var _tier_label: Label
var _status_label: Label
var _feed_label: Label
var _pk_fill: ColorRect
var _start_button: Button
var _pause_button: Button
var _restart_button: Button
var _word_buttons: Array[Button] = []
var _selected_word_id: String = ""
var _selected_unit_id: String = ""
var _refresh_elapsed: float = 0.0
var _recent_events: Array[String] = []


func _ready() -> void:
	# 使用固定宽屏原型布局；正式移动端布局由 PB-04 后续接手。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host = $BattleHost
	_build_layout()
	_host.pk_changed.connect(_on_pk_changed)
	_host.tier_changed.connect(_on_tier_changed)
	_host.battle_ended.connect(_on_battle_ended)
	_host.battle_state_changed.connect(_on_battle_state_changed)
	_host.publish_result.connect(_on_publish_result)
	_host.unit_changed.connect(_on_unit_changed)
	_host.unit_spawned.connect(_on_unit_spawned)
	_host.unit_despawned.connect(_on_unit_despawned)
	_arena.arena_pressed.connect(_on_arena_pressed)
	_refresh_words()
	_refresh_hud()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.1:
		return
	_refresh_elapsed = 0.0
	_refresh_hud()


func _build_layout() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1920.0, 1080.0)
	background.color = Color("#121722")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_add_panel(Rect2(32.0, 116.0, 320.0, 642.0), PANEL_COLOR)
	_add_panel(Rect2(372.0, 116.0, 1144.0, 642.0), PANEL_COLOR)
	_add_panel(Rect2(1536.0, 116.0, 352.0, 642.0), PANEL_COLOR)
	_add_panel(Rect2(372.0, 780.0, 1516.0, 270.0), PANEL_COLOR)

	_add_label("费米直播间 · 独立战斗原型", Vector2(40.0, 25.0), Vector2(850.0, 52.0), 32, TEXT_COLOR)
	_add_label(
		"PB-01 联调场景  ·  临时 A/B/C/D 接口  ·  PK 只按实时阵营人数结算",
		Vector2(42.0, 74.0), Vector2(920.0, 30.0), 17, MUTED_TEXT_COLOR
	)

	_start_button = _add_button("开始战斗", Rect2(1234.0, 32.0, 184.0, 58.0))
	_pause_button = _add_button("暂停", Rect2(1432.0, 32.0, 184.0, 58.0))
	_restart_button = _add_button("重开", Rect2(1630.0, 32.0, 184.0, 58.0))
	_start_button.pressed.connect(_on_start_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)

	_add_label("PK · 玩家胜率推进", Vector2(56.0, 142.0), Vector2(270.0, 36.0), 20, TEXT_COLOR)
	_pk_label = _add_label("50.00%", Vector2(56.0, 190.0), Vector2(260.0, 56.0), 38, PLAYER_COLOR)
	var pk_track := ColorRect.new()
	pk_track.position = Vector2(56.0, 254.0)
	pk_track.size = Vector2(260.0, 22.0)
	pk_track.color = Color("#11151d")
	pk_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pk_track)
	_pk_fill = ColorRect.new()
	_pk_fill.position = pk_track.position
	_pk_fill.size = Vector2(130.0, 22.0)
	_pk_fill.color = PLAYER_COLOR
	_pk_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pk_fill)
	var mid_marker := ColorRect.new()
	mid_marker.position = Vector2(184.0, 251.0)
	mid_marker.size = Vector2(3.0, 28.0)
	mid_marker.color = Color("#f1f4fa")
	mid_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid_marker)
	_add_label("0% 失败", Vector2(56.0, 280.0), Vector2(118.0, 25.0), 14, MUTED_TEXT_COLOR)
	_add_label("100% 进入矛盾", Vector2(174.0, 280.0), Vector2(142.0, 25.0), 14, MUTED_TEXT_COLOR)

	_add_label("场上棋子", Vector2(56.0, 342.0), Vector2(260.0, 34.0), 20, TEXT_COLOR)
	_player_count_label = _add_label("我方信徒  0", Vector2(58.0, 392.0), Vector2(260.0, 32.0), 18, PLAYER_COLOR)
	_opponent_count_label = _add_label("费米粉丝  0", Vector2(58.0, 438.0), Vector2(260.0, 32.0), 18, OPPONENT_COLOR)
	_neutral_count_label = _add_label("中立观众  0", Vector2(58.0, 484.0), Vector2(260.0, 32.0), 18, NEUTRAL_COLOR)
	_total_count_label = _add_label("总人数  0 / 96", Vector2(58.0, 530.0), Vector2(260.0, 30.0), 16, MUTED_TEXT_COLOR)
	_tier_label = _add_label("临时档位  T0", Vector2(58.0, 604.0), Vector2(260.0, 34.0), 20, Color("#ffe28a"))
	_add_label("档位读取现有 08 Tier Catalog\n只显示数值区间，不接正式剧情演出。", Vector2(58.0, 648.0), Vector2(255.0, 66.0), 14, MUTED_TEXT_COLOR)

	_arena = ARENA_SCRIPT.new()
	_arena.position = Vector2(384.0, 128.0)
	_arena.size = Vector2(1120.0, 618.0)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_arena)
	_arena.set_world_origin(_arena.global_position)
	_add_label("战斗区 · 点中立观众完成播种", Vector2(400.0, 134.0), Vector2(720.0, 30.0), 16, MUTED_TEXT_COLOR)

	_add_label("临时属性克制", Vector2(1560.0, 142.0), Vector2(290.0, 32.0), 20, TEXT_COLOR)
	_add_label("A 克 B   ·   B 克 C\nC 克 A   ·   同属性只弹开", Vector2(1560.0, 188.0), Vector2(288.0, 62.0), 17, MUTED_TEXT_COLOR)
	_add_label("强度决定合法感染概率", Vector2(1560.0, 276.0), Vector2(288.0, 32.0), 17, TEXT_COLOR)
	_add_label("强1  20%     强2  35%\n强3  50%     中立只计人数", Vector2(1560.0, 320.0), Vector2(288.0, 58.0), 16, MUTED_TEXT_COLOR)
	_add_label("最近战斗事实", Vector2(1560.0, 406.0), Vector2(288.0, 32.0), 19, TEXT_COLOR)
	_feed_label = _add_label("等待开场……", Vector2(1560.0, 450.0), Vector2(288.0, 246.0), 15, MUTED_TEXT_COLOR)

	_add_label("选择一句话，再点击棋盘中的中立观众", Vector2(400.0, 796.0), Vector2(920.0, 34.0), 20, TEXT_COLOR)
	_status_label = _add_label("开始后，费米会按冷却自动发表。", Vector2(400.0, 836.0), Vector2(1440.0, 30.0), 15, MUTED_TEXT_COLOR)


func _add_panel(rect: Rect2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)


func _add_label(
	text_value: String, position: Vector2, label_size: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _add_button(text_value: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 18)
	add_child(button)
	return button


func _refresh_words() -> void:
	for button: Button in _word_buttons:
		button.queue_free()
	_word_buttons.clear()
	var available_ids: Array[String] = _host.get_available_word_ids("player")
	for index: int in range(available_ids.size()):
		var word_id: String = available_ids[index]
		var definition: Dictionary = _host.get_word_definition(word_id)
		var word_text: String = String(definition.get("text", word_id))
		var battle_type: String = String(definition.get("battle_type", ""))
		var strength: int = int(definition.get("strength", 1))
		var button: Button = _add_button(
			"%s  ·  %s / 强%d" % [word_text, battle_type, strength],
			Rect2(400.0 + float(index) * 490.0, 884.0, 468.0, 116.0)
		)
		button.set_meta("word_id", word_id)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_on_word_selected.bind(word_id))
		button.modulate = Color("#ffe28a") if word_id == _selected_word_id else Color.WHITE
		_word_buttons.append(button)
	if available_ids.is_empty():
		_status_label.text = "本局玩家预制话语已用完。"


func _refresh_hud() -> void:
	if _host == null or _arena == null:
		return
	var counts: Dictionary = _host.get_faction_counts()
	var player_count: int = int(counts.get("player", 0))
	var opponent_count: int = int(counts.get("opponent", 0))
	var neutral_count: int = int(counts.get("neutral", 0))
	var total_count: int = player_count + opponent_count + neutral_count
	var pk: float = _host.get_pk()
	_player_count_label.text = "我方信徒  %d" % player_count
	_opponent_count_label.text = "费米粉丝  %d" % opponent_count
	_neutral_count_label.text = "中立观众  %d" % neutral_count
	_total_count_label.text = "总人数  %d / 96" % total_count
	_pk_label.text = "%.2f%%" % pk
	_pk_fill.size.x = 260.0 * pk / 100.0
	_tier_label.text = "临时档位  T%d" % _host.get_current_tier()
	var state: StringName = _host.get_battle_state()
	_start_button.disabled = state == &"running" or state == &"paused"
	_start_button.text = "再开一局" if state == &"ended" else "开始战斗"
	_pause_button.disabled = state != &"running" and state != &"paused"
	_pause_button.text = "继续" if state == &"paused" else "暂停"
	for word_button: Button in _word_buttons:
		word_button.disabled = state != &"running" or _host.get_publish_cooldown_remaining("player") > 0.0
	_arena.set_battle_snapshot(_host.get_unit_snapshots(), _selected_unit_id, state != &"idle")
	_feed_label.text = "\n".join(_recent_events)


func _on_start_pressed() -> void:
	_host.start_battle(_arena.size, _arena.global_position)
	_status_label.text = "选择一句话，再点灰色中立观众；每次成功发言只会播种一名观众。"
	_push_event("战斗开始：PK 50%，中立76、费米2。")
	_refresh_hud()


func _on_pause_pressed() -> void:
	if _host.get_battle_state() == &"running":
		_host.pause_battle()
	else:
		_host.resume_battle()
	_refresh_hud()


func _on_restart_pressed() -> void:
	_host.restart_battle(_arena.size, _arena.global_position)
	_selected_unit_id = ""
	_selected_word_id = ""
	_status_label.text = "新一局开始。选择一句话，再点灰色中立观众。"
	_refresh_words()
	_push_event("战斗已重开：顺序号、冷却、词库与PK均重置。")
	_refresh_hud()


func _on_word_selected(word_id: String) -> void:
	_selected_word_id = word_id
	var definition: Dictionary = _host.get_word_definition(word_id)
	_status_label.text = "已选：%s。接着点击一个中立观众。" % String(definition.get("text", word_id))
	for index: int in range(_word_buttons.size()):
		var is_selected: bool = String(_word_buttons[index].get_meta("word_id", "")) == word_id
		_word_buttons[index].modulate = Color("#ffe28a") if is_selected else Color.WHITE


func _on_arena_pressed(position: Vector2) -> void:
	if _host.get_battle_state() != &"running":
		_status_label.text = "请先开始或继续战斗。"
		return
	var neutral_unit_id: Variant = _host.get_neutral_unit_at(_arena.global_position + position)
	if str(neutral_unit_id).is_empty():
		_status_label.text = "这个位置没有可播种的中立观众。"
		return
	_selected_unit_id = str(neutral_unit_id)
	if _selected_word_id.is_empty():
		_status_label.text = "已选中 %s；先选一句预制话语，再点击该观众。" % str(neutral_unit_id)
		_refresh_hud()
		return
	var result: Dictionary = _host.publish_word("player", _selected_word_id, neutral_unit_id)
	if bool(result.get("ok", false)):
		var order: int = int(result.get("word_order", 0))
		_status_label.text = "播种成功：%s · 全局 word_order=%d。" % [_selected_word_id, order]
		_selected_word_id = ""
		_refresh_words()
	else:
		_status_label.text = "发表失败：%s。失败不会占用话语、冷却或顺序号。" % String(result.get("reason", "unknown"))
	_refresh_hud()


func _on_pk_changed(_value: float) -> void:
	_refresh_hud()


func _on_tier_changed(current_tier: int) -> void:
	_tier_label.text = "临时档位  T%d" % current_tier
	_push_event("PK 跨档：进入临时 T%d。" % current_tier)


func _on_battle_ended(result: StringName) -> void:
	if result == &"failed":
		_status_label.text = "PK 降至 0%：本场失败事实已发出。可以重开。"
		_push_event("本场结束：PK 归零。")
	else:
		_status_label.text = "PK 达到 100%：进入矛盾阶段事实已发出。可以重开。"
		_push_event("本场结束：PK 满值，等待矛盾阶段接入。")
	_refresh_hud()


func _on_battle_state_changed(state: StringName) -> void:
	if state == &"paused":
		_status_label.text = "战斗已暂停，棋子移动、碰撞和 PK 采样均已冻结。"
	elif state == &"running":
		_status_label.text = "战斗运行中。"
	_refresh_hud()


func _on_publish_result(team: String, word_id: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var side: String = "我方" if team == "player" else "费米"
	_push_event("%s发表 %s · 顺序 %d。" % [side, word_id, int(result.get("word_order", 0))])
	if team == "opponent":
		_refresh_hud()


func _on_unit_changed(unit_id: String, reason: String) -> void:
	match reason:
		"seed":
			_push_event("%s 成为新信徒。" % unit_id)
		"convert":
			_push_event("%s 经接触转化阵营。" % unit_id)
		"relay":
			_push_event("%s 通过同阵营接触改口。" % unit_id)
	_refresh_hud()


func _on_unit_spawned(_unit_id: String) -> void:
	if not _recent_events.is_empty() and _recent_events[0].begins_with("战斗开始"):
		_refresh_hud()


func _on_unit_despawned(_unit_id: String) -> void:
	_refresh_hud()


func _push_event(message: String) -> void:
	_recent_events.push_front(message)
	while _recent_events.size() > 6:
		_recent_events.pop_back()
	if _feed_label != null:
		_feed_label.text = "\n".join(_recent_events)
