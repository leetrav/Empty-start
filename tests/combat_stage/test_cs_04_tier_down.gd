extends SceneTree

const CombatStageScript = preload("res://core/combat/combat_stage.gd")


func _initialize() -> void:
	var tier_catalog: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	var combat_stage = CombatStageScript.new(tier_catalog)
	combat_stage.begin_combat()
	combat_stage.try_tier_up(0.56)
	var downgraded: bool = combat_stage.try_tier_down(0.529)
	var test_passed: bool = downgraded and combat_stage.get_current_tier() == 0
	if test_passed:
		print("PASS CS-04 PK below downgrade threshold lowers Tier")
		quit(0)
	else:
		push_error("CS-04 below-threshold tier-down test failed.")
		quit(1)
