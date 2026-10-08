class_name RestResultView
extends CanvasLayer

signal continue_requested

# 只保留当前休息上下文的 Resource 引用，历史来源和正式内容归 15 持有。
var _history_scripture: ScriptureData
var _history_level_catalog: LevelCatalog

@onready var _overlay: Control = %Overlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_description: Label = %ResultDescription
@onready var _new_rewards_empty: Label = %NewRewardsEmpty
@onready var _history_empty_states: VBoxContainer = %HistoryEmptyStates
@onready var _scripture_history_empty: Label = %ScriptureHistoryEmpty
@onready var _loser_card_history_empty: Label = %LoserCardHistoryEmpty
@onready var _scripture_history_button: Button = %ScriptureHistoryButton
@onready var _scripture_history_unavailable: Label = %ScriptureHistoryUnavailable
@onready var _scripture_history: ScriptureHistoryView = %ScriptureHistoryView
@onready var _continue_button: Button = %ContinueButton


# 隐藏两个面板并连接查看、返回与继续请求。
func _ready() -> void:
	_overlay.hide()
	_scripture_history.hide()
	_continue_button.pressed.connect(_on_continue_pressed)
	_scripture_history_button.pressed.connect(_on_scripture_history_requested)
	_scripture_history.back_requested.connect(_on_scripture_history_back_requested)


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
	_history_scripture = run_data.scripture_data if run_data != null else null
	_history_level_catalog = level_catalog
	_scripture_history_button.disabled = _history_scripture == null or _history_level_catalog == null
	_scripture_history_unavailable.visible = _scripture_history_button.disabled
	# 缺少数据表示未知；真实历史集合为空时才显示对应空提示。
	_scripture_history_empty.visible = (
		_history_scripture != null and _history_level_catalog != null
		and _history_scripture.get_ordered_entries().is_empty()
	)
	_loser_card_history_empty.visible = (
		run_data != null and run_data.loser_card_data != null
		and run_data.loser_card_data.get_acquired_cards(loser_card_catalog).is_empty()
	)
	_history_empty_states.visible = _scripture_history_empty.visible or _loser_card_history_empty.visible
	_scripture_history.hide()
	_overlay.show()
	_continue_button.grab_focus()
	return true


# 重开时同步收起结果与历史面板，释放本次上下文引用。
func hide_result() -> void:
	_overlay.hide()
	_scripture_history.hide()
	_history_scripture = null
	_history_level_catalog = null


# 主动查看当前周目正式圣典，子面板复用现成章节适配与显示组件。
func _on_scripture_history_requested() -> void:
	_scripture_history.show_history(_history_scripture, _history_level_catalog)
	_overlay.hide()


# 返回原休息面板并恢复可用按钮焦点，结果与继续信号保持原状态。
func _on_scripture_history_back_requested() -> void:
	_scripture_history.hide()
	_overlay.show()
	if _scripture_history_button.disabled:
		_continue_button.grab_focus()
	else:
		_scripture_history_button.grab_focus()


# 继续流程由外层组合方决定；路由完成前保留结果提示。
func _on_continue_pressed() -> void:
	continue_requested.emit()
