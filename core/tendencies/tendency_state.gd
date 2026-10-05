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


# 只有一个累计值严格高于另外两项时才返回主导倾向 ID。
func get_primary_tendency_id() -> String:
	if orthodox_total > heretical_total and orthodox_total > absurd_total:
		return "orthodox"
	if heretical_total > orthodox_total and heretical_total > absurd_total:
		return "heretical"
	if absurd_total > orthodox_total and absurd_total > heretical_total:
		return "absurd"
	return ""
