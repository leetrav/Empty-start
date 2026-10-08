class_name RestResultView
extends CanvasLayer

signal continue_requested

@onready var _overlay: Control = %Overlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_description: Label = %ResultDescription
@onready var _new_rewards_empty: Label = %NewRewardsEmpty
@onready var _history_empty_states: VBoxContainer = %HistoryEmptyStates
@onready var _scripture_history_empty: Label = %ScriptureHistoryEmpty
@onready var _loser_card_history_empty: Label = %LoserCardHistoryEmpty
@onready var _continue_button: Button = %ContinueButton


# 隐藏结果面板并连接继续请求。
func _ready() -> void:
	_overlay.hide()
	_continue_button.pressed.connect(_on_continue_pressed)


# 保留未击破专用入口；没有周目数据时只显示本场说明。
func show_unbroken_result(session: RestSession) -> bool:
	if session == null or not session.is_open():
		return false
	var result_snapshot: Dictionary = session.get_result_snapshot()
	if String(result_snapshot.get("result_kind", "")) != "pk_win_unbroken":
		return false
	return show_result(session)


# 空态只读 Session 聚合结果和成果系统历史快照，继续入口始终保留。
func show_result(
		session: RestSession,
		run_data: SaveData = null,
		level_catalog: LevelCatalog = null,
		loser_card_catalog: LoserCardCatalog = null
	) -> bool:
	if session == null or not session.is_open():
		return false
	var result_kind: String = String(session.get_result_snapshot().get("result_kind", ""))
	if run_data == null and result_kind != "pk_win_unbroken":
		return false
	if result_kind == "pk_win_unbroken":
		_result_title.text = "PK 胜利 · 矛盾未击破"
		_result_description.text = "你赢下了本场 PK，但未能确认真正的矛盾。\n本场没有神谕或击败奖励，仍可继续后续流程。"
	else:
		_result_title.text = "本场直播结束"
		_result_description.text = "本场结果已保存。"

	var rewards: Dictionary = session.read_committed_rewards(run_data, level_catalog, loser_card_catalog)
	var new_assimilation: Dictionary = rewards["new_assimilation"]
	_new_rewards_empty.visible = (
		rewards["new_scripture_entry"] == null
		and rewards["new_loser_card"] == null
		and new_assimilation.is_empty()
	)
	# 缺少数据表示未知；真实历史集合为空时才显示对应空提示。
	_scripture_history_empty.visible = (
		run_data != null and run_data.scripture_data != null
		and run_data.scripture_data.get_ordered_entries().is_empty()
	)
	_loser_card_history_empty.visible = (
		run_data != null and run_data.loser_card_data != null
		and run_data.loser_card_data.get_acquired_cards(loser_card_catalog).is_empty()
	)
	_history_empty_states.visible = _scripture_history_empty.visible or _loser_card_history_empty.visible
	_overlay.show()
	_continue_button.grab_focus()
	return true


# 重开当前尝试时同步收起已经显示的结果面板。
func hide_result() -> void:
	_overlay.hide()


# 继续流程由外层组合方决定；路由完成前保留结果提示。
func _on_continue_pressed() -> void:
	continue_requested.emit()
