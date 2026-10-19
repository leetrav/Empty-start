extends Button

## 点击区域固定，只有文字参与动效；快速划过也不会移动命中边界。
@export var caption: String = ""
@export var text_size: int = 64
var _label: Label
var _motion: Tween
var _hovered := false
var _pressed := false
const NORMAL := Color("354536")
const ACTIVE := Color("755326")


func _ready() -> void:
	text = ""
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	_label = Label.new()
	_label.text = caption
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 使用现有可变字体的粗字重，缩小到720p后仍能看清笔画。
	var menu_font := FontVariation.new()
	menu_font.base_font = preload("res://assets/fonts/NotoSansSC-VF.ttf")
	menu_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
	_label.add_theme_font_override("font", menu_font)
	_label.add_theme_font_size_override("font_size", text_size)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.modulate = NORMAL if not disabled else Color("7b866c")
	add_child(_label)
	_label.position = Vector2(12, 0)
	_label.pivot_offset = Vector2(0, text_size * 0.65)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_refresh_feedback)
	focus_exited.connect(_refresh_feedback)
	button_down.connect(_press_feedback)
	button_up.connect(_release_feedback)


# 中断旧Tween并从当前位置接续，避免反复划过累积缩放和位移。
func _animate(target_scale: float, offset: float, color: Color, seconds: float) -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = create_tween().set_parallel(true)
	_motion.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_label, "scale", Vector2.ONE * target_scale, seconds)
	_motion.tween_property(_label, "position:x", 12.0 + offset, seconds)
	_motion.tween_property(_label, "modulate", color, seconds)


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_feedback()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_feedback()


# 鼠标与键盘共用同一反馈；禁用项可见但不响应。
func _refresh_feedback() -> void:
	if disabled:
		_animate(1.0, 0.0, Color("7b866c"), 0.18)
		return
	if _pressed:
		return
	var active := _hovered or has_focus()
	_animate(1.08 if active else 1.0, 12.0 if active else 0.0,
		ACTIVE if active else NORMAL, 0.16 if active else 0.22)


func _press_feedback() -> void:
	if not disabled:
		_pressed = true
		_animate(0.96, 6.0, ACTIVE, 0.08)


func _release_feedback() -> void:
	_pressed = false
	_refresh_feedback()


# 宿主载入存档状态后同步禁用显示，不依赖下一次鼠标事件。
func refresh_state() -> void:
	_refresh_feedback()
