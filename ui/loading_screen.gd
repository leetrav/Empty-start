extends Control

# 常驻路由层只绘制轻量加载提示，不额外加载美术或写入存档。
var show_indicator: bool = false
var _elapsed: float = 0.0
# 通关演出的遮幕与片尾使用同一纯黑，其他加载保留原底色。
var pure_black: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))

# 指示动画按真实时间转动，初始化阶段不伪造百分比。
func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func reset_indicator() -> void:
	_elapsed = 0.0
	show_indicator = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK if pure_black else Color("100f0c"))
	if not show_indicator:
		return
	var scale_factor: float = clampf(minf(size.x / 1280.0, size.y / 720.0), 0.65, 2.0)
	var center: Vector2 = size - Vector2(205.0, 65.0) * scale_factor
	for index: int in 8:
		var angle: float = float(index) * TAU / 8.0
		var pulse: float = 0.25 + 0.75 * (0.5 + 0.5 * cos(angle - _elapsed * 5.0))
		draw_circle(center + Vector2.from_angle(angle) * 12.0 * scale_factor, 2.1 * scale_factor, Color(0.95, 0.87, 0.65, pulse))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = roundi(20.0 * scale_factor)
	draw_string(font, center + Vector2(28.0, 7.0) * scale_factor, "正在加载", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("eee6d2"))
