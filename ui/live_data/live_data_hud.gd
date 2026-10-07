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

var _live_session: LiveSessionData = null


# 编辑器只预览展示方向；运行时按独立绑定配置读取当前周目。
func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_values()
		return
	if auto_bind_player_session:
		bind_live_session(SaveManager.data.live_session if SaveManager.data != null else null)
	else:
		_refresh_values()


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


# 将调用方提供的四项数值直接映射到文本，不保存敌方业务状态。
func set_values(viewer_count: int, like_count: int, comment_count: int, fan_count: int) -> void:
	_render_metric(_viewer_metric, viewer_icon, viewer_count)
	_render_metric(_like_metric, like_icon, like_count)
	_render_metric(_comment_metric, comment_icon, comment_count)
	_render_metric(_fan_metric, fan_icon, fan_count)


# 绑定数据时读取唯一来源；仅改展示配置时沿用标签中的当前整数。
func _refresh_values() -> void:
	if not is_node_ready():
		return
	if _live_session == null:
		# parsed_text 去掉 BBCode；to_int 忽略 Emoji 等非数字，避免新增数值副本。
		set_values(_viewer_metric.get_parsed_text().to_int(), _like_metric.get_parsed_text().to_int(),
			_comment_metric.get_parsed_text().to_int(), _fan_metric.get_parsed_text().to_int())
		return
	set_values(_live_session.viewer_count, _live_session.like_count,
		_live_session.comment_count, _live_session.fan_count)


# 四项标签独立渲染，后续单项变色或 Tween 可在此接入。
func _render_metric(metric: RichTextLabel, icon: String, value: int) -> void:
	if display_side == DisplaySide.OPPONENT_RIGHT:
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		metric.text = str(value) + icon
	else:
		metric.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		metric.text = icon + str(value)
