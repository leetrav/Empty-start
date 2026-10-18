extends Control

signal publish_result(word_id: String, unit_id: String, succeeded: bool)
signal word_selected(word_id: String)
signal publish_requested(word_id: String, unit_id: String)
signal dialogue_sequence_completed(sequence_id: StringName, side: int)
signal dialogue_bubble_presented(side: int, event_id: StringName, text: String)
signal tier_breakthrough_finished(previous_tier: int, current_tier: int, completed: bool)
signal failure_presentation_finished
signal opponent_result_presentation_finished(broken: bool)
signal restart_requested

const UnitFieldScript = preload("res://ui/plan_b/plan_b_unit_field.gd")
const StreamerPanelScript = preload("res://ui/plan_b/plan_b_streamer_panel.gd")
const PK_BAR_SKIN_SCENE: PackedScene = preload("res://systems/presentation/pk_bar_skin.tscn")
const AIM_RETICLE_SCENE: PackedScene = preload("res://systems/combat_attack/aim_reticle.tscn")
const StageArrowScript = preload("res://systems/presentation/stage_arrow_fx.gd")
const DialogueQueueScript = preload("res://ui/streamer_bubble_dialogue/streamer_bubble_dialogue_queue.gd")
const COLOR_PLAYER := Color("#50c7ff")
const COLOR_OPPONENT := Color("#ff9f68")
const COLOR_NEUTRAL := Color("#92a2ad")
const COLOR_TEXT := Color("#eef5f6")
const COLOR_MUTED := Color("#91a4ae")
const BOARD_FALLBACK_BOUNDS := Rect2(Vector2(448.0, 72.0), Vector2(1024.0, 828.0))

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
var _player_display_name := "玩家主播"
var _opponent_display_name := "当前主播"
var _player_fan_group_name := "粉丝团"
var _opponent_fan_group_name := "粉丝团"
var _touch_overlay: Control
var _sync_elapsed := 0.0
var _hand_remaining_count := 0
var _hand_words: Array[Dictionary] = []
var _hand_from_c := false
var _pending_publish := false
var _pending_word_id := ""
var _pending_unit_id := ""
var _battle_tier := 0
var _paradox_stage_active := false
var _final_oracle_stage_active := false
var _actual_player_pk := 0.5
var _opponent_connected := true
var _stage_transition_active := false
var _stage_transition_previous_tier := -1
var _stage_transition_current_tier := -1
var _failure_presentation_active := false
var _feedback_seconds := 0.0
var _counterattack_seconds := 0.0
var _portrait_attack: AttackChargeInput
var _last_player_echo := ""
var _last_opponent_echo := ""
var _last_hand_status_tint := Color.TRANSPARENT

var _field
var _player_panel: Control
var _opponent_panel: Control
var _dialogue_queue: Node
var _board_overlay: Control
var _stage_arrow: Control
var _aim_reticle: AimReticle
var _pk_bar_skin: Control
var _pk_value_label: Label
var _tier_value_label: Label
var _pk_bar: ProgressBar
var _counts_label: Label
var _population_ribbon: Control
var _event_label: Label
var _paradox_stage_label: Label
var _word_hand_panel: Control
var _paradox_footer: Control
var _oracle_footer: Control
var _hand_buttons: Array[Button] = []
var _hand_phrase_labels: Array[Label] = []
var _hand_meta_labels: Array[Label] = []
var _hand_button_selected_state: Array[bool] = []
var _hand_button_disabled_state: Array[bool] = []
var _hand_status_label: Label
var _hand_count_label: Label
var _counterattack_label: Label


func _ready() -> void:
	# 本组件只呈现战斗所有者提供的事实，并把玩家输入交给 A 的统一发表入口。
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_view()
	_dialogue_queue = DialogueQueueScript.new()
	_dialogue_queue.name = "BubbleDialogueQueue"
	_dialogue_queue.call("configure", 3, Callable(self, "show_dialogue_bubble"), Callable(self, "_clear_bubble_stack"))
	_dialogue_queue.connect("sequence_completed", Callable(self, "_on_dialogue_sequence_completed"))
	add_child(_dialogue_queue)
	_refresh_sources()
	set_opponent_portrait_connected(_battle_tier > 0)
	_refresh_view()



func _process(delta: float) -> void:
	_feedback_seconds = maxf(0.0, _feedback_seconds - delta)
	if _feedback_seconds <= 0.0 and _event_label != null:
		_event_label.modulate.a = 0.0
	_counterattack_seconds = maxf(0.0, _counterattack_seconds - delta)
	if _counterattack_seconds <= 0.0 and _counterattack_label != null:
		_counterattack_label.visible = false
	_sync_elapsed += delta
	if _sync_elapsed < 0.1:
		return
	_sync_elapsed = 0.0
	_refresh_sources()
	_refresh_view()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var slot := -1
	match event.keycode:
		KEY_1:
			slot = 0
		KEY_2:
			slot = 1
		KEY_3:
			slot = 2
		KEY_4:
			slot = 3
	if slot >= 0:
		_select_hand_slot(slot)
		get_viewport().set_input_as_handled()


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
	if not _hand_from_c:
		_rebuild_fallback_hand()
	_refresh_hand_view()
	_refresh_view()


func set_word_hand(hand: Array, remaining_count: int = 0) -> void:
	# C 提供当前手牌快照与词池余量；D 只显示和选择，不抽取、不补牌。
	_hand_from_c = true
	_hand_remaining_count = maxi(remaining_count, 0)
	_hand_words.clear()
	for value in hand:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value.duplicate(true)
		var word_id := _entry_word_id(entry)
		if word_id.is_empty():
			continue
		if not entry.has("text") and _word_text_by_id.has(word_id):
			entry["text"] = _word_text_by_id[word_id]
		if entry.has("text"):
			_word_text_by_id[word_id] = str(entry["text"])
		_hand_words.append(entry)
		if _hand_words.size() >= 4:
			break
	_refresh_hand_view()
	if _field != null:
		_field.set_word_texts(_word_text_by_id)
	_refresh_view()


func set_world_bounds(bounds: Rect2) -> void:
	if _field != null:
		_field.set_world_bounds(bounds)


