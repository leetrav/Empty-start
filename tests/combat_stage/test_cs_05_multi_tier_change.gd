extends SceneTree

const CombatStageScript = preload("res://core/combat/combat_stage.gd")


func _initialize() -> void:
	var tier_catalog: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	var failed_count: int = 0
	if not _test_pk_increase_crosses_multiple_tiers(tier_catalog):
		push_error("CS-05 a large PK increase must cross multiple tiers.")
		failed_count += 1
	else:
		print("PASS CS-05 multi-tier increase")

	if not _test_pk_decrease_crosses_multiple_tiers(tier_catalog):
		push_error("CS-05 a large PK decrease must cross multiple tiers.")
		failed_count += 1
	else:
		print("PASS CS-05 multi-tier decrease")

	quit(1 if failed_count > 0 else 0)


func _test_pk_increase_crosses_multiple_tiers(tier_catalog: CombatStageTierCatalog) -> bool:
	var combat_stage = CombatStageScript.new(tier_catalog)
	combat_stage.begin_combat()
	var changed: bool = combat_stage.update_tier_for_pk(0.8)
	var test_passed: bool = changed and combat_stage.get_current_tier() == 4
	return test_passed


func _test_pk_decrease_crosses_multiple_tiers(tier_catalog: CombatStageTierCatalog) -> bool:
	var combat_stage = CombatStageScript.new(tier_catalog)
	combat_stage.begin_combat()
	for _index in range(5):
		combat_stage.try_tier_up(1.0)
	var changed: bool = combat_stage.update_tier_for_pk(0.52)
	var test_passed: bool = changed and combat_stage.get_current_tier() == 0
	return test_passed
