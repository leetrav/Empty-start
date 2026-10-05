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
	var top_tendency_ids: Array[String] = _get_top_tendency_ids()
	if top_tendency_ids.size() == 1:
		return top_tendency_ids[0]
	if top_tendency_ids.has(opening_identity_tendency_id):
		return opening_identity_tendency_id
	if top_tendency_ids.has("orthodox"):
		return "orthodox"
	if top_tendency_ids.has("heretical"):
		return "heretical"
	if top_tendency_ids.has("absurd"):
		return "absurd"
	return ""


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