func get_board_world_bounds() -> Rect2:
	# 公开棋盘逻辑画布矩形供 A 原样交给 B；布局尚未完成时返回设计尺寸。
	if is_instance_valid(_field) and _field.is_inside_tree():
		var board_rect: Rect2 = _field.get_global_rect()
		var expected_origin_distance := board_rect.position.distance_to(BOARD_FALLBACK_BOUNDS.position)
		if board_rect.size.x > 0.0 and board_rect.size.y > 0.0 and expected_origin_distance < 1.0:
			return board_rect
		# Container 尚未完成首轮布局时坐标常暂留 (0, 0)，返回固定设计矩形给开局初始化。
	return BOARD_FALLBACK_BOUNDS


func set_battle_tier(tier: int) -> void:
	# 档位只接受 A 提供的临时事实；UI 不按 PK 阈值自行计算。
	var tier_changed := maxi(tier, 0) != _battle_tier
	_battle_tier = maxi(tier, 0)
	_tier_label = "T%d" % _battle_tier
	if _tier_value_label != null:
		_tier_value_label.text = "T6 · 矛盾" if _paradox_stage_active else _tier_label
	if _opponent_panel != null:
		_opponent_panel.call("set_tier", _battle_tier)
		if tier_changed:
			set_opponent_portrait_connected(_battle_tier > 0)
	if _pk_bar_skin != null:
		_pk_bar_skin.call("set_display_state", _actual_player_pk, _battle_tier, _paradox_stage_active)
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
	if not _hand_from_c:
		_rebuild_fallback_hand()
	_refresh_hand_view()
	_refresh_view()


func set_publish_cooldown_remaining(seconds: float) -> void:
	# 冷却时间来自 A；UI 不维护第二套游戏计时。
	_cooldown_remaining = maxf(0.0, seconds)
	_refresh_view()


func set_review_source_label(value: String) -> void:
	_review_source_label = value


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


# 以下接口供 A 注入直播、评论、人物素材和阶段事实，D 只负责呈现。
func configure_streamers(player_name: String, opponent_name: String) -> void:
	_player_display_name = player_name
	_opponent_display_name = opponent_name
	_player_panel.call("configure_identity", _player_display_name, _player_fan_group_name)
	_opponent_panel.call("configure_identity", _opponent_display_name, _opponent_fan_group_name)


func configure_fan_group_names(player_group: String, opponent_group: String) -> void:
	_player_fan_group_name = player_group
	_opponent_fan_group_name = opponent_group
	_player_panel.call("configure_identity", _player_display_name, _player_fan_group_name)
	_opponent_panel.call("configure_identity", _opponent_display_name, _opponent_fan_group_name)


func configure_streamer_assets(
	player_portrait: Texture2D,
	player_background: Texture2D,
	player_badge: Texture2D,
	opponent_portrait: Texture2D,
	opponent_background: Texture2D,
	opponent_badge: Texture2D
) -> void:
	_player_panel.call("configure_assets", player_portrait, player_background, player_badge, null)
	_opponent_panel.call("configure_assets", opponent_portrait, opponent_background, opponent_badge, null)


func configure_opponent_tier_textures(idle: Texture2D, tier_01: Texture2D, tier_02: Texture2D, tier_03: Texture2D) -> void:
	_opponent_panel.call("configure_opponent_tier_textures", idle, tier_01, tier_02, tier_03)


func configure_opponent_foreground(texture: Texture2D) -> void:
	_opponent_panel.call("configure_opponent_foreground", texture)


func configure_portrait_character(character_id: String) -> void:
	_opponent_panel.call("configure_portrait_character", character_id)


func bind_player_live_session(session: LiveSessionData, unknown_metrics: Array = []) -> void:
	_player_panel.call("bind_live_session", session, unknown_metrics)


func bind_opponent_live_session(session: LiveSessionData, unknown_metrics: Array = []) -> void:
	_opponent_panel.call("bind_live_session", session, unknown_metrics)


func configure_formal_comments(side: int, rows: Array[Dictionary], parameters: Dictionary) -> void:
	var target: Control = _player_panel if side == BubbleDialogueEntry.SpeakerSide.PLAYER else _opponent_panel
	target.call("configure_formal_comments", rows, parameters)


func configure_player_formal_comments(rows: Array[Dictionary], parameters: Dictionary) -> void:
	_player_panel.call("configure_formal_comments", rows, parameters)


func configure_opponent_formal_comments(rows: Array[Dictionary], parameters: Dictionary) -> void:
	_opponent_panel.call("configure_formal_comments", rows, parameters)


func get_live_data_hud(side: String) -> Control:
	var target: Control = _opponent_panel if side == "opponent" else _player_panel
	return target.call("get_live_data_hud") as Control


func set_unit_team_art(neutral: Texture2D, player: Texture2D, opponent: Texture2D) -> void:
	_field.call("set_team_textures", neutral, player, opponent)


func get_paradox_overlay_layer() -> Control:
	return _board_overlay


func get_aim_reticle() -> AimReticle:
	# A 把本节点的准星交给 AttackChargeInput，保证命中查询与可见准星共用实例。
	return _aim_reticle


func refresh_pk(player_pk: float, current_tier: int) -> void:
	# 兼容旧 HUD 使用 0–1 比例与 Plan B Host 的 0–100 百分比输入。
	_actual_player_pk = clampf(player_pk / 100.0 if player_pk > 1.0 else player_pk, 0.0, 1.0)
	_pk_value = _actual_player_pk * 100.0
	set_battle_tier(current_tier)
	if _pk_bar_skin != null:
		_pk_bar_skin.call("set_display_state", _actual_player_pk, _battle_tier, _paradox_stage_active)
	_refresh_view()


func set_paradox_stage_active(active: bool, current_tier: int) -> void:
	_paradox_stage_active = active
	_battle_tier = maxi(current_tier, 0)
	_tier_label = "T%d" % _battle_tier
	_refresh_special_stage_layout()
	if active and not _final_oracle_stage_active:
		_show_field_event("矛盾阶段 · 蓄力射击", 2.5)
		_aim_reticle.call("refresh_mouse_position")
	if _opponent_panel != null:
		_opponent_panel.call("set_tier", _battle_tier)
	if _tier_value_label != null:
		_tier_value_label.text = "T6 · 矛盾" if active else _tier_label
	if _pk_bar_skin != null:
		_pk_bar_skin.call("set_display_state", _actual_player_pk, _battle_tier, active)
	_refresh_view()


