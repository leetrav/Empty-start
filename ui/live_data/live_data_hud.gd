@tool
extends Control

enum DisplaySide { PLAYER_LEFT, OPPONENT_RIGHT }

# 展示方向只控制图标顺序和对齐。
@export var display_side: DisplaySide = DisplaySide.PLAYER_LEFT:
	set(value):
		display_side = value
		_refresh_values()

# 默认订阅玩家当前周目；其他数据来源由组合方关闭此项并显式注入。
@export var auto_bind_player_session: bool = true

# 正式 ICON 可替换为 BBCode [img]，继续沿用相同的数值刷新入口。
@export_group("指标图标")
@export var viewer_icon: String = "👤":
	set(value):
		viewer_icon = value
		_refresh_values()
@export var like_icon: String = "👍":
	set(value):
		like_icon = value
		_refresh_values()
@export var comment_icon: String = "🔊":
	set(value):
		comment_icon = value
		_refresh_values()
@export var fan_icon: String = "👥":
	set(value):
		fan_icon = value
		_refresh_values()

@onready var _viewer_metric: RichTextLabel = %ViewerMetric
@onready var _like_metric: RichTextLabel = %LikeMetric
@onready var _comment_metric: RichTextLabel = %CommentMetric
@onready var _fan_metric: RichTextLabel = %FanMetric
@onready var _metrics: VBoxContainer = $Metrics

var _live_session: LiveSessionData = null
# 仅缓存最近展示输入，避免图标或方向变化时从 k 文本反推并丢失整数。
var _display_values: Array[int] = [0, 0, 0, 0]
var _comment_rows: Array[Dictionary] = []
var _comment_params: Dictionary = {}
var _comment_scroll: ScrollContainer
var _comment_list: VBoxContainer
var _comment_timer: float = 0.0
var _comment_scroll_speed: float = 24.0
var _comment_scroll_remainder: float = 0.0
var _comment_row_cap: int = 5
var _unknown_metrics: Dictionary = {}


# A 提交未配置事实的指标 ID；这里只显示未知，不生成对手业务数值。
func set_unknown_metrics(metric_ids: Array) -> void:
	_unknown_metrics.clear()
	for metric_id: Variant in metric_ids:
		var key: String = str(metric_id)
		if key in ["viewer_count", "like_count", "comment_count", "fan_count"]:
			_unknown_metrics[key] = true
	_refresh_values()


# 交接/诊断只读当前显示值，未知字段保持 null，避免把占位零值报告成真实人数。
func get_display_snapshot() -> Dictionary:
	var result: Dictionary = {"has_live_session": _live_session != null}
	var keys: Array[String] = ["viewer_count", "like_count", "comment_count", "fan_count"]
	for index: int in keys.size():
		result[keys[index]] = null if _unknown_metrics.has(keys[index]) else _display_values[index]
	return result


# 编辑器只预览展示方向；运行时按独立绑定配置读取当前周目。
func _ready() -> void:
	_create_comment_feed()
	if Engine.is_editor_hint():
		_refresh_values()
		return
	if auto_bind_player_session:
		bind_live_session(SaveManager.data.live_session if SaveManager.data != null else null)
	else:
		_refresh_values()


## 只展示正式评论，不修改直播统计中的真实 comment_count。
func configure_formal_comments(rows: Array[Dictionary], parameters: Dictionary) -> void:
	_comment_rows = rows.duplicate(true)
	_comment_params = parameters.duplicate()
	_comment_row_cap = maxi(1, int(_comment_params.get("comment_visible_row_cap", 5)))
	_comment_scroll_speed = maxf(0.0, float(_comment_params.get("comment_scroll_speed_px_s", 24.0)))
	_comment_scroll_remainder = 0.0
	if _comment_scroll != null:
		_comment_list.add_theme_constant_override("separation", int(_comment_params.get("comment_row_spacing_px", 8)))
		_comment_scroll.custom_minimum_size.y = maxf(0.0, float(_comment_row_cap) * float(_comment_params.get("comment_font_size_px", 20)) * 1.6)
		_comment_timer = _next_comment_interval()
		_clear_comment_rows()
	var pause_with_game: bool = bool(_comment_params.get("comment_pause_with_game", true))
	process_mode = Node.PROCESS_MODE_PAUSABLE if pause_with_game else Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _comment_rows.is_empty() or _comment_list == null:
		return
	_comment_timer -= delta
	if _comment_timer <= 0.0:
		_add_next_comment()
		_comment_timer = _next_comment_interval()
	if _comment_scroll != null:
		_comment_scroll_remainder += _comment_scroll_speed * delta
		var scroll_step := int(floor(_comment_scroll_remainder))
		if scroll_step > 0:
			_comment_scroll_remainder -= float(scroll_step)
			_comment_scroll.scroll_vertical = mini(
				int(_comment_scroll.get_v_scroll_bar().max_value),
				_comment_scroll.scroll_vertical + scroll_step
			)


