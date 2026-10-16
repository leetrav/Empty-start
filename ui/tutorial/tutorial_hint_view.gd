## 只渲染 24 表运行器发来的提示；步骤裁决与完成进度归 TutorialStepRunner。
extends PanelContainer

var _runner: Object
var _step_id: String = ""
@onready var _hint: Label = $Margin/Hint


# 在 runner.begin() 前绑定；兼容 C 的 RefCounted 运行器，不复制教程状态机。
func bind_runner(runner: Object) -> bool:
	if is_instance_valid(_runner):
		_runner.disconnect("hint_requested", show_hint)
		_runner.disconnect("step_completed", _on_step_completed)
		_runner.disconnect("tutorial_completed", _on_tutorial_completed)
	_runner = null
	clear_hint()
	if runner == null:
		return true
	for signal_id: StringName in [&"hint_requested", &"step_completed", &"tutorial_completed"]:
		if not runner.has_signal(signal_id):
			return false
	_runner = runner
	_runner.connect("hint_requested", show_hint)
	_runner.connect("step_completed", _on_step_completed)
	_runner.connect("tutorial_completed", _on_tutorial_completed)
	return true


# 文案直接来自正式 hint_text；空提示关闭面板，鼠标和触屏继续穿透。
func show_hint(step_id: String, hint_text: String) -> void:
	_step_id = step_id
	_hint.text = hint_text
	visible = not hint_text.strip_edges().is_empty()


# 重开或离开战斗时由组合方显式清理，既有进度继续归周目所有者。
func clear_hint() -> void:
	_step_id = ""
	if is_node_ready():
		_hint.text = ""
	hide()


# 已完成的步骤立即移除旧提示；下一步 hint_requested 会展示新文案。
func _on_step_completed(step_id: String) -> void:
	if step_id == _step_id:
		clear_hint()


# 最后一步完成后隐藏教程面板。
func _on_tutorial_completed(_config_id: String) -> void:
	clear_hint()


# 解除对象信号引用，允许场景正常释放。
func _exit_tree() -> void:
	bind_runner(null)
