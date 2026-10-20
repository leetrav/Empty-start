extends NinePatchRect

## 空白身份卡作为九宫格纸面，局部主题只改变纸面文字，不影响其他场景。
func _ready() -> void:
	var host := get_parent() as Control
	if host == null:
		return
	var paper_theme := preload("res://ui/theme/base_theme.tres").duplicate() as Theme
	for label_type: String in ["Label", "TitleLabel", "HeadingLabel", "MutedLabel", "StreamerNameLabel", "StreamerHeadingLabel", "StreamerMutedLabel"]:
		paper_theme.set_color("font_color", label_type, Color("#60442f"))
	paper_theme.set_color("default_color", "RichTextLabel", Color("#60442f"))
	host.theme = paper_theme

	if host is PanelContainer:
		# 容器自己绘制纸面，让边框位于内容留白之外，避免标题压到纸边上。
		var style := paper_theme.get_stylebox("panel", "CardPanel").duplicate() as StyleBoxTexture
		style.content_margin_left = 48.0
		style.content_margin_right = 48.0
		style.content_margin_top = 48.0
		style.content_margin_bottom = 48.0
		host.add_theme_stylebox_override("panel", style)
		hide()
