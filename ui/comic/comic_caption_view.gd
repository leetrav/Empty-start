class_name ComicCaptionView
extends Control

var caption: ComicCaption
var label: Label

# 气泡、旁白和弹幕使用不同样式，尾巴指向角色，原画保持只读。
func setup(value: ComicCaption) -> void:
	caption = value
	position = value.rect.position
	size = value.rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff9e9") if value.kind == "speech" else Color("201c26e8")
	if value.kind == "danmaku":
		style.bg_color = Color("b3e3eae8")
	style.border_color = Color("473424")
	style.set_border_width_all(3)
	style.set_corner_radius_all(25 if value.kind == "speech" else 10)
	if value.kind == "danmaku":
		style.bg_color = Color.TRANSPARENT
		style.set_border_width_all(0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	label = Label.new()
	label.position = Vector2(22, 12)
	label.size = size - Vector2(44, 24)
	label.text = value.text
	label.visible_characters = 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("31271f") if value.kind != "narration" else Color("fff9e9"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	queue_redraw()

# 尾部先绘制，再由面板覆盖连接处，形成连续气泡。
func _draw() -> void:
	if caption == null or caption.kind != "speech" or caption.tail.x < 0:
		return
	var tip := caption.tail - position
	var anchor := Vector2(clampf(tip.x, 24, size.x - 24), size.y - 5)
	draw_colored_polygon(PackedVector2Array([anchor + Vector2(-17, 0), tip, anchor + Vector2(17, 0)]), Color("fff9e9"))
	draw_line(anchor + Vector2(-17, 0), tip, Color("473424"), 3)
	draw_line(tip, anchor + Vector2(17, 0), Color("473424"), 3)
