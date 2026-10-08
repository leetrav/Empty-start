class_name EndingScriptureRow
extends PanelContainer

@onready var _number: Label = %ChapterNumber
@onready var _streamer: Label = %StreamerName
@onready var _text: Label = %ScriptureText


# 入树后呈现 EN-04 经文行；缺章没有节号，正文直接采用确认原文。
func show_row(row: Dictionary) -> void:
	var chapter: int = int(row.get("chapter_number", 0))
	var has_oracle: bool = bool(row.get("has_oracle", false))
	_number.text = "第 %d 章 · 第 %d 节" % [chapter, int(row.get("verse_number", 0))] if has_oracle else "第 %d 章" % chapter
	_streamer.text = str(row.get("streamer_name", ""))
	_streamer.visible = has_oracle and not _streamer.text.is_empty()
	_text.text = str(row.get("original_line_text", "")) if has_oracle else "未形成神谕"
