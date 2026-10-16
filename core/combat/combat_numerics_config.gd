class_name CombatNumericsConfig
extends Resource

## 06 战斗数值、06 生命周期和 09 直播规则的正式运行时值；单位保持与源 CSV 一致。
@export var initial_player_pk: float = 0.5
@export var minimum_player_pk: float = 0.0
@export var maximum_player_pk: float = 1.0
@export var base_pullback_speed_pk_per_second: float = 0.0008
@export var pc_aim_radius_px: float = 72.0
@export var touch_aim_radius_px: float = 90.0
## 06 基础参数 aim_visual_size 的圆形视觉直径，不改变判定半径。
@export var aim_visual_diameter_px: float = 96.0
@export var charge_time_seconds: float = 0.8
@export var projectile_flight_seconds: float = 0.2
@export var recovery_time_seconds: float = 0.15
@export var normal_hit_pk_by_strength: PackedFloat32Array = PackedFloat32Array([0.0, 0.004, 0.007, 0.012])
@export var normal_hit_tendency_by_strength: PackedInt32Array = PackedInt32Array([0, 1, 5, 10])
@export var miss_penalty_pk: float = -0.01
@export var blocked_penalty_pk: float = -0.01
@export var fake_penalty_pk: float = -0.005
@export var retaliation_penalty_pk: float = -0.007
@export var reflect_penalty_pk: float = -0.01
@export var thunder_penalty_pk: float = -0.005
@export var positive_pk_shot_cap: float = 0.02
@export var negative_pk_shot_cap: float = 0.02
@export var special_foreground_instance_cap: int = 3
@export var foreground_interior_spawn_ratio: float = 0.65
@export var foreground_speed_change_period_seconds: float = 2.5
@export var foreground_wander_turn_interval_seconds: float = 2.0
@export var foreground_speed_cap_px_per_second: float = 95.0
@export var foreground_scale_min_ratio: float = 0.92
@export var foreground_scale_max_ratio: float = 1.08
@export var foreground_layer_change_interval_seconds: float = 3.0
@export var foreground_local_animation_probability: float = 0.15
@export var foreground_local_animation_intensity: float = 0.2
@export var foreground_outline_width_px: int = 2
@export var foreground_outline_color: Color = Color("#30272F")
@export var repeat_text_color: Color = Color("#888888")
@export var foreground_curve_amplitude_px: float = 72.0
@export var foreground_straight_spread_degrees: float = 30.0
@export var foreground_wander_speed_multiplier: float = 0.35
@export var lifetimes_by_type_seconds: Dictionary = {
	"word_strength_1": 8.0, "word_strength_2": 7.0, "word_strength_3": 6.0,
	"thunder": 7.0, "fake": 7.0, "retaliation": 5.0, "repeat": 3.0,
	"unselectable": 5.0, "split": 6.0,
}
@export var lifetime_tier_affected: Dictionary = {
	"word_strength_1": true, "word_strength_2": true, "word_strength_3": true,
	"thunder": false, "fake": false, "retaliation": false, "repeat": true,
	"unselectable": false, "split": true,
}
@export var opening_viewer_multiplier_min: float = 0.75
@export var opening_viewer_multiplier_max: float = 1.25
@export var normal_hit_viewer_delta: int = 2
@export var normal_hit_like_delta: int = 3
@export var trap_hit_viewer_delta: int = -2
@export var trap_hit_like_multiplier: float = 0.98
@export var tier_up_viewer_delta: int = 15
@export var high_tier_like_multiplier: float = 1.05
@export var pk_win_fan_gain: int = 120
@export var contradiction_break_viewer_gain: int = 80
@export var contradiction_break_like_gain: int = 40
@export var contradiction_break_boost_duration_seconds: float = 2.0
@export var contradiction_break_comment_delta: int = 1
@export var oracle_confirmation_viewer_gain: int = 40
@export var oracle_confirmation_like_gain: int = 20
@export var oracle_confirmation_boost_duration_seconds: float = 2.0
@export var oracle_confirmation_comment_delta: int = 1


## 按“PK 百分点”转换为运行时 0–1 比例；源 CSV 数值保留原单位。
func percentage_points_to_pk(value: float) -> float:
	return value / 100.0


## 按话语强度取正式收益，neutral 仍由调用方清零倾向增量。
func get_normal_hit_reward(strength: int, tendency_id: String = "") -> Dictionary:
	if strength < 1 or strength >= normal_hit_pk_by_strength.size():
		return {}
	var tendency_delta: int = normal_hit_tendency_by_strength[strength]
	if tendency_id == "neutral":
		tendency_delta = 0
	return {"pk_delta": normal_hit_pk_by_strength[strength], "tendency_delta": tendency_delta}


## 弹幕寿命只对 CSV 标记 affected_by_tier_lifetime_mult 的种类乘档位倍率。
func get_lifetime_seconds(barrage_type: String, tier_multiplier: float) -> float:
	if not lifetimes_by_type_seconds.has(barrage_type):
		return 0.0
	var lifetime: float = float(lifetimes_by_type_seconds[barrage_type])
	if bool(lifetime_tier_affected.get(barrage_type, false)):
		lifetime *= maxf(tier_multiplier, 0.0)
	return lifetime


## 06 基础参数的攻击时序字段构造出攻击组件使用的正式配置 Resource。
func create_attack_timing_config() -> AttackTimingConfig:
	var timing := AttackTimingConfig.new()
	timing.charge_time_s = charge_time_seconds
	timing.projectile_flight_s = projectile_flight_seconds
	timing.recovery_time_s = recovery_time_seconds
	return timing
