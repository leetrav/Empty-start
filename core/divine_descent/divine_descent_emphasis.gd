class_name DivineDescentEmphasis
extends CanvasLayer

signal finished

var _overlay: Control
var _tween: Tween
var _response_tween: Tween


# 最小本地全屏表现：遮罩与居中锁句沿用现有主题，没有正式素材时保留基础排版。
func _ready() -> void:
	layer = 15
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.theme = preload("res://ui/theme/base_theme.tres")
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	var background := ColorRect.new()
	background.color = Color.BLACK
	_overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sentence := Label.new()
	sentence.name = "Sentence"
	sentence.add_theme_font_size_override("font_size", 42)
	sentence.add_theme_color_override("font_color", Color(0.94,0.92,0.86))
	sentence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(sentence)
	sentence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sentence.offset_left = 180.0
	sentence.offset_right = -180.0
	sentence.mouse_filter = Control.MOUSE_FILTER_IGNORE


# 只播一次淡入、停留、淡出；真正结束后才通知所属 DD 组件。
func play(sentence_text: String, fade_seconds: float, hold_seconds: float) -> void:
	if _tween != null:
		return
	(_overlay.get_node("Sentence") as Label).text = sentence_text
	_overlay.modulate.a = 0.0
	_overlay.show()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_tween.tween_property(_overlay, "modulate:a", 1.0, fade_seconds)
	_tween.tween_interval(hold_seconds)
	# 黑底保留到路由接管，只让神谕文字退场，避免露出底下的PK。
	_tween.tween_property(_overlay.get_node("Sentence"), "modulate:a", 0.0, fade_seconds)
	_tween.finished.connect(_on_tween_finished)


# 15表给出总时长；淡入淡出各最多0.8秒，把主要时间留给完整阅读。
func play_for_total_duration(sentence_text: String, total_seconds: float) -> bool:
	if not is_finite(total_seconds) or total_seconds <= 0.0:
		return false
	var fade := minf(0.8, total_seconds * 0.2)
	play(sentence_text, fade, total_seconds - fade * 2.0)
	return true


# 输入只强化强调中的正文，原完成 Tween 的时序和单次 finished 保持原样。
func respond_to_player(scale_value: float, return_seconds: float) -> void:
	if not _overlay.visible or get_tree().paused:
		return
	var sentence := _overlay.get_node("Sentence") as Label
	sentence.pivot_offset = sentence.size * 0.5
	if _response_tween != null:
		_response_tween.kill()
	sentence.scale = Vector2.ONE * scale_value
	_response_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_response_tween.tween_property(sentence, "scale", Vector2.ONE, return_seconds)


# 黑底随当前场景生命周期保留，由路由在全黑时替换场景。
func _on_tween_finished() -> void:
	finished.emit()


# 离树取消动画；中断不会被误报成演出完成。
func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
