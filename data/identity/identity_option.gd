class_name IdentityOption
extends Resource

@export var identity_id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

# 倾向只保存稳定标识，累计与判定由三项倾向系统负责。
@export_enum("orthodox", "heretical", "absurd") var tendency_id: String = "orthodox"
