## 终局战斗规则边界；不负责进入神降临，也不持有终局历史快照。
class_name DivineDescentCombatMode
extends RefCounted

signal terminal_mode_started(initial_tier: int, tier_config: CombatStageTierConfig)
signal new_word_rate_changed(rate_multiplier: float, progress: float)

const TERMINAL_TIER: int = 5

var _active: bool = false
var _tier5_config: CombatStageTierConfig
var _barrage_area: BarrageArea
var _opponent_pk_bar: OpponentPKBar
var _decay_config: DivineDescentDecayConfig
var _decay_elapsed_seconds: float = 0.0
var _new_word_rate_multiplier: float = 0.0


# 应用 Tier 5 初始表现并锁定普通战斗规则；新话由 DD-05 的衰减接口继续控制。
func enter_terminal_mode(
		tier_catalog: CombatStageTierCatalog,
		hit_resolution: HitResolution = null,
		combat_stage: CombatStage = null,
		contradiction_break: ContradictionBreakSystem = null,
		barrage_area: BarrageArea = null,
		opponent_pk_bar: OpponentPKBar = null
	) -> bool:
	if _active or tier_catalog == null:
		return false
	var tier5_config: CombatStageTierConfig = tier_catalog.get_tier_config(TERMINAL_TIER)
	if tier5_config == null:
		return false
	if combat_stage != null and not combat_stage.enter_terminal_tier(TERMINAL_TIER):
		return false

	_active = true
	_tier5_config = tier5_config
	_decay_config = null
	_decay_elapsed_seconds = 0.0
	_new_word_rate_multiplier = _tier5_config.generation_frequency_multiplier
	_barrage_area = barrage_area
	_opponent_pk_bar = opponent_pk_bar
	if hit_resolution != null:
		# 终局命中仍可由后续表现流程读取，但普通 PK 数值不再变化。
		hit_resolution.set_normal_pk_resolution_enabled(false)
	if contradiction_break != null:
		contradiction_break.set_contradiction_break_enabled(false)
	if _barrage_area != null:
		# 只切换后续表现参数；不清理现有视图，后续终局流程仍可复用生成入口。
		_barrage_area.set_generation_multipliers(
			_tier5_config.generation_count_multiplier,
			_tier5_config.generation_frequency_multiplier,
			_tier5_config.movement_speed_multiplier
		)
		_barrage_area.set_lifetime_multiplier(_tier5_config.lifetime_multiplier)
		_barrage_area.stop_contradiction_generation()
	if _opponent_pk_bar != null:
		# 终局不再持续回拉玩家 PK。
		_opponent_pk_bar.stop_pullback()
	terminal_mode_started.emit(TERMINAL_TIER, _tier5_config)
	return true


# 终局开始时保留 Tier 5 新话率；后续帧由该接口按配置时长推进到零。
func start_new_word_decay(config: DivineDescentDecayConfig) -> bool:
	if not _active or config == null or config.new_word_decay_duration_seconds <= 0.0:
		return false
	_decay_config = config
	_decay_elapsed_seconds = 0.0
	_new_word_rate_multiplier = _tier5_config.generation_frequency_multiplier
	_apply_new_word_rate()
	new_word_rate_changed.emit(_new_word_rate_multiplier, 0.0)
	return true


# 推进终局新话衰减；到达配置时长后频率固定为零并停止生成 Timer。
func advance_new_word_decay(delta_seconds: float) -> float:
	if _decay_config == null:
		return _new_word_rate_multiplier
	_decay_elapsed_seconds = minf(
		_decay_elapsed_seconds + maxf(delta_seconds, 0.0),
		_decay_config.new_word_decay_duration_seconds
	)
	var progress: float = _decay_elapsed_seconds / _decay_config.new_word_decay_duration_seconds
	_new_word_rate_multiplier = lerpf(_tier5_config.generation_frequency_multiplier, 0.0, progress)
	_apply_new_word_rate()
	new_word_rate_changed.emit(_new_word_rate_multiplier, progress)
	return _new_word_rate_multiplier


func get_new_word_rate_multiplier() -> float:
	return _new_word_rate_multiplier


func get_new_word_decay_progress() -> float:
	if _decay_config == null:
		return 0.0
	return _decay_elapsed_seconds / _decay_config.new_word_decay_duration_seconds


func is_new_word_decay_complete() -> bool:
	return _decay_config != null and is_equal_approx(get_new_word_decay_progress(), 1.0)


# 只更新弹幕生成系统的频率，Tier 5 的产量、移动和寿命参数保持不变。
func _apply_new_word_rate() -> void:
	if _barrage_area == null or _tier5_config == null:
		return
	_barrage_area.set_generation_multipliers(
		_tier5_config.generation_count_multiplier,
		_new_word_rate_multiplier,
		_tier5_config.movement_speed_multiplier
	)


# 终局流程用此状态判断普通规则是否仍可驱动；进入前保留普通战斗默认值。
func is_terminal_mode_active() -> bool:
	return _active


func get_initial_tier() -> int:
	return TERMINAL_TIER if _active else -1


func get_tier5_config() -> CombatStageTierConfig:
	return _tier5_config


# 普通命中结算、Tier 升降和矛盾入口都必须通过这些公开边界判断。
func allows_normal_pk_resolution() -> bool:
	return not _active


func allows_tier_changes() -> bool:
	return not _active


func allows_contradiction_break() -> bool:
	return not _active


# 终局继续保留 BarrageGeneration 的生成 / 寿命能力，交给后续扩散和锁句流程调用。
func keeps_barrage_presentation() -> bool:
	return _active
