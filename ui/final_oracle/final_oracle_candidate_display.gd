class_name FinalOracleCandidateDisplay
extends Control

const MAX_CANDIDATE_COUNT: int = 3
const TARGET_SIZE: Vector2 = Vector2(920.0, 176.0)
const TARGET_FONT_SIZE: int = 30
const CANDIDATE_ID_META: StringName = &"final_oracle_candidate_id"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


# 只显示冻结快照中的原句正文；返回的 Label 控件交给普通攻击组件作为瞄准目标。
func show_candidates(candidates: Array[Dictionary]) -> Array[Control]:
	clear_display()
	if candidates.is_empty() or candidates.size() > MAX_CANDIDATE_COUNT:
		push_error("FinalOracleCandidateDisplay: 候选数量必须在 1 到 3 句之间。")
		return []

	var target_controls: Array[Control] = []
	var vertical_centers: Array[float] = _get_vertical_centers(candidates.size())
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		var sentence_id: String = str(candidate.get("original_sentence_id", ""))
		var sentence_text: String = str(candidate.get("original_sentence_text", ""))
		if sentence_id.is_empty() or sentence_text.is_empty():
			clear_display()
			push_error("FinalOracleCandidateDisplay: 冻结候选缺少原句 ID 或正文。")
			return []

		var label: Label = _create_sentence_label(sentence_text, vertical_centers[index])
		label.set_meta(CANDIDATE_ID_META, sentence_id)
		add_child(label)
		target_controls.append(label)
	show()
	return target_controls


# 首次确认后只保留最终原句文本，并移除所有可攻击目标。
func show_confirmed_candidate(candidate: Dictionary) -> void:
	clear_display()
	var sentence_text: String = str(candidate.get("original_sentence_text", ""))
	if sentence_text.is_empty():
		push_error("FinalOracleCandidateDisplay: 已确认候选缺少原句正文。")
		return
	add_child(_create_sentence_label(sentence_text, size.y * 0.5))
	show()


# 读取显示目标上绑定的稳定原句 ID，候选内容仍由 FinalOracleSession 持有。
func get_candidate_id_for_target(target: Control) -> String:
	if target == null or not is_instance_valid(target) or target.get_parent() != self:
		return ""
	return str(target.get_meta(CANDIDATE_ID_META, ""))


# 清理场上候选或确认文本，不影响 Session 保存的候选快照。
func clear_display() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	hide()


# 候选保持固定位置；相邻文字框留出窄间隙，准心边缘可能覆盖两条时再按中心裁决。
func _get_vertical_centers(candidate_count: int) -> Array[float]:
	match candidate_count:
		1:
			return [size.y * 0.5]
		2:
			return [size.y * 0.37, size.y * 0.63]
		3:
			return [size.y * 0.25, size.y * 0.5, size.y * 0.75]
		_:
			return []


# 文本 Label 本身就是候选命中区域；不创建卡片、按钮或倾向标签。
func _create_sentence_label(sentence_text: String, vertical_center: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.add_theme_font_size_override("font_size", TARGET_FONT_SIZE)
	label.custom_minimum_size = TARGET_SIZE
	label.custom_maximum_size = TARGET_SIZE
	label.size = TARGET_SIZE
	label.position = Vector2((size.x - TARGET_SIZE.x) * 0.5, vertical_center - TARGET_SIZE.y * 0.5)
	label.text = sentence_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
