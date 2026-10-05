class_name CombatStage
extends RefCounted

const INITIAL_TIER: int = 0

var _tier_catalog: CombatStageTierCatalog
var _current_tier: int = INITIAL_TIER


func _init(tier_catalog: CombatStageTierCatalog) -> void:
	# 注入本系统静态 Tier 配置；运行时当前档位继续由 CombatStage 自己持有。
	_tier_catalog = tier_catalog


func begin_combat() -> void:
	# 新一场或当前关重开时统一从 Tier 0 开始。
	_current_tier = INITIAL_TIER


func get_current_tier() -> int:
	return _current_tier


func bind_hit_resolution(hit_resolution: HitResolution) -> void:
	# 监听命中结算的最终 PK 事实；整发攻击和每次回拉共用同一入口。
	hit_resolution.final_player_pk_updated.connect(_on_final_player_pk_updated)


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
	return tier_changed
