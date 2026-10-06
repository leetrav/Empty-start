## 负责普通战斗的批次计时、倍率应用与单条弹幕实例化。
class_name BarrageArea
extends Control

@export var barrage_view_scene: PackedScene
## 所有舞台区域共享的设计尺寸；本系统只读取中央弹幕区域。
@export var stage_layout_profile: StageLayoutProfile
## 临时全局基础寿命，正式数值表接入前可在 Inspector 调整。
@export var base_lifetime_seconds: float = 10.0
## 临时复读同屏上限，正式数值表接入前可在 Inspector 调整。
@export var repeat_barrage_screen_cap: int = 24
@onready var _spawn_timer: Timer = $SpawnTimer

var _speech_selector: NormalSpeechSelector = NormalSpeechSelector.new()
var _current_level_profile: LevelProfile
var _normal_generation_enabled: bool = false
var _count_multiplier: float = 1.0
var _frequency_multiplier: float = 1.0
var _movement_speed_multiplier: float = 1.0
var _lifetime_multiplier: float = 1.0
## 普通话语与陷阱共用的容量账本。
var _normal_capacity_ledger: BarrageCapacityLedger = BarrageCapacityLedger.new()
var _repeat_capacity_ledger: BarrageCapacityLedger = BarrageCapacityLedger.new()

## 连接本组件的批次 Timer 超时信号。
func _ready() -> void:
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_apply_stage_layout()

## 将资源中的中央弹幕区域转换成相对基准分辨率的 Control 锚点。
func _apply_stage_layout() -> void:
	if stage_layout_profile == null:
		return
	var base_resolution: Vector2i = stage_layout_profile.base_resolution
	if base_resolution.x <= 0 or base_resolution.y <= 0:
		push_error("BarrageArea: 舞台基准分辨率必须大于零。")
		return
	var area_rect: Rect2i = stage_layout_profile.central_barrage_area_rect
	anchor_left = float(area_rect.position.x) / float(base_resolution.x)
	anchor_top = float(area_rect.position.y) / float(base_resolution.y)
	anchor_right = float(area_rect.position.x + area_rect.size.x) / float(base_resolution.x)
	anchor_bottom = float(area_rect.position.y + area_rect.size.y) / float(base_resolution.y)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

## 打开普通生成并立即生成第一批，之后按当前关卡间隔与频率倍率循环。
func start_normal_generation(level_profile: LevelProfile) -> bool:
	if level_profile == null or level_profile.base_spawn_interval_seconds <= 0.0:
		return false
	if _normal_generation_enabled:
		if _current_level_profile == level_profile:
			return true
		stop_normal_generation()
	_current_level_profile = level_profile
	_normal_generation_enabled = true
	if _frequency_multiplier > 0.0:
		_spawn_normal_batch()
	_restart_spawn_timer()
	return true

## 更新倍率只影响后续批次和新弹幕；已有实例保留创建时的移动速度。
func set_generation_multipliers(generation_count_multiplier: float, generation_frequency_multiplier: float, movement_speed_multiplier: float) -> void:
	_count_multiplier = generation_count_multiplier
	_frequency_multiplier = generation_frequency_multiplier
	_movement_speed_multiplier = movement_speed_multiplier
	_restart_spawn_timer()

## 保存当前寿命倍率；它只参与之后新建弹幕的截止时间计算。
func set_lifetime_multiplier(lifetime_multiplier: float) -> void:
	_lifetime_multiplier = lifetime_multiplier

## 申请普通弹幕共享容量；未设置当前关卡或容量满时返回 false。
func try_register_normal_capacity_occupant(occupant: Object) -> bool:
	if _current_level_profile == null:
		return false
	return _try_register_normal_capacity_occupant(occupant, _current_level_profile.normal_barrage_screen_cap)

## 释放占位对象；普通弹幕节点离树时会自动调用此入口。
func release_normal_capacity_occupant(occupant: Object) -> bool:
	if not _normal_capacity_ledger.release(occupant):
		return false
	_restart_spawn_timer()
	return true

