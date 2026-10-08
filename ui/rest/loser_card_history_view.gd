class_name LoserCardHistoryView
extends Control

signal back_requested

const CARD_ROW: PackedScene = preload("res://ui/rest/loser_card_history_row.tscn")

@onready var _state: Label = %HistoryState
@onready var _rows: VBoxContainer = %CardRows
@onready var _scroll: ScrollContainer = %HistoryScroll
@onready var _back_button: Button = %BackButton


# 历史子面板沿用圣典查看的组合方式，只通知返回请求。
func _ready() -> void:
	hide()
	_back_button.pressed.connect(_on_back_pressed)


# 只读已获卡片，顺序和获得规则由 LoserCardData 持有。
func show_history(loser_card_data: LoserCardData, catalog: LoserCardCatalog) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_state.hide()
	if loser_card_data == null:
		_state.text = "历史败者卡资料暂不可用，请返回休息面板。"
		_state.show()
	else:
		var cards: Array[Dictionary] = loser_card_data.get_acquired_cards(catalog)
		var has_missing_profile: bool = false
		for card: Dictionary in cards:
			var row_view := CARD_ROW.instantiate() as LoserCardHistoryRow
			_rows.add_child(row_view)
			row_view.show_card(card)
			if card["profile"] == null:
				has_missing_profile = true
		if cards.is_empty():
			_state.text = "败者卡：暂无已获卡片。"
			_state.show()
		elif has_missing_profile:
			_state.text = "已有卡片，当前卡片目录暂不可用；已获记录保留如下。" if catalog == null else "已获卡片中有档案暂缺，已获记录保留如下。"
			_state.show()
	_scroll.scroll_vertical = 0
	show()
	_back_button.grab_focus()


# 查看操作只发出返回通知，不登记或撤回奖励。
func _on_back_pressed() -> void:
	back_requested.emit()
