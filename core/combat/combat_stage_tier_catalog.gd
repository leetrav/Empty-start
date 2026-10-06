class_name CombatStageTierCatalog
extends Resource

@export var tier_0: CombatStageTierConfig
@export var tier_1: CombatStageTierConfig
@export var tier_2: CombatStageTierConfig
@export var tier_3: CombatStageTierConfig
@export var tier_4: CombatStageTierConfig
@export var tier_5: CombatStageTierConfig


func get_tier_config(tier: int) -> CombatStageTierConfig:
	# 按 Tier 编号读取静态参数；范围外没有当前阶段配置。
	match tier:
		0:
			return tier_0
		1:
			return tier_1
		2:
			return tier_2
		3:
			return tier_3
		4:
			return tier_4
		5:
			return tier_5
		_:
			return null
