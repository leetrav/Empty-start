## TEST_ONLY：缺配表的两关奖励与演出参数仅注入内存副本。
extends "res://scenes/sandbox/sandbox.gd"

func _ready() -> void:
	level_catalog = preload("res://data/test_only/generated/level_configuration/test_only_level_catalog.tres").duplicate(true)
	battle_config = battle_config.duplicate(true)
	battle_config.attack_timing = preload("res://tests/fixtures/combat_attack/ca07_short_attack_timing.tres")
	battle_config.contradiction_repeat_count = 3
	battle_config.contradiction_repeat_lifetime_seconds = 0.3
	battle_config.repeat_lifetime_seconds = 0.6
	battle_config.pk_win_fan_gain = 7
	loser_card_catalog = LoserCardCatalog.new()
	var source: LoserCardCatalog = preload("res://tests/fixtures/fo11/test_loser_card_catalog.tres")
	for profile: LevelProfile in level_catalog.profiles:
		profile.base_move_speed_pixels_per_second = 0.0
		profile.normal_pool_inheritance = preload("res://tests/fixtures/fo11/test_normal_pool_inheritance.tres").duplicate(true)
		profile.normal_pool_inheritance.pool_id = StringName("test_int04_pool_" + profile.level_id)
		profile.inheritable_trait_ids = [&"occlusion"]
		var card: LoserCardProfile = source.profiles[0].duplicate(true)
		card.streamer_id = StringName(profile.streamer_id)
		card.streamer_name = profile.streamer_name
		loser_card_catalog.profiles.append(card)
	divine_decay_config = DivineDescentDecayConfig.new()
	divine_decay_config.new_word_decay_duration_seconds = 1.0
	divine_repeat_interval_seconds = 0.1
	divine_fade_seconds = 0.15
	divine_hold_seconds = 0.6
	divine_input_scale = 1.35
	divine_input_return_seconds = 0.2
	divine_trait_colors = {&"occlusion": Color.CYAN}
	super._ready()
