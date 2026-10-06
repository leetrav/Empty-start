## 负责普通战斗的批次计时、倍率应用与单条弹幕实例化。
class_name BarrageArea
extends Control

## 普通话语与复读均在视图进入场景树并完成定位后通知成功生成。
signal barrage_generated(view: BarrageView)

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
var _contradiction_generation_enabled: bool = false
var _contradiction_lines: Array[LevelContradiction] = []
var _next_contradiction_index: int = 0
var _count_multiplier: float = 1.0
var _frequency_multiplier: float = 1.0
var _movement_speed_multiplier: float = 1.0
var _lifetime_multiplier: float = 1.0
## 普通话语与陷阱共用的容量账本。
var _normal_capacity_ledger: BarrageCapacityLedger = BarrageCapacityLedger.new()
var _repeat_capacity_ledger: BarrageCapacityLedger = BarrageCapacityLedger.new()
var _next_spawn_row: int = 0

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

## 矛盾阶段复用当前档位的数量、频率、速度和寿命倍率；静态内容由关卡提供。
func start_contradiction_generation(
	level_profile: LevelProfile,
	true_lines: Array[LevelContradiction],
	false_lines: Array[LevelContradiction]
) -> bool:
	if level_profile == null or level_profile.base_spawn_interval_seconds <= 0.0:
		return false
	var lines: Array[LevelContradiction] = []
	for line: LevelContradiction in true_lines + false_lines:
		if line == null or line.original_sentence_id.is_empty() or line.text.is_empty():
			continue
		lines.append(line)
	if lines.is_empty():
		return false
	stop_normal_generation()
	stop_contradiction_generation()
	_current_level_profile = level_profile
	_contradiction_lines = lines
	_next_contradiction_index = 0
	_contradiction_generation_enabled = true
	if _frequency_multiplier > 0.0:
		_spawn_contradiction_batch()
	_restart_spawn_timer()
	return true


## 离开矛盾阶段时停止后续批次；已生成实例由场景协调方决定何时清理。
func stop_contradiction_generation() -> void:
	_contradiction_generation_enabled = false
	_contradiction_lines.clear()
	_spawn_timer.stop()

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
	# 只有满容量曾暂停计时时才恢复；正在运行的周期保留剩余时间，命中不会推迟下一批。
	if _spawn_timer.is_stopped():
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
	if _normal_generation_enabled or _contradiction_generation_enabled:
		_spawn_timer.stop()

## 关闭普通生成；已在场弹幕继续按自己的运行参数移动。
func stop_normal_generation() -> void:
	_normal_generation_enabled = false
	if not _contradiction_generation_enabled:
		_spawn_timer.stop()

## 结算协调方按实例 ID 结束本区域目标；立即离树归还容量，重复请求保持无副作用。
func end_barrage(target_instance_id: int) -> bool:
	var target: Object = instance_from_id(target_instance_id)
	if not is_instance_valid(target) or not target is BarrageView:
		return false
	var barrage_view: BarrageView = target as BarrageView
	if barrage_view.get_parent() != self or barrage_view.is_queued_for_deletion():
		return false
	remove_child(barrage_view)
	barrage_view.queue_free()
	return true

## 重开或阶段结束时停止普通生成并清理当前视图，避免旧实例占用新一局容量。
func clear_barrages() -> void:
	stop_normal_generation()
	stop_contradiction_generation()
	for child in get_children():
		if child is BarrageView:
			# 自然到期可能已排队释放，仍须立即离树，确保同帧重开归还全部容量。
			if child.is_queued_for_deletion():
				remove_child(child)
			else:
				end_barrage(child.get_instance_id())
	_next_spawn_row = 0

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
	barrage_record.original_sentence_text = speech.text
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
	if not _place_new_barrage(view):
		# 场上没有可见空位时归还刚申请的容量，普通 Timer 后续继续尝试。
		end_barrage(view.get_instance_id())
		return null
	barrage_generated.emit(view)
	return view


