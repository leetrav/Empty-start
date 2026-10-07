class_name RestResultView
extends CanvasLayer

signal continue_requested

@onready var _overlay: Control = %Overlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_description: Label = %ResultDescription
@onready var _continue_button: Button = %ContinueButton


# 隐藏结果面板并连接继续请求。
func _ready() -> void:
	_overlay.hide()
	_continue_button.pressed.connect(_on_continue_pressed)


# 只展示已经打开的未击破结果，不把奖励列表缺失解释为失败。
func show_unbroken_result(session: RestSession) -> bool:
	if session == null or not session.is_open():
		return false
	var result_snapshot: Dictionary = session.get_result_snapshot()
	if String(result_snapshot.get("result_kind", "")) != "pk_win_unbroken":
		return false

	_result_title.text = "PK 胜利 · 矛盾未击破"
	_result_description.text = "你赢下了本场 PK，但未能确认真正的矛盾。\n本场没有神谕或击败奖励，仍可继续后续流程。"
	_overlay.show()
	_continue_button.grab_focus()
	return true


# 重开当前尝试时同步收起已经显示的结果面板。
func hide_result() -> void:
	_overlay.hide()


# 继续流程由外层组合方决定；路由完成前保留结果提示。
func _on_continue_pressed() -> void:
	continue_requested.emit()