func _create_comment_feed() -> void:
	_comment_scroll = ScrollContainer.new()
	_comment_scroll.name = "FormalCommentScroll"
	_comment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_comment_scroll.custom_minimum_size = Vector2(0.0, 160.0)
	_comment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_comment_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_metrics.add_child(_comment_scroll)
	_comment_list = VBoxContainer.new()
	_comment_list.name = "CommentRows"
	_comment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comment_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comment_scroll.add_child(_comment_list)


func _add_next_comment() -> void:
	if _comment_rows.is_empty():
		return
	var row: Dictionary = _pick_weighted_comment()
	var viewer: Dictionary = row.get("viewer", {})
	var show_badge := str(viewer.get("audience_type", "")) == "fan" and randf() <= float(_comment_params.get("comment_fan_probability", 0.45))
	var badge := "[color=#ffd866]◆[/color] " if show_badge else ""
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(0.0, float(_comment_params.get("comment_font_size_px", 20)) * 1.5)
	label.add_theme_font_size_override("normal_font_size", int(_comment_params.get("comment_font_size_px", 20)))
	var safe_name := str(viewer.get("display_name", "")).replace("[", "[lb]")
	var safe_text := str(row.get("text", "")).replace("[", "[lb]")
	label.text = "%s[color=#b8c0ce]%s[/color]  %s" % [badge, safe_name, safe_text]
	_comment_list.add_child(label)
	while _comment_list.get_child_count() > _comment_row_cap:
		var oldest: Node = _comment_list.get_child(0)
		_comment_list.remove_child(oldest)
		oldest.queue_free()


func _pick_weighted_comment() -> Dictionary:
	var total_weight := 0.0
	for row: Dictionary in _comment_rows:
		total_weight += float(row.get("weight", 1.0))
	var target := randf() * total_weight
	for row: Dictionary in _comment_rows:
		target -= float(row.get("weight", 1.0))
		if target <= 0.0:
			return row
	return _comment_rows.back()


func _next_comment_interval() -> float:
	var low := maxf(0.1, float(_comment_params.get("comment_spawn_interval_min_s", 2.5)))
	var high := maxf(low, float(_comment_params.get("comment_spawn_interval_max_s", 4.5)))
	return randf_range(low, high)


func _clear_comment_rows() -> void:
	for child: Node in _comment_list.get_children():
		_comment_list.remove_child(child)
		child.queue_free()


# 场景初始化或替换数据源时显式重连，HUD 只订阅当前 Resource。
func bind_live_session(session: LiveSessionData) -> void:
	if _live_session != null and _live_session.changed.is_connected(_refresh_values):
		_live_session.changed.disconnect(_refresh_values)
	_live_session = session
	if _live_session != null:
		_live_session.changed.connect(_refresh_values)
		_refresh_values()
	elif is_node_ready():
		# 显式解绑仍清空显示，保持原绑定入口的约定。
		set_values(0, 0, 0, 0)


# 保留调用方的原始展示输入；业务状态仍由数据源持有。
func set_values(viewer_count: int, like_count: int, comment_count: int, fan_count: int) -> void:
	# 绑定后由唯一 Resource 优先，旧零占位调用不能覆盖当前事实。
	if _live_session != null:
		viewer_count = _live_session.viewer_count
		like_count = _live_session.like_count
		comment_count = _live_session.comment_count
		fan_count = _live_session.fan_count
	_display_values = [viewer_count, like_count, comment_count, fan_count]
	if not is_node_ready():
		return
	_render_metric(_viewer_metric, viewer_icon, viewer_count, "viewer_count")
	_render_metric(_like_metric, like_icon, like_count, "like_count")
	_render_metric(_comment_metric, comment_icon, comment_count, "comment_count")
	_render_metric(_fan_metric, fan_icon, fan_count, "fan_count")


# 绑定时读取数据源；未绑定时按最近的原始展示输入重新排版。
func _refresh_values() -> void:
	if not is_node_ready():
		return
	if _live_session == null:
		set_values(_display_values[0], _display_values[1], _display_values[2], _display_values[3])
		return
	set_values(_live_session.viewer_count, _live_session.like_count,
		_live_session.comment_count, _live_session.fan_count)


# 四项标签独立渲染，后续单项变色或 Tween 可在此接入。
func _render_metric(metric: RichTextLabel, icon: String, value: int, metric_id: String = "") -> void:
	# 千以下沿用整数；从 1000 起按千显示一位小数，只转换可见文字。
	var number_text: String = "%.1fk" % (value / 1000.0) if value >= 1000 else str(value)
	if _unknown_metrics.has(metric_id):
		number_text = "—"
		metric.tooltip_text = "该指标尚未配置事实来源"
	else:
		metric.tooltip_text = ""
	if display_side == DisplaySide.OPPONENT_RIGHT:
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		metric.text = number_text + icon
	else:
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		metric.text = icon + number_text
