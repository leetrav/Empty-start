class_name ContradictionBreakSystem
extends Node

## 当前关卡的静态矛盾内容只由 LevelProfile 提供，不改写原始 Resource。
var _true_contradictions: Array[LevelContradiction] = []
var _false_contradictions: Array[LevelContradiction] = []
var _context_clues: Array[String] = []


# 在进入矛盾阶段时接收当前关卡；复制列表以固定本场读取到的内容。
func load_level_content(level_profile: LevelProfile) -> bool:
	if level_profile == null:
		return false
	_true_contradictions = level_profile.true_contradictions.duplicate()
	_false_contradictions = level_profile.false_contradictions.duplicate()
	_context_clues = level_profile.contradiction_context_clues.duplicate()
	return true


func get_true_contradictions() -> Array[LevelContradiction]:
	return _true_contradictions.duplicate()


func get_false_contradictions() -> Array[LevelContradiction]:
	return _false_contradictions.duplicate()


func get_context_clues() -> Array[String]:
	return _context_clues.duplicate()
