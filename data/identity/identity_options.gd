class_name IdentityOptions
extends RefCounted

# 正式卡片按策划固定混排；旧资源仅用于读取已确认身份。
const CARDS: Array[IdentityOption] = [
	preload("res://data/identity/identity_orthodox_1.tres"),
	preload("res://data/identity/identity_heresy_4.tres"),
	preload("res://data/identity/identity_absurd_1.tres"),
	preload("res://data/identity/identity_heresy_2.tres"),
	preload("res://data/identity/identity_absurd_2.tres"),
	preload("res://data/identity/identity_orthodox_3.tres"),
	preload("res://data/identity/identity_heresy_3.tres"),
	preload("res://data/identity/identity_absurd_4.tres"),
	preload("res://data/identity/identity_orthodox_4.tres"),
	preload("res://data/identity/identity_absurd_3.tres"),
	preload("res://data/identity/identity_orthodox_2.tres"),
	preload("res://data/identity/identity_heresy_1.tres"),
]
const LEGACY: Array[IdentityOption] = [
	preload("res://data/identity/identity_orthodox_placeholder.tres"),
	preload("res://data/identity/identity_heretical_placeholder.tres"),
	preload("res://data/identity/identity_absurd_placeholder.tres"),
]

# 查询具体身份，兼容旧存档且保持原 ID。
static func find_option(identity_id: StringName) -> IdentityOption:
	for option in CARDS + LEGACY:
		if option.identity_id == identity_id:
			return option
	return null
