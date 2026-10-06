extends SceneTree

const CombatStageScript = preload("res://core/combat/combat_stage.gd")


func _initialize() -> void:
	var tier_catalog: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	var combat_stage = CombatStageScript.new(tier_catalog)
	combat_stage.begin_combat()
	var upgraded: bool = combat_stage.try_tier_up(0.56)
	var test_passed: bool = upgraded and combat_stage.get_current_tier() == 1
	if test_passed:
		print("PASS CS-03 PK equal to upgrade threshold raises Tier")
		quit(0)
	else:
		push_error("CS-03 equal-threshold tier-up test failed.")
		quit(1)