## 以当前关卡的容量限制登记普通弹幕或陷阱占位者。
func _try_register_normal_capacity_occupant(occupant: Object, capacity_limit: int) -> bool:
	if occupant == null:
		return false
	if _normal_capacity_ledger.has_occupant(occupant):
		return true
	if not _normal_capacity_ledger.try_register(occupant, capacity_limit):
		_pause_normal_generation_timer()
		return false
	if occupant is Node:
		var occupant_node: Node = occupant as Node
		occupant_node.tree_exited.connect(_on_normal_capacity_occupant_tree_exited.bind(occupant), CONNECT_ONE_SHOT)
	if not _normal_capacity_ledger.has_capacity(capacity_limit):
		_pause_normal_generation_timer()
	return true

## 节点实例离开场景树时自动归还共享容量。
func _on_normal_capacity_occupant_tree_exited(occupant: Object) -> void:
	release_normal_capacity_occupant(occupant)

## 容量达到上限时保留生成开启状态，只暂停批次 Timer。
func _pause_normal_generation_timer() -> void:
	if _normal_generation_enabled:
		_spawn_timer.stop()

## 关闭普通生成；已在场弹幕继续按自己的运行参数移动。
func stop_normal_generation() -> void:
	_normal_generation_enabled = false
	_spawn_timer.stop()

## 由其他系统明确调用，生成一条选中的普通话语。
func spawn_normal_barrage(level_profile: LevelProfile, speech: LevelSpeech) -> BarrageView:
	if level_profile == null or speech == null:
		push_error("BarrageArea: 生成普通弹幕需要关卡配置和话语定义。")
		return null
	if barrage_view_scene == null:
		push_error("BarrageArea: 未配置弹幕表现 Scene。")
		return null

	if not _normal_capacity_ledger.has_capacity(level_profile.normal_barrage_screen_cap):
		_pause_normal_generation_timer()
		return null

	var barrage_record: BarrageRuntimeRecord = BarrageRuntimeRecord.new()
	barrage_record.text = speech.text
	barrage_record.source_id = level_profile.streamer_id
	barrage_record.tendency_id = speech.tendency_id
	barrage_record.strength = 1.0
	barrage_record.original_sentence_id = speech.original_sentence_id
	barrage_record.capture_lifetime_at_spawn(Time.get_ticks_msec(), base_lifetime_seconds, _lifetime_multiplier)

	var view: BarrageView = barrage_view_scene.instantiate() as BarrageView
	if view == null:
		push_error("BarrageArea: 弹幕表现 Scene 根节点需要 BarrageView。")
		return null
	var effective_move_speed: float = level_profile.base_move_speed_pixels_per_second * _movement_speed_multiplier
	view.setup(barrage_record, effective_move_speed, self)
	if not _try_register_normal_capacity_occupant(view, level_profile.normal_barrage_screen_cap):
		view.free()
		return null
	add_child(view)
	var start_x: float = size.x - view.size.x
	if start_x < 0.0:
		start_x = 0.0
	view.position = Vector2(start_x, maxf((size.y - view.size.y) * 0.5, 0.0))
	return view