func set_final_oracle_stage_active(active: bool) -> void:
	# 神谕候选展示由 A 管理；D 只切换正常战斗层并保留外部候选覆盖区。
	_final_oracle_stage_active = active
	_refresh_special_stage_layout()
	if active:
		_show_field_event("最终神谕 · 选择一句回应", 2.5)
	_refresh_view()


func _refresh_special_stage_layout() -> void:
	# 特殊阶段替换手牌内容但保留三段高度，棋盘逻辑矩形始终不变。
	var special_stage_active := _paradox_stage_active or _final_oracle_stage_active
	var show_paradox_layer := _paradox_stage_active and not _final_oracle_stage_active
	_field.call("set_unit_layer_visible", not special_stage_active)
	_word_hand_panel.visible = not special_stage_active
	_paradox_footer.visible = show_paradox_layer
	_oracle_footer.visible = _final_oracle_stage_active
	_population_ribbon.visible = not special_stage_active
	_paradox_stage_label.visible = show_paradox_layer
	_aim_reticle.visible = show_paradox_layer
	if special_stage_active:
		_counterattack_label.visible = false
		_counterattack_seconds = 0.0


func _is_special_stage_active() -> bool:
	return _paradox_stage_active or _final_oracle_stage_active


func play_tier_breakthrough(previous_tier: int, current_tier: int) -> bool:
	if previous_tier < 0 or current_tier <= previous_tier or not is_node_ready():
		return false
	cancel_tier_breakthrough()
	_stage_transition_previous_tier = previous_tier
	_stage_transition_current_tier = current_tier
	_stage_transition_active = true
	if previous_tier == 0:
		set_opponent_portrait_connected(false)
	_stage_arrow.call("play", 1)
	return true


func is_stage_transition_playing() -> bool:
	var connecting := _opponent_panel != null and bool(_opponent_panel.call("is_connecting"))
	return _stage_transition_active or (_stage_arrow != null and bool(_stage_arrow.call("is_playing"))) or connecting


func cancel_tier_breakthrough() -> void:
	if _stage_arrow != null:
		_stage_arrow.call("reset_effect")
	if _opponent_panel != null and bool(_opponent_panel.call("is_connecting")):
		_opponent_panel.call("reset_connection")
	if not _stage_transition_active:
		return
	var previous_tier := _stage_transition_previous_tier
	var current_tier := _stage_transition_current_tier
	_stage_transition_active = false
	tier_breakthrough_finished.emit(previous_tier, current_tier, false)


func set_opponent_portrait_connected(connected: bool) -> void:
	if connected == _opponent_connected:
		return
	_opponent_connected = connected
	if _opponent_panel != null:
		_opponent_panel.call("set_opponent_portrait_connected", connected)
	if _dialogue_queue != null:
		_dialogue_queue.call("set_side_enabled", BubbleDialogueEntry.SpeakerSide.OPPONENT, connected)


func configure_opponent_result(level: LevelProfile, presentation: Dictionary = {}) -> bool:
	return bool(_opponent_panel.call("configure_opponent_result", level, presentation))


func play_opponent_result(broken: bool) -> bool:
	return bool(_opponent_panel.call("play_opponent_result", broken))


func bind_portrait_attack(attack: AttackChargeInput) -> void:
	if is_instance_valid(_portrait_attack) and _portrait_attack.shot_snapshot_created.is_connected(_on_player_shot):
		_portrait_attack.shot_snapshot_created.disconnect(_on_player_shot)
	_portrait_attack = attack
	if is_instance_valid(_portrait_attack):
		_portrait_attack.shot_snapshot_created.connect(_on_player_shot)


func _on_player_shot(_snapshot: AttackTargetSnapshot) -> void:
	if _aim_reticle != null:
		_aim_reticle.visible = not _final_oracle_stage_active
		_aim_reticle.call("play_shot_feedback")
	_player_panel.call("play_shot")


func _on_aim_animation_finished() -> void:
	if not _paradox_stage_active and _aim_reticle != null:
		_aim_reticle.visible = false


func refresh_attack(progress: float, _phase: int) -> void:
	var holding := is_instance_valid(_portrait_attack) and _portrait_attack.is_charge_held()
	var fully_charged := is_instance_valid(_portrait_attack) and _portrait_attack.is_fully_charged()
	if _aim_reticle != null:
		_aim_reticle.visible = not _final_oracle_stage_active and (_paradox_stage_active or holding or fully_charged or progress > 0.0)
		_aim_reticle.call("set_charge_visual_state", progress, holding, fully_charged)


func move_touch_aim(viewport_position: Vector2, diameter: float = 144.0) -> void:
	# 保留准星原生触控入口，位置按当前画布缩放转换。
	_aim_reticle.call("move_touch_aim", viewport_position, diameter)


func restore_mouse_aim(viewport_position: Vector2) -> void:
	_aim_reticle.call("restore_mouse_aim", viewport_position)


func show_dialogue_bubble(entry: BubbleDialogueEntry) -> StreamerBubbleView:
	if entry == null or entry.text.strip_edges().is_empty():
		return null
	var panel: Control = _player_panel if entry.side == BubbleDialogueEntry.SpeakerSide.PLAYER else _opponent_panel
	var bubble: StreamerBubbleView = panel.call("show_bubble", entry) as StreamerBubbleView
	if bubble != null:
		dialogue_bubble_presented.emit(entry.side, entry.event_id, entry.text)
	return bubble


func enqueue_dialogue_bubble(entry: BubbleDialogueEntry) -> bool:
	return bool(_dialogue_queue.call("enqueue_entry", entry)) if _dialogue_queue != null else false


func enqueue_dialogue_sequence(entries: Array[BubbleDialogueEntry], sequence_id: StringName = &"") -> StringName:
	if _dialogue_queue == null:
		return &""
	return StringName(_dialogue_queue.call("enqueue_sequence", entries, sequence_id))


