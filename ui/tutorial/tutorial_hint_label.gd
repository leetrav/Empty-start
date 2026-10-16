class_name TutorialHintLabel
extends Label


## TutorialStepRunner 的 hint_requested 信号可直接连接本方法。
func show_tutorial_hint(_step_id: String, hint_text: String) -> void:
	text = hint_text
	visible = not hint_text.is_empty()


## 流程结束或关卡重开时由教学拥有者显式清理提示。
func clear_tutorial_hint() -> void:
	text = ""
	visible = false