## 单条矛盾使用与普通弹幕相同的容量、定位和当前档位参数，不附加普通陷阱特性。
func spawn_contradiction_barrage(level_profile: LevelProfile, line: LevelContradiction) -> BarrageView:
	if level_profile == null or line == null or barrage_view_scene == null:
		return null
	if not _normal_capacity_ledger.has_capacity(level_profile.normal_barrage_screen_cap):
		_pause_normal_generation_timer()
		return null
	var barrage_record := BarrageRuntimeRecord.new()
	barrage_record.text = line.text
	barrage_record.original_sentence_text = line.text
	barrage_record.original_sentence_id = line.original_sentence_id
	barrage_record.source_id = level_profile.streamer_id
	barrage_record.is_contradiction = true
	barrage_record.capture_lifetime_at_spawn(Time.get_ticks_msec(), base_lifetime_seconds, _lifetime_multiplier)
	var view := barrage_view_scene.instantiate() as BarrageView
	if view == null:
		return null
	view.setup(barrage_record, level_profile.base_move_speed_pixels_per_second * _movement_speed_multiplier, self)
	if not _try_register_normal_capacity_occupant(view, level_profile.normal_barrage_screen_cap):
		view.free()
		return null
	add_child(view)
	if not _place_new_barrage(view):
		end_barrage(view.get_instance_id())
		return null
	barrage_generated.emit(view)
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
	repeat_record.original_sentence_text = plan.original_line_text
	repeat_record.is_repeat = true
	repeat_record.is_contradiction_repeat = plan.repeat_type == RepeatPlan.RepeatType.CONTRADICTION
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
	if not _place_new_barrage(view):
		# 到期请求继续留在 Repeat 队列，成功定位前不发送实际生成事实。
		end_barrage(view.get_instance_id())
		return null
	barrage_generated.emit(view)
	return view


## 成功击破后的过渡等待实际可见矛盾复读离场，不把排队项当作已展示。
func has_visible_contradiction_repeats() -> bool:
	for child in get_children():
		if child is BarrageView and not child.is_queued_for_deletion():
			var view := child as BarrageView
			if view.runtime_record != null and view.runtime_record.is_contradiction_repeat:
				return true
	return false

## 从轮换行寻找当前真实空位；上一轮横移目标仍占着入口时跳到其他行。
func _place_new_barrage(view: BarrageView) -> bool:
	var start_x: float = maxf(size.x - view.size.x, 0.0)
	var top_margin: float = minf(48.0, maxf(size.y - view.size.y, 0.0))
	var row_step: float = view.size.y + 16.0
	var available_height: float = maxf(size.y - view.size.y - top_margin - 16.0, 0.0)
	var row_count: int = maxi(floori(available_height / row_step) + 1, 1)
	for row_offset: int in range(row_count):
		var row_index: int = (_next_spawn_row + row_offset) % row_count
		var candidate_position: Vector2 = Vector2(start_x, top_margin + float(row_index) * row_step)
		var candidate_rect: Rect2 = Rect2(candidate_position, view.size).grow(8.0)
		var overlaps_existing: bool = false
		for child in get_children():
			if child == view or not child is BarrageView or child.is_queued_for_deletion():
				continue
			var existing_view: BarrageView = child as BarrageView
			var existing_rect: Rect2 = Rect2(existing_view.position, existing_view.size).grow(8.0)
			if candidate_rect.intersects(existing_rect):
				overlaps_existing = true
				break
		if overlaps_existing:
			continue
		view.position = candidate_position
		_next_spawn_row = (row_index + 1) % row_count
		return true
	return false

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


## 每批轮换当前关真假矛盾；同一稳定 ID 可再次出现，但真假归属只由关卡定义。
func _spawn_contradiction_batch() -> void:
	if not _contradiction_generation_enabled or _current_level_profile == null or _contradiction_lines.is_empty():
		return
	if not _has_normal_capacity_for(_current_level_profile):
		_pause_normal_generation_timer()
		return
	var batch_count: int = roundi(float(_current_level_profile.base_batch_count) * _count_multiplier)
	for _index in range(maxi(batch_count, 0)):
		var line: LevelContradiction = _contradiction_lines[_next_contradiction_index]
		if spawn_contradiction_barrage(_current_level_profile, line) == null:
			return
		_next_contradiction_index = (_next_contradiction_index + 1) % _contradiction_lines.size()

## 按传入关卡的上限判断普通话语与陷阱的共享容量。
func _has_normal_capacity_for(level_profile: LevelProfile) -> bool:
	return level_profile != null and _normal_capacity_ledger.has_capacity(level_profile.normal_barrage_screen_cap)

## 根据当前频率倍率更新时间间隔；零频率时保留已开启状态并暂停 Timer。
func _restart_spawn_timer() -> void:
	if not is_inside_tree() or (not _normal_generation_enabled and not _contradiction_generation_enabled) or _current_level_profile == null or _frequency_multiplier <= 0.0 or not _has_normal_capacity_for(_current_level_profile):
		_spawn_timer.stop()
		return
	_spawn_timer.wait_time = _get_effective_spawn_interval()
	_spawn_timer.start()

func _get_effective_spawn_interval() -> float:
	return _current_level_profile.base_spawn_interval_seconds / _frequency_multiplier

## Timer 每到间隔触发一批，关闭状态下保持静默。
func _on_spawn_timer_timeout() -> void:
	if (not _normal_generation_enabled and not _contradiction_generation_enabled) or _current_level_profile == null or _frequency_multiplier <= 0.0:
		return
	if not _has_normal_capacity_for(_current_level_profile):
		_pause_normal_generation_timer()
		return
	if _contradiction_generation_enabled:
		_spawn_contradiction_batch()
	else:
		_spawn_normal_batch()