func clear_dialogue_bubbles(side: int = -1) -> void:
	if _dialogue_queue != null:
		_dialogue_queue.call("clear_side", side)
	else:
		_clear_bubble_stack(side)


func _clear_bubble_stack(side: int) -> void:
	if side == -1 or side == BubbleDialogueEntry.SpeakerSide.PLAYER:
		_player_panel.call("clear_bubbles")
	if side == -1 or side == BubbleDialogueEntry.SpeakerSide.OPPONENT:
		_opponent_panel.call("clear_bubbles")


func _on_dialogue_sequence_completed(sequence_id: StringName, side: int) -> void:
	dialogue_sequence_completed.emit(sequence_id, side)


func show_battle_state(message: String) -> void:
	_set_status(message, "info")
	_show_field_event(message)


func show_failure() -> void:
	_battle_over = true
	_aim_reticle.visible = false
	_selected_word_id = ""
	_field.call("set_selected_unit", "")
	_set_status("本场结束", "warning")
	_show_field_event("本场结束 · 等待重开")
	_refresh_hand_view()


func request_restart() -> void:
	# 重开按钮归 A 的根场景；D 只转发用户的重开请求，不触碰战斗生命周期。
	restart_requested.emit()


func reset_for_attempt(current_tier: int = 0) -> void:
	_battle_over = false
	_selected_word_id = ""
	_pending_publish = false
	_pending_word_id = ""
	_pending_unit_id = ""
	_failure_presentation_active = false
	cancel_tier_breakthrough()
	clear_dialogue_bubbles()
	set_final_oracle_stage_active(false)
	_opponent_connected = true
	_player_panel.call("reset_for_attempt")
	_opponent_panel.call("reset_for_attempt")
	set_opponent_portrait_connected(false)
	_aim_reticle.call("reset_visual_state")
	_aim_reticle.visible = false
	set_paradox_stage_active(false, current_tier)
	set_battle_tier(current_tier)
	set_opponent_portrait_connected(current_tier > 0)
	_field.call("set_selected_unit", "")
	_set_status("先选一句，再点击棋盘中的中立观众。", "info")
	_refresh_hand_view()


func play_failure_presentation() -> void:
	if _failure_presentation_active:
		return
	_failure_presentation_active = true
	clear_dialogue_bubbles()
	if _actual_player_pk > 0.0:
		_failure_presentation_active = false
		failure_presentation_finished.emit()
		return
	_player_panel.call("play_shutdown")


func _on_player_shutdown_finished() -> void:
	if not _failure_presentation_active:
		return
	_failure_presentation_active = false
	failure_presentation_finished.emit()


func _on_opponent_result_presentation_finished(broken: bool) -> void:
	opponent_result_presentation_finished.emit(broken)


func _on_opponent_connection_finished() -> void:
	if _stage_transition_active:
		_finish_tier_breakthrough()


func _on_stage_arrow_finished(direction: int) -> void:
	if direction < 0 or not _stage_transition_active:
		return
	if _stage_transition_previous_tier == 0:
		set_opponent_portrait_connected(true)
		_opponent_panel.call("play_connection")
	else:
		_finish_tier_breakthrough()


func _finish_tier_breakthrough() -> void:
	if not _stage_transition_active:
		return
	var previous_tier := _stage_transition_previous_tier
	var current_tier := _stage_transition_current_tier
	_stage_transition_active = false
	tier_breakthrough_finished.emit(previous_tier, current_tier, true)


func _show_field_event(message: String, seconds: float = 2.2) -> void:
	if _event_label == null:
		return
	_event_label.text = message
	_event_label.modulate.a = 1.0
	_feedback_seconds = maxf(seconds, 0.1)

