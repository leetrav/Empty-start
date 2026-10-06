class_name ContradictionBreakSystem
extends Node

enum Outcome { PENDING, BREAKTHROUGH, NOT_BROKEN }

## 当前关卡的静态矛盾内容只由 LevelProfile 提供，不改写原始 Resource。
var _true_contradictions: Array[LevelContradiction] = []
var _false_contradictions: Array[LevelContradiction] = []
var _context_clues: Array[String] = []
var _window_timer: Timer
var _remaining_shots: int = 0
var _pending_shots: int = 0
var _window_active: bool = false
var _outcome: Outcome = Outcome.PENDING


func _ready() -> void:
	_window_timer = Timer.new()
	_window_timer.one_shot = true
	# Godot 的暂停模式会在全局暂停时保存 Timer 剩余时间。
	_window_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_window_timer)


# 在进入矛盾阶段时接收当前关卡；复制列表以固定本场读取到的内容。
func load_level_content(level_profile: LevelProfile) -> bool:
	if level_profile == null:
		return false
	_true_contradictions = level_profile.true_contradictions.duplicate()
	_false_contradictions = level_profile.false_contradictions.duplicate()
	_context_clues = level_profile.contradiction_context_clues.duplicate()
	return true


func get_true_contradictions() -> Array[LevelContradiction]:
	return _true_contradictions.duplicate()


func get_false_contradictions() -> Array[LevelContradiction]:
	return _false_contradictions.duplicate()


func get_context_clues() -> Array[String]:
	return _context_clues.duplicate()


# 由阶段协调者传入数值表配置；本系统只持有本场运行计时与机会。
func start_window(config: ContradictionWindowConfig) -> bool:
	if config == null or config.duration_seconds <= 0.0 or config.max_shots <= 0:
		return false
	if _window_timer == null:
		return false
	_remaining_shots = config.max_shots
	_pending_shots = 0
	_window_active = true
	_outcome = Outcome.PENDING
	_window_timer.start(config.duration_seconds)
	return true


func get_remaining_seconds() -> float:
	if not _window_active:
		return 0.0
	return _window_timer.time_left


func get_remaining_shots() -> int:
	return _remaining_shots


func get_outcome() -> Outcome:
	return _outcome


func can_launch_shot() -> bool:
	return _window_active and _remaining_shots > 0


# 只接收 AttackChargeInput 真正满蓄发射后产生的快照事实；取消蓄力不调用此入口。
func register_launched_shot() -> bool:
	if not can_launch_shot():
		return false
	_remaining_shots -= 1
	_pending_shots += 1
	return true


# 一发到达后只按稳定原句 ID 判定；矛盾命中不提交普通 PK 或倾向收益。
func resolve_shot_hit_ids(hit_sentence_ids: Array[String]) -> bool:
	if not _window_active or _pending_shots <= 0:
		return false
	_pending_shots -= 1
	for contradiction in _true_contradictions:
		if contradiction != null and hit_sentence_ids.has(contradiction.original_sentence_id):
			_outcome = Outcome.BREAKTHROUGH
			_window_active = false
			_window_timer.stop()
			return true
	return true
