class_name CombatStage
extends RefCounted

const INITIAL_TIER: int = 0

var _current_tier: int = INITIAL_TIER


func begin_combat() -> void:
	# 新一场或当前关重开时统一从 Tier 0 开始。
	_current_tier = INITIAL_TIER


func get_current_tier() -> int:
	return _current_tier