func _build_view() -> void:
	# 逻辑画布按 448 / 1024 / 448 固定切分；主播信息留在两侧，操作集中在中间。
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071018")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var columns := HBoxContainer.new()
	columns.name = "ThreeColumnLayout"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 0)
	columns.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(columns)

	_player_panel = StreamerPanelScript.new()
	_player_panel.name = "PlayerStreamerPanel"
	_player_panel.call("configure_side", "player")
	_player_panel.custom_minimum_size = Vector2(448.0, 1080.0)
	_player_panel.size_flags_horizontal = Control.SIZE_FILL
	_player_panel.connect("shutdown_finished", Callable(self, "_on_player_shutdown_finished"))
	columns.add_child(_player_panel)

	var center := Control.new()
	center.name = "BattleCenter"
	center.custom_minimum_size = Vector2(1024.0, 1080.0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	_build_center(center)

	_opponent_panel = StreamerPanelScript.new()
	_opponent_panel.name = "OpponentStreamerPanel"
	_opponent_panel.call("configure_side", "opponent")
	_opponent_panel.custom_minimum_size = Vector2(448.0, 1080.0)
	_opponent_panel.size_flags_horizontal = Control.SIZE_FILL
	_opponent_panel.connect("connection_finished", Callable(self, "_on_opponent_connection_finished"))
	_opponent_panel.connect("result_presentation_finished", Callable(self, "_on_opponent_result_presentation_finished"))
	columns.add_child(_opponent_panel)

	# 旧准星以全画布坐标跟随鼠标；透明、忽略鼠标事件，不改变棋盘点击判定。
	_aim_reticle = AIM_RETICLE_SCENE.instantiate()
	_aim_reticle.name = "AimReticle"
	_aim_reticle.z_index = 60
	_aim_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_reticle.visible = false
	_aim_reticle.connect("animation_finished", Callable(self, "_on_aim_animation_finished"))
	add_child(_aim_reticle)



func _build_center(parent: Control) -> void:
	# 中央区固定由 PK 72、棋盘 828、话语栏 180 三段组成。
	var column := VBoxContainer.new()
	column.name = "BattleColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(column)
	_build_pk_bar(column)
	_build_field(column)
	_build_word_hand(column)


func _build_pk_bar(parent: Container) -> void:
	# PK 比例与 Tier 只读 A/Host 提供的数值，原皮肤资源继续呈现档位变化。
	var panel := PanelContainer.new()
	panel.name = "PkTierBar"
	panel.custom_minimum_size = Vector2(0.0, 72.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101f29"), Color("#29414c"), 0, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(rows)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	rows.add_child(heading)
	_pk_value_label = _label("50% · 玩家 PK", 17, COLOR_TEXT)
	_pk_value_label.custom_minimum_size.x = 144.0
	heading.add_child(_pk_value_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_tier_value_label = _label("T0", 18, Color("#ffd59b"))
	_tier_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(_tier_value_label)

	_pk_bar = ProgressBar.new()
	_pk_bar.name = "PkProgress"
	_pk_bar.custom_minimum_size.y = 16.0
	_pk_bar.min_value = 0.0
	_pk_bar.max_value = 100.0
	_pk_bar.value = _pk_value
	_pk_bar.show_percentage = false
	_pk_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pk_bar.add_theme_stylebox_override("background", _panel_style(Color("#20333d"), Color("#20333d"), 7, 0))
	_pk_bar.add_theme_stylebox_override("fill", _panel_style(Color("#42bdd8"), Color("#42bdd8"), 7, 0))
	rows.add_child(_pk_bar)
	_pk_bar_skin = PK_BAR_SKIN_SCENE.instantiate()
	_pk_bar_skin.name = "PkBarSkin"
	_pk_bar.add_child(_pk_bar_skin)


func _build_field(parent: Container) -> void:
	# 棋盘绘制与点击命中共用 B 的全局坐标，不覆盖模拟拥有者状态。
	var field_host := Control.new()
	field_host.name = "UnitFieldHost"
	field_host.custom_minimum_size = Vector2(1024.0, 828.0)
	field_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(field_host)

	_field = UnitFieldScript.new()
	_field.name = "UnitField"
	_field.custom_minimum_size = Vector2(1024.0, 828.0)
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.set_density_profile(_density_profile)
	_field.unit_clicked.connect(_on_unit_clicked)
	_field.empty_field_clicked.connect(_on_empty_field_clicked)
	field_host.add_child(_field)

	_board_overlay = Control.new()
	_board_overlay.name = "BattleOverlayLayer"
	_board_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_overlay.z_index = 10
	field_host.add_child(_board_overlay)

	var ribbon := PanelContainer.new()
	ribbon.name = "PopulationRibbon"
	ribbon.anchor_left = 0.0
	ribbon.anchor_right = 1.0
	ribbon.offset_left = 14.0
	ribbon.offset_top = 10.0
	ribbon.offset_right = -14.0
	ribbon.offset_bottom = 48.0
	ribbon.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.10, 0.14, 0.90), Color("#2b4652"), 10))
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_population_ribbon = ribbon
	_board_overlay.add_child(_population_ribbon)
	_counts_label = _label("煲煲 0    ·    中立 0    ·    费米 0", 16, COLOR_TEXT)
	_counts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(_counts_label)

	_counterattack_label = _label("", 17, Color("#ffe096"))
	_counterattack_label.anchor_left = 0.18
	_counterattack_label.anchor_right = 0.82
	_counterattack_label.offset_top = 58.0
	_counterattack_label.offset_bottom = 90.0
	_counterattack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counterattack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counterattack_label.add_theme_color_override("font_outline_color", Color("#24180d"))
	_counterattack_label.add_theme_constant_override("outline_size", 5)
	_counterattack_label.visible = false
	_board_overlay.add_child(_counterattack_label)

	_paradox_stage_label = _label("矛盾阶段 · 蓄力射击", 20, Color("#eadfff"))
	_paradox_stage_label.anchor_left = 0.18
	_paradox_stage_label.anchor_right = 0.82
	_paradox_stage_label.offset_top = 10.0
	_paradox_stage_label.offset_bottom = 48.0
	_paradox_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paradox_stage_label.add_theme_color_override("font_outline_color", Color("#15121d"))
	_paradox_stage_label.add_theme_constant_override("outline_size", 5)
	_paradox_stage_label.visible = false
	_board_overlay.add_child(_paradox_stage_label)

	_event_label = _label("", 14, Color("#f1f7f8"))
	_event_label.anchor_left = 0.12
	_event_label.anchor_right = 0.88
	_event_label.anchor_top = 1.0
	_event_label.anchor_bottom = 1.0
	_event_label.offset_top = -56.0
	_event_label.offset_bottom = -14.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_label.add_theme_color_override("font_outline_color", Color("#071018"))
	_event_label.add_theme_constant_override("outline_size", 5)
	_event_label.modulate.a = 0.0
	_board_overlay.add_child(_event_label)

	_stage_arrow = StageArrowScript.new()
	_stage_arrow.name = "StageArrowFx"
	_stage_arrow.z_index = 20
	_stage_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_overlay.add_child(_stage_arrow)
	_stage_arrow.connect("animation_finished", Callable(self, "_on_stage_arrow_finished"))


