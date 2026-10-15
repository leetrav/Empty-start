extends SceneTree


func _initialize() -> void:
	var catalog := BarrageTraitCatalog.new()
	assert(catalog.load_production_tables())
	assert(catalog.get_trait_count() == 6)
	assert(catalog.get_enabled_skill_count() == 32)
	assert(catalog.get_trait_definition(&"fake_card").get("lifetime_override_s", "") == "7")
	var alien := catalog.choose_skill("alien", 2, _fixed_rng(1))
	var kiwi := catalog.choose_skill("kiwi", 3, _fixed_rng(1))
	assert(alien.get("skill_id", "") == "alien_t2_occlusion")
	assert(kiwi.get("skill_id", "") in ["kiwi_t3_retaliation_copy", "kiwi_t3_fake_card"])
	assert(catalog.get_skill_trait_ids(alien) == [&"occlusion"])
	assert(catalog.get_skill_trait_ids(kiwi).size() == 1)
	assert(catalog.get_skill_trait_ids(kiwi)[0] in [&"retaliation_copy", &"fake_card"])
	assert(catalog.choose_skill("alien", 1).is_empty())
	var runner := TutorialStepRunner.new()
	var hints: Array[String] = []
	runner.hint_requested.connect(func(_id: String, hint: String) -> void: hints.append(hint))
	assert(runner.begin("tutorial_level_001"))
	assert(runner.notify_event("tutorial_target_available"))
	assert(hints.size() == 1)
	assert(runner.notify_event("tutorial_aim_acquired"))
	assert(runner.get_active_step_id() == "tutorial_001_charge")
	assert(runner.notify_event("tutorial_charge_full"))
	assert(runner.get_active_step_id() == "tutorial_001_fire")
	assert(runner.notify_event("tutorial_normal_hit"))
	quit()


func _fixed_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
