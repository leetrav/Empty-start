extends NinePatchRect

## 空白身份卡作为九宫格纸面，局部主题统一纸面文字与复古按钮，不影响其他场景。
func _ready() -> void:
	var host := get_parent() as Control
	if host == null:
		return
	var paper_theme := preload("res://ui/theme/base_theme.tres").duplicate() as Theme
	for label_type: String in ["Label", "TitleLabel", "HeadingLabel", "MutedLabel", "StreamerNameLabel", "StreamerHeadingLabel", "StreamerMutedLabel"]:
		paper_theme.set_color("font_color", label_type, Color("#60442f"))
	paper_theme.set_color("default_color", "RichTextLabel", Color("#60442f"))
	apply_button_palette(paper_theme)
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

## 纸面按钮使用深木棕与古铜色，保留原按钮尺寸、圆角和交互状态。
static func apply_button_palette(target_theme: Theme) -> void:
	for button_type: String in ["Button", "SecondaryButton", "PrimaryButton"]:
		var primary := button_type == "PrimaryButton"
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var source_state := "pressed" if state == "hover_pressed" else state
			var source_type := "PrimaryButton" if primary and source_state in ["normal", "hover", "pressed"] else "Button"
			var style := target_theme.get_stylebox(source_state, source_type).duplicate() as StyleBoxFlat
			if style == null:
				continue
			match state:
				"normal": style.bg_color = Color("#805638" if primary else "#514033")
				"hover": style.bg_color = Color("#956741" if primary else "#68503c")
				"pressed", "hover_pressed": style.bg_color = Color("#64412c" if primary else "#3d3027")
				"disabled": style.bg_color = Color("#695a49")
				"focus": style.bg_color = Color.TRANSPARENT
			style.border_color = Color("#d3ae72" if state in ["hover", "focus"] else "#aa8053")
			target_theme.set_stylebox(state, button_type, style)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			target_theme.set_color(color_name, button_type, Color("#f5e5c5"))
		target_theme.set_color("font_disabled_color", button_type, Color("#c2ac8b"))