func _build_word_hand(parent: Container) -> void:
	# 四张卡只展示 C 的手牌快照；抽取和成功补位由 C/A 负责。
	var panel := PanelContainer.new()
	panel.name = "WordHand"
	panel.custom_minimum_size = Vector2(0.0, 180.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101f29"), Color("#29414c"), 0, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_word_hand_panel = panel
	parent.add_child(_word_hand_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	content.add_child(heading)
	var title := _label("当前手牌  ·  按 1–4 选句", 16, Color("#75d9f0"))
	heading.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_hand_count_label = _label("等待 C 提供手牌", 14, COLOR_MUTED)
	_hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(_hand_count_label)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cards)
	for index in range(4):
		var button := Button.new()
		button.name = "WordCard%d" % (index + 1)
		button.custom_minimum_size = Vector2(0.0, 98.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.clip_contents = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_stylebox_override("disabled", _panel_style(Color("#101a21"), Color("#23343c"), 10))
		button.add_theme_color_override("font_disabled_color", Color("#82929a"))
		_style_button(button, false)
		cards.add_child(button)

		var card_content := VBoxContainer.new()
		card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_content.add_theme_constant_override("separation", 3)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(card_content)

		var key_label := _label("%d" % (index + 1), 11, Color("#7dd9ef"))
		card_content.add_child(key_label)
		var phrase_label := _label("等待词池", 18, COLOR_TEXT)
		phrase_label.custom_minimum_size.y = 42.0
		phrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		phrase_label.max_lines_visible = 2
		card_content.add_child(phrase_label)
		var meta_label := _label("", 11, COLOR_MUTED)
		card_content.add_child(meta_label)

		button.pressed.connect(_select_hand_slot.bind(index))
		_hand_buttons.append(button)
		_hand_phrase_labels.append(phrase_label)
		_hand_meta_labels.append(meta_label)
		_hand_button_selected_state.append(false)
		_hand_button_disabled_state.append(false)

	_hand_status_label = _label(_status_text, 14, COLOR_MUTED)
	_hand_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hand_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(_hand_status_label)
	_refresh_hand_view()
	_build_paradox_footer(parent)
	_build_oracle_footer(parent)


func _build_paradox_footer(parent: Container) -> void:
	# 矛盾阶段替换底部手牌区但保留 180px 高度，避免棋盘逻辑矩形变化。
	_paradox_footer = PanelContainer.new()
	_paradox_footer.name = "ParadoxFooter"
	_paradox_footer.custom_minimum_size = Vector2(0.0, 180.0)
	_paradox_footer.add_theme_stylebox_override("panel", _panel_style(Color("#171523"), Color("#56486d"), 0, 0))
	_paradox_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paradox_footer.visible = false
	parent.add_child(_paradox_footer)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 8)
	_paradox_footer.add_child(copy)
	var heading := _label("T6 · 矛盾射击", 24, Color("#eadfff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(heading)
	var instruction := _label("按住蓄力。准心接近满格时瞄准，再松开发射。", 16, Color("#c5b7db"))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(instruction)


func _build_oracle_footer(parent: Container) -> void:
	# 神谕候选层由 A 放进 overlay，底部仍保留固定高度。
	_oracle_footer = PanelContainer.new()
	_oracle_footer.name = "FinalOracleFooter"
	_oracle_footer.custom_minimum_size = Vector2(0.0, 180.0)
	_oracle_footer.add_theme_stylebox_override("panel", _panel_style(Color("#1a1721"), Color("#665979"), 0, 0))
	_oracle_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oracle_footer.visible = false
	parent.add_child(_oracle_footer)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 8)
	_oracle_footer.add_child(copy)
	var heading := _label("最终神谕", 24, Color("#eadfff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(heading)
	var instruction := _label("结合战场结果选择最后回应。", 16, Color("#c5b7db"))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(instruction)


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
	# 兼容旧联调入口；正式布局只重绘底部四张手牌。
	if not _hand_from_c:
		_rebuild_fallback_hand()
	_refresh_hand_view()


func _rebuild_fallback_hand() -> void:
	# 旧预览只提供词条全集时取前四条；正式接入由 C 的手牌快照覆盖。
	_hand_words.clear()
	for definition in _word_definitions:
		var word_id := str(definition.get("word_id", ""))
		if word_id.is_empty() or _used_word_ids.has(word_id):
			continue
		_hand_words.append(definition.duplicate(true))
		if _hand_words.size() >= 4:
			break
	_hand_remaining_count = maxi(0, _word_definitions.size() - _hand_words.size())


func _entry_word_id(entry: Dictionary) -> String:
	return str(entry.get("word_id", entry.get("id", entry.get("phrase_id", ""))))


func _refresh_hand_view() -> void:
	if _hand_buttons.is_empty():
		return
	for index in range(4):
		var entry: Dictionary = _hand_words[index] if index < _hand_words.size() else {}
		var word_id := _entry_word_id(entry)
		var phrase := str(entry.get("text", _word_text_by_id.get(word_id, "")))
		var used := not word_id.is_empty() and _used_word_ids.has(word_id)
		var button := _hand_buttons[index]
		var phrase_label := _hand_phrase_labels[index]
		var meta_label := _hand_meta_labels[index]
		var next_disabled := true
		if word_id.is_empty():
			var empty_text := "词池已空" if _hand_from_c else "等待 C 提供手牌"
			if phrase_label.text != empty_text:
				phrase_label.text = empty_text
			if meta_label.text != "":
				meta_label.text = ""
			if button.tooltip_text != empty_text:
				button.tooltip_text = empty_text
		else:
			var shown_phrase := phrase if not phrase.is_empty() else word_id
			if phrase_label.text != shown_phrase:
				phrase_label.text = shown_phrase
			var strength := int(entry.get("strength", 1))
			var battle_type := str(entry.get("battle_type", "话语"))
			var meta_text := "已发表" if used else "强度 %d · %s" % [strength, battle_type]
			if meta_label.text != meta_text:
				meta_label.text = meta_text
			var tooltip := phrase if not used else phrase + "\n本局已发表"
			if button.tooltip_text != tooltip:
				button.tooltip_text = tooltip
			next_disabled = used or _battle_over or _pending_publish
		var next_selected := word_id == _selected_word_id and not used
		var disabled_changed := _hand_button_disabled_state[index] != next_disabled
		var selection_changed := _hand_button_selected_state[index] != next_selected
		if button.disabled != next_disabled:
			button.disabled = next_disabled
		if disabled_changed or selection_changed:
			_style_button(button, next_selected)
			_hand_button_disabled_state[index] = next_disabled
			_hand_button_selected_state[index] = next_selected
	if _hand_count_label != null:
		if _hand_from_c:
			_hand_count_label.text = "手牌 %d/4 · 词池余 %d" % [_hand_words.size(), _hand_remaining_count]
		else:
			_hand_count_label.text = "手牌 %d/4 · 词库预览" % _hand_words.size()
	_update_status_view()


func _refresh_sources() -> void:
	if is_instance_valid(_battle_host) and _battle_host.has_method("get_pk"):
		var pk_value := float(_battle_host.call("get_pk"))
		_actual_player_pk = clampf(pk_value / 100.0 if pk_value > 1.0 else pk_value, 0.0, 1.0)
		_pk_value = _actual_player_pk * 100.0
	if _has_method(_battle_host, "get_used_word_ids"):
		var used_ids: Variant = _battle_host.call("get_used_word_ids")
		if used_ids is Array:
			set_published_word_ids(used_ids)
	if _has_method(_battle_host, "get_publish_cooldown_remaining"):
		_cooldown_remaining = maxf(float(_battle_host.call("get_publish_cooldown_remaining", "player")), 0.0)
	if _has_method(_battle_host, "get_current_tier"):
		var current_tier := int(_battle_host.call("get_current_tier"))
		if current_tier != _battle_tier:
			_on_tier_changed(current_tier)
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
			if _refresh_missing_word_texts() and _field != null:
				_field.set_word_texts(_word_text_by_id)
		if _field != null:
			_field.set_unit_snapshots(_snapshots)


func _refresh_missing_word_texts() -> bool:
	if not is_instance_valid(_word_catalog) or not _word_catalog.has_method("get_word_definition"):
		return false
	var changed := false
	for unit in _snapshots:
		if not unit is Dictionary:
			continue
		var word_id := str(unit.get("word_id", ""))
		if word_id.is_empty() or _word_text_by_id.has(word_id):
			continue
		var definition: Variant = _word_catalog.call("get_word_definition", word_id)
		if definition is Dictionary:
			_word_text_by_id[word_id] = str(definition.get("text", ""))
			changed = true
	return changed


func _refresh_view() -> void:
	if _pk_value_label == null:
		return
	var pk_text := "玩家 PK %.0f%%" % _pk_value
	if _pk_value_label.text != pk_text:
		_pk_value_label.text = pk_text
	if not is_equal_approx(_pk_bar.value, _pk_value):
		_pk_bar.value = _pk_value
	var tier_text := "T6 · 矛盾" if _paradox_stage_active else _tier_label
	if _tier_value_label.text != tier_text:
		_tier_value_label.text = tier_text
	var player_count := int(_counts.get("player", 0))
	var opponent_count := int(_counts.get("opponent", 0))
	var neutral_count := int(_counts.get("neutral", 0))
	var counts_text := "煲煲 %d    ·    中立 %d    ·    费米 %d    ·    合计 %d / 96" % [
		player_count, neutral_count, opponent_count, player_count + neutral_count + opponent_count
	]
	if _counts_label.text != counts_text:
		_counts_label.text = counts_text
	_update_faction_phrases()
	_refresh_hand_view()


func _update_faction_phrases() -> void:
	var player_phrases := _most_common_words("player", 2)
	var opponent_phrases := _most_common_words("opponent", 2)
	var player_text := "暂无复读" if player_phrases.is_empty() else _format_phrase_list(player_phrases)
	var opponent_text := "暂无复读" if opponent_phrases.is_empty() else _format_phrase_list(opponent_phrases)
	var player_summary := "当前复读 · " + player_text.replace("\n", "  ")
	var opponent_summary := "当前复读 · " + opponent_text.replace("\n", "  ")
	if player_summary != _last_player_echo:
		_player_panel.call("set_echo_summary", player_summary)
		_last_player_echo = player_summary
	if opponent_summary != _last_opponent_echo:
		_opponent_panel.call("set_echo_summary", opponent_summary)
		_last_opponent_echo = opponent_summary


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


func _update_status_view() -> void:
	if _hand_status_label == null:
		return
	var next_text := ""
	if _battle_over:
		next_text = "本场已结束"
	elif _pending_publish:
		next_text = "正在提交「%s」…" % _clip_text(str(_word_text_by_id.get(_pending_word_id, _pending_word_id)), 28)
	elif _selected_word_id.is_empty():
		next_text = "选择一句话，再点击棋盘中的中立观众。"
	elif int(_counts.get("neutral", 0)) <= 0:
		next_text = "场内暂无中立观众，请等局势变化。"
	else:
		next_text = "已选「%s」· 点击中立观众发表" % _clip_text(str(_word_text_by_id.get(_selected_word_id, _selected_word_id)), 30)
	if _cooldown_remaining > 0.0:
		next_text += "  ·  冷却 %.1f 秒" % _cooldown_remaining
	var tint := COLOR_MUTED
	match _status_kind:
		"success":
			tint = Color("#85e7c0")
		"error":
			tint = Color("#ff9c83")
		"warning":
			tint = Color("#ffd38e")
	if tint != _last_hand_status_tint:
		_hand_status_label.add_theme_color_override("font_color", tint)
		_last_hand_status_tint = tint
	if not _status_text.is_empty() and _status_kind != "info":
		next_text = _status_text
	if _hand_status_label.text != next_text:
		_hand_status_label.text = next_text


func _update_event_view() -> void:
	if _event_lines.is_empty():
		return
	_show_field_event(_event_lines[0], 1.8)


func _on_word_pressed(word_id: String) -> void:
	for index in range(_hand_words.size()):
		if _entry_word_id(_hand_words[index]) == word_id:
			_select_hand_slot(index)
			return


func _select_hand_slot(index: int) -> void:
	# 鼠标与 1–4 键共用一次选择入口，已发表话语保持禁用。
	if _battle_over:
		_set_status("本场已经结束。", "warning")
		return
	if index < 0 or index >= _hand_words.size():
		return
	var entry := _hand_words[index]
	var word_id := _entry_word_id(entry)
	if word_id.is_empty():
		_set_status("当前没有可选话语。", "warning")
		return
	if _used_word_ids.has(word_id):
		_set_status("这句话本局已经发表。", "warning")
		return
	_selected_word_id = word_id
	_field.call("set_selected_unit", "")
	_status_kind = "info"
	_status_text = ""
	word_selected.emit(word_id)
	_refresh_hand_view()


func _on_unit_clicked(unit_id: String, team: String) -> void:
	if _battle_over:
		_set_status("本场已经结束，无法继续发表。", "warning")
		return
	if _selected_word_id.is_empty():
		_set_status("先从底部手牌选择一句话。", "warning")
		return
	if team != "neutral":
		_set_status("这个观众已加入%s阵营，请点中立观众。" % ("煲煲" if team == "player" else "费米"), "error")
		_field.call("show_unit_feedback", unit_id, "invalid_target")
		return
	if _cooldown_remaining > 0.0:
		_set_status("发表冷却还剩 %.1f 秒。" % _cooldown_remaining, "warning")
		return
	if int(_counts.get("neutral", 0)) <= 0:
		_set_status("当前没有中立观众可供发表。", "warning")
		return

	var word_id := _selected_word_id
	if not publish_requested.get_connections().is_empty():
		_pending_publish = true
		_pending_word_id = word_id
		_pending_unit_id = unit_id
		publish_requested.emit(word_id, unit_id)
		if _pending_publish:
			_status_text = "已提交发表请求，等待战斗主控回执。"
			_status_kind = "info"
			_refresh_hand_view()
		return

	if not _has_method(_battle_host, "publish_word"):
		_set_status("战斗主控尚未提供发表入口。", "error")
		return
	var result: Variant = _battle_host.call("publish_word", "player", word_id, unit_id)
	resolve_publish_request(word_id, unit_id, result)


func resolve_publish_request(word_id: String, unit_id: String, result: Variant) -> void:
	# A 回传权威发表结果；失败保留当前手牌与选句，成功后由 C 更新补位。
	var succeeded := false
	var reason := ""
	var word_order := 0
	if result is Dictionary:
		succeeded = bool(result.get("ok", false))
		reason = str(result.get("reason", ""))
		word_order = int(result.get("word_order", 0))
	else:
		succeeded = bool(result)
	_pending_publish = false
	_pending_word_id = ""
	_pending_unit_id = ""
	if not succeeded:
		_set_status(_friendly_failure_reason(reason), "error")
		publish_result.emit(word_id, unit_id, false)
		_refresh_hand_view()
		return

	_used_word_ids[word_id] = true
	if _selected_word_id == word_id:
		_selected_word_id = ""
	_field.call("set_selected_unit", "")
	var published_text := str(_word_text_by_id.get(word_id, _definition_for(word_id).get("text", word_id)))
	var order_suffix := " · 顺序 #%d" % word_order if word_order > 0 else ""
	_set_status("发表成功：%s 开始复读「%s」%s" % [unit_id, _clip_text(published_text, 30), order_suffix], "success")
	_field.call("show_unit_feedback", unit_id, "seed")
	if not _hand_from_c:
		_rebuild_fallback_hand()
	_refresh_hand_view()
	publish_result.emit(word_id, unit_id, true)


func _on_empty_field_clicked() -> void:
	if not _selected_word_id.is_empty():
		_set_status("这里没有观众棋子，空白处不会生成新单位。", "warning")


func _on_density_pressed(profile: String) -> void:
	_density_profile = "compact" if profile == "compact" else "clear"
	if _field != null:
		_field.call("set_density_profile", _density_profile)


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
	_actual_player_pk = clampf(value / 100.0 if value > 1.0 else value, 0.0, 1.0)
	_pk_value = _actual_player_pk * 100.0
	if _pk_bar_skin != null:
		_pk_bar_skin.call("set_display_state", _actual_player_pk, _battle_tier, _paradox_stage_active)
	_refresh_view()


func _on_tier_changed(current_tier: int) -> void:
	var previous_tier := _battle_tier
	set_battle_tier(current_tier)
	if previous_tier == current_tier:
		return
	if previous_tier == 0 and current_tier > 0:
		play_tier_breakthrough(previous_tier, current_tier)
	else:
		_stage_arrow.call("play", 1 if current_tier > previous_tier else -1)


func _on_battle_ended(result: Variant) -> void:
	_battle_over = true
	_selected_word_id = ""
	_field.call("set_selected_unit", "")
	var result_text := str(result)
	if result is Dictionary:
		result_text = str(result.get("message", result.get("result", result_text)))
	_set_status("本场结束 · %s" % result_text, "warning")
	_refresh_view()


func show_counterattack_windup(request: Dictionary) -> void:
	if _is_special_stage_active():
		return
	var target_id := str(request.get("target_unit_id", ""))
	var skill_id := str(request.get("skill_id", request.get("effect_id", "费米反击")))
	var windup := float(request.get("pre_windup_seconds", 0.0))
	if not target_id.is_empty():
		_field.call("show_unit_feedback", target_id, "counterattack")
	_counterattack_label.text = "费米反击蓄力 · %s" % skill_id
	_counterattack_label.visible = true
	_counterattack_seconds = maxf(windup + 1.2, 1.2)
	_add_event("[费米反击前摇] %s · 目标 %s · %.1f 秒" % [skill_id, target_id, windup])
	_set_status("费米正在准备反击，请留意目标棋子的紫色脉冲。", "warning")


func show_counterattack_result(result: Dictionary) -> void:
	if _is_special_stage_active():
		return
	var target_id := str(result.get("target_unit_id", ""))
	var skill_id := str(result.get("skill_id", result.get("effect_id", "费米反击")))
	var applied := bool(result.get("applied", false))
	if not target_id.is_empty():
		_field.call("show_unit_feedback", target_id, "counterattack")
	_counterattack_label.text = "%s · %s" % ["反击生效" if applied else "反击未生效", skill_id]
	_counterattack_label.visible = true
	_counterattack_seconds = 2.4
	_add_event("[%s] %s · %s" % ["费米反击生效" if applied else "费米反击未生效", skill_id, target_id])
	_set_status("费米反击已结算：%s。" % ("生效" if applied else "未生效"), "warning" if applied else "info")


func _on_contact_resolved(first_unit_id: Variant, second_unit_id: Variant, outcome: StringName) -> void:
	if _is_special_stage_active():
		return
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
	_field.call("show_contact_feedback", first_id, second_id, str(outcome))
	_add_event("[碰撞] %s ↔ %s · %s" % [first_id, second_id, outcome_text])


func _on_unit_changed(unit_id: String, reason: String) -> void:
	if _is_special_stage_active():
		return
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
	_field.call("show_unit_feedback", unit_id, reason)
	_add_event(message)
	_refresh_sources()
	_refresh_view()


func _on_unit_spawned(unit_id: String) -> void:
	if _is_special_stage_active():
		return
	_add_event("[入场] 新观众 %s 加入" % unit_id)


func _on_unit_despawned(unit_id: String) -> void:
	if _is_special_stage_active():
		return
	_add_event("[离场] 观众 %s 离开" % unit_id)


func _add_event(message: String) -> void:
	if _is_special_stage_active():
		return
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
	for hand_entry in _hand_words:
		if _entry_word_id(hand_entry) == word_id:
			return hand_entry
	return {}


func _clip_text(value: String, max_characters: int) -> String:
	return value if value.length() <= max_characters else value.left(max_characters - 1) + "…"
