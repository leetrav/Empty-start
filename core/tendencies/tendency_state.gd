class_name TendencyState
extends Resource

@export var orthodox_total: int = 0
@export var heretical_total: int = 0
@export var absurd_total: int = 0
@export var opening_identity_tendency_id: String = ""


# 开始新周目时清零累计值，并从开局 IdentityOption 复制比较参照。
func initialize_from_identity_option(identity_option: IdentityOption) -> void:
	orthodox_total = 0
	heretical_total = 0
	absurd_total = 0
	opening_identity_tendency_id = ""
	if identity_option != null:
		opening_identity_tendency_id = identity_option.tendency_id


# 返回最高分主导倾向；并列时先看开局参照，再按固定倾向顺序裁决。
func get_primary_tendency_id() -> String:
	return _resolve_tendency_tie(_get_top_tendency_ids())


# 从主导以外的正分项中选择最高项；没有正分项时次要沿用主导。
func get_secondary_tendency_id() -> String:
	var primary_tendency_id: String = get_primary_tendency_id()
	var remaining_tendency_ids: Array[String] = []
	for tendency_id in ["orthodox", "heretical", "absurd"]:
		if tendency_id != primary_tendency_id and _get_tendency_total(tendency_id) > 0:
			remaining_tendency_ids.append(tendency_id)
	if remaining_tendency_ids.is_empty():
		return primary_tendency_id

	var highest_remaining_score: int = 0
	for tendency_id in remaining_tendency_ids:
		highest_remaining_score = maxi(highest_remaining_score, _get_tendency_total(tendency_id))

	var top_secondary_ids: Array[String] = []
	for tendency_id in remaining_tendency_ids:
		if _get_tendency_total(tendency_id) == highest_remaining_score:
			top_secondary_ids.append(tendency_id)
	return _resolve_tendency_tie(top_secondary_ids)


# 并列标记由当前累计值即时计算，避免保存第二份可派生状态。
func is_primary_tied() -> bool:
	return _get_top_tendency_ids().size() > 1


# 收集当前所有最高分项，供主导倾向裁决和并列标记共用。
func _get_top_tendency_ids() -> Array[String]:
	var highest_score: int = maxi(maxi(orthodox_total, heretical_total), absurd_total)
	var top_tendency_ids: Array[String] = []
	if orthodox_total == highest_score:
		top_tendency_ids.append("orthodox")
	if heretical_total == highest_score:
		top_tendency_ids.append("heretical")
	if absurd_total == highest_score:
		top_tendency_ids.append("absurd")
	return top_tendency_ids


# 对任意候选并列项沿用开局参照优先，再按正统 / 异端 / 荒谬排序。
func _resolve_tendency_tie(tendency_ids: Array[String]) -> String:
	if tendency_ids.size() == 1:
		return tendency_ids[0]
	if tendency_ids.has(opening_identity_tendency_id):
		return opening_identity_tendency_id
	if tendency_ids.has("orthodox"):
		return "orthodox"
	if tendency_ids.has("heretical"):
		return "heretical"
	if tendency_ids.has("absurd"):
		return "absurd"
	return ""


func _get_tendency_total(tendency_id: String) -> int:
	match tendency_id:
		"orthodox":
			return orthodox_total
		"heretical":
			return heretical_total
		"absurd":
			return absurd_total
		_:
			return 0
