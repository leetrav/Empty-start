extends SceneTree

const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")

func _initialize() -> void:
    assert(is_equal_approx(NUMERICS.initial_player_pk, 0.5))
    assert(is_equal_approx(NUMERICS.base_pullback_speed_pk_per_second, 0.0008))
    assert(is_equal_approx(NUMERICS.pc_aim_radius_px, 72.0))
    assert(is_equal_approx(NUMERICS.charge_time_seconds, 0.8))
    var reward: Dictionary = NUMERICS.get_normal_hit_reward(3, "orthodox")
    assert(is_equal_approx(float(reward["pk_delta"]), 0.012))
    assert(int(reward["tendency_delta"]) == 10)
    print("SHEET-A PASS core formal 06 numerical values and Resource")
    quit(0)
