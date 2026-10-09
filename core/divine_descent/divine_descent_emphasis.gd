class_name DivineDescentEmphasis
extends CanvasLayer

signal finished

var _overlay: Control
var _tween: Tween


# 最小本地全屏表现：遮罩与居中锁句沿用现有主题，没有正式素材时保留基础排版。
func _ready() -> void:
	layer = 20
	_overlay = Control.new()
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
	sentence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(sentence)
	sentence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_tween.tween_property(_overlay, "modulate:a", 0.0, fade_seconds)
	_tween.finished.connect(_on_tween_finished)


# 先收起遮罩再发出事实，组合方可以安全展示 Ending 页面。
func _on_tween_finished() -> void:
	_overlay.hide()
	finished.emit()


# 离树取消动画；中断不会被误报成演出完成。
func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
