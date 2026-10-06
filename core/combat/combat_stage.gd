class_name CombatStage
extends RefCounted

signal opponent_tier_state_changed(pullback_multiplier: float, tier5_desperation_active: bool)
signal barrage_generation_multipliers_changed(count_multiplier: float, frequency_multiplier: float, movement_speed_multiplier: float)
signal barrage_lifetime_multiplier_changed(lifetime_multiplier: float)

const INITIAL_TIER: int = 0

var _tier_catalog: CombatStageTierCatalog
var _current_tier: int = INITIAL_TIER


func _init(tier_catalog: CombatStageTierCatalog) -> void:
	# 注入本系统静态 Tier 配置；运行时当前档位继续由 CombatStage 自己持有。
	_tier_catalog = tier_catalog


func begin_combat() -> void:
	# 新一场或当前关重开时统一从 Tier 0 开始。
	_current_tier = INITIAL_TIER
	_publish_current_tier_state()


func get_current_tier() -> int:
	return _current_tier


func get_current_repeat_count_per_hit() -> int:
	# 给复读计划创建方读取当前 Tier 的每次命中复读数量。
	var current_config: CombatStageTierConfig = _tier_catalog.get_tier_config(_current_tier)
	return current_config.repeat_count_per_hit


func bind_hit_resolution(hit_resolution: HitResolution) -> void:
	# 监听命中结算的最终 PK 事实；整发攻击和每次回拉共用同一入口。
	hit_resolution.final_player_pk_updated.connect(_on_final_player_pk_updated)


func bind_opponent_pk_bar(opponent_pk_bar: OpponentPKBar) -> void:
	# Tier 配置只通过信号通知对手系统；同一对象重复绑定时不重复连接。
	var callback: Callable = Callable(opponent_pk_bar, "apply_tier_state")
	if not opponent_tier_state_changed.is_connected(callback):
		opponent_tier_state_changed.connect(callback)
	_publish_opponent_tier_state()


func bind_barrage_area(barrage_area: BarrageArea) -> void:
	# 复用弹幕生成系统现有的倍率入口，并在绑定时补发当前 Tier 配置。
	var generation_callback: Callable = Callable(barrage_area, "set_generation_multipliers")
	if not barrage_generation_multipliers_changed.is_connected(generation_callback):
		barrage_generation_multipliers_changed.connect(generation_callback)
	var lifetime_callback: Callable = Callable(barrage_area, "set_lifetime_multiplier")
	if not barrage_lifetime_multiplier_changed.is_connected(lifetime_callback):
		barrage_lifetime_multiplier_changed.connect(lifetime_callback)
	_publish_barrage_multipliers()


func _on_final_player_pk_updated(final_player_pk: float) -> void:
	update_tier_for_pk(final_player_pk)


func try_tier_up(final_player_pk: float) -> bool:
	# 达到当前档位配置的升档阈值时最多升一档，Tier 5 留给矛盾阶段处理。
	if _current_tier >= 5:
		return false

	var current_config: CombatStageTierConfig = _tier_catalog.get_tier_config(_current_tier)
	if final_player_pk < current_config.upgrade_threshold:
		return false

	_current_tier += 1
	return true


func try_tier_down(final_player_pk: float) -> bool:
	# 只有 PK 严格低于当前档位的降档阈值时才下降一档。
	if _current_tier <= INITIAL_TIER:
		return false

	var current_config: CombatStageTierConfig = _tier_catalog.get_tier_config(_current_tier)
	if final_player_pk >= current_config.downgrade_threshold:
		return false

	_current_tier -= 1
	return true


func update_tier_for_pk(final_player_pk: float) -> bool:
	# 重复调用已实现的单档规则，直到该 PK 不再跨越升档或降档阈值。
	var tier_changed: bool = false
	while try_tier_up(final_player_pk):
		tier_changed = true
	while try_tier_down(final_player_pk):
		tier_changed = true
	if tier_changed:
		_publish_current_tier_state()
	return tier_changed


func _publish_current_tier_state() -> void:
	# 先确定唯一当前 Tier，再把同一配置分别交给各系统。
	_publish_opponent_tier_state()
	_publish_barrage_multipliers()


func _publish_opponent_tier_state() -> void:
	# Tier 稳定后再广播最终倍率与 Tier 5 状态，不发送跨档中间值。
	var current_config: CombatStageTierConfig = _tier_catalog.get_tier_config(_current_tier)
	opponent_tier_state_changed.emit(
		current_config.opponent_pullback_multiplier,
		_current_tier == 5
	)


func _publish_barrage_multipliers() -> void:
	# 弹幕系统只接收倍率，具体生成、速度和寿命应用由 BarrageArea 负责。
	var current_config: CombatStageTierConfig = _tier_catalog.get_tier_config(_current_tier)
	barrage_generation_multipliers_changed.emit(
		current_config.generation_count_multiplier,
		current_config.generation_frequency_multiplier,
		current_config.movement_speed_multiplier
	)
	barrage_lifetime_multiplier_changed.emit(current_config.lifetime_multiplier)
