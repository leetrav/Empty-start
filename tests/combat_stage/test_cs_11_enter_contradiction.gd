extends SceneTree


# 单个关键用例验证满值产生阶段结果，边界使用独立 TEST_ONLY 数值。
func _initialize() -> void:
	var catalog: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	var stage: CombatStage = CombatStage.new(catalog)
	const TEST_ONLY_MAXIMUM_PK: float = 2.0
	stage.begin_combat()
	var passed: bool = (
		stage.get_stage_result(1.99, TEST_ONLY_MAXIMUM_PK) == CombatStage.StageResult.NORMAL_COMBAT
		and stage.get_stage_result(TEST_ONLY_MAXIMUM_PK, TEST_ONLY_MAXIMUM_PK) == CombatStage.StageResult.ENTER_CONTRADICTION
	)
	if passed:
		print("PASS CS-11 PK max produces ENTER_CONTRADICTION (1 case)")
	else:
		push_error("FAIL CS-11 PK max stage result")
	quit(0 if passed else 1)