## 把 RepeatPlan 的单条请求显示为场上复读；容量满时返回 null 供 Repeat 处理溢出。
func spawn_repeat_barrage(plan: RepeatPlan) -> BarrageView:
	if plan == null or _current_level_profile == null:
		return null
	if barrage_view_scene == null:
		push_error("BarrageArea: 未配置弹幕表现 Scene。")
		return null
	var original_line_id: String = str(plan.original_line_id)
	if original_line_id.is_empty() or plan.lifetime_seconds <= 0.0:
		push_error("BarrageArea: 复读请求需要稳定原句 ID 和正寿命。")
		return null
	if not _repeat_capacity_ledger.has_capacity(repeat_barrage_screen_cap):
		return null

	var repeat_record: BarrageRuntimeRecord = BarrageRuntimeRecord.new()
	repeat_record.text = plan.display_text if not plan.display_text.is_empty() else plan.original_line_text
	repeat_record.source_id = _current_level_profile.streamer_id
	repeat_record.original_sentence_id = original_line_id
	repeat_record.strength = 1.0
	repeat_record.capture_lifetime_at_spawn(Time.get_ticks_msec(), plan.lifetime_seconds, 1.0)

	var view: BarrageView = barrage_view_scene.instantiate() as BarrageView
	if view == null:
		push_error("BarrageArea: 弹幕表现 Scene 根节点需要 BarrageView。")
		return null
	var effective_move_speed: float = _current_level_profile.base_move_speed_pixels_per_second * _movement_speed_multiplier
	view.setup(repeat_record, effective_move_speed, self)
	if not _try_register_repeat_capacity_occupant(view):
		view.free()
		return null
	add_child(view)
	var start_x: float = size.x - view.size.x
	if start_x < 0.0:
		start_x = 0.0
	view.position = Vector2(start_x, maxf((size.y - view.size.y) * 0.5, 0.0))
	return view

## 复读屏幕容量独立登记，视图离树时自动释放。
func _try_register_repeat_capacity_occupant(occupant: Object) -> bool:
	if occupant == null:
		return false
	if _repeat_capacity_ledger.has_occupant(occupant):
		return true
	if not _repeat_capacity_ledger.try_register(occupant, repeat_barrage_screen_cap):
		return false
	if occupant is Node:
		var occupant_node: Node = occupant as Node
		occupant_node.tree_exited.connect(_on_repeat_capacity_occupant_tree_exited.bind(occupant), CONNECT_ONE_SHOT)
	return true

## 复读视图离树时归还独立屏幕容量。
func _on_repeat_capacity_occupant_tree_exited(occupant: Object) -> void:
	_repeat_capacity_ledger.release(occupant)

## 按四舍五入后的批次数量倍率生成当前批次。
func _spawn_normal_batch() -> void:
	if not _normal_generation_enabled or _current_level_profile == null or _frequency_multiplier <= 0.0:
		return
	if not _has_normal_capacity_for(_current_level_profile):
		_pause_normal_generation_timer()
		return
	var batch_count: int = roundi(float(_current_level_profile.base_batch_count) * _count_multiplier)
	if batch_count <= 0:
		return
	for _index in range(batch_count):
		var speech: LevelSpeech = _speech_selector.select_next_normal_speech(_current_level_profile)
		if speech == null:
			return
		var barrage_view: BarrageView = spawn_normal_barrage(_current_level_profile, speech)
		if barrage_view == null:
			return

## 按传入关卡的上限判断普通话语与陷阱的共享容量。
func _has_normal_capacity_for(level_profile: LevelProfile) -> bool:
	return level_profile != null and _normal_capacity_ledger.has_capacity(level_profile.normal_barrage_screen_cap)

## 根据当前频率倍率更新时间间隔；零频率时保留已开启状态并暂停 Timer。
func _restart_spawn_timer() -> void:
	if not is_inside_tree() or not _normal_generation_enabled or _current_level_profile == null or _frequency_multiplier <= 0.0 or not _has_normal_capacity_for(_current_level_profile):
		_spawn_timer.stop()
		return
	_spawn_timer.wait_time = _get_effective_spawn_interval()
	_spawn_timer.start()

func _get_effective_spawn_interval() -> float:
	return _current_level_profile.base_spawn_interval_seconds / _frequency_multiplier

## Timer 每到间隔触发一批，关闭状态下保持静默。
func _on_spawn_timer_timeout() -> void:
	if not _normal_generation_enabled or _current_level_profile == null or _frequency_multiplier <= 0.0:
		return
	if not _has_normal_capacity_for(_current_level_profile):
		_pause_normal_generation_timer()
		return
	_spawn_normal_batch()
