class_name ScriptureHistoryView
extends Control

signal back_requested

const SCRIPTURE_ROW: PackedScene = preload("res://ui/ending/ending_scripture_row.tscn")

@onready var _state: Label = %HistoryState
@onready var _rows: VBoxContainer = %ScriptureRows
@onready var _scroll: ScrollContainer = %HistoryScroll
@onready var _back_button: Button = %BackButton


# 历史子面板只负责展示和返回请求，页面切换由 RestResultView 组合。
func _ready() -> void:
	hide()
	_back_button.pressed.connect(_on_back_pressed)


# 入树后读取正式圣典，章节顺序、缺章和编号沿用现有适配器与经文行。
func show_history(scripture_data: ScriptureData, level_catalog: LevelCatalog) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_state.hide()
	if scripture_data == null or level_catalog == null:
		_state.text = "历史圣典资料暂不可用，请返回休息面板。"
		_state.show()
	else:
		var display_rows: Array[Dictionary] = EndingScriptureDisplayData.new().build_from_scripture(scripture_data, level_catalog)
		if display_rows.is_empty():
			_state.text = "当前章节目录暂无可查看内容。"
			_state.show()
		elif scripture_data.get_ordered_entries().is_empty():
			_state.text = "圣典暂无已保存经文。尚未形成神谕的章节保留如下。"
			_state.show()
		for row: Dictionary in display_rows:
			var row_view := SCRIPTURE_ROW.instantiate() as EndingScriptureRow
			_rows.add_child(row_view)
			row_view.show_row(row)
	_scroll.scroll_vertical = 0
	show()
	_back_button.grab_focus()


# 返回只通知父面板，查看操作不会提交或撤回经文。
func _on_back_pressed() -> void:
	back_requested.emit()
