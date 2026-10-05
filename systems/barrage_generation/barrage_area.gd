## 负责普通战斗的批次计时、倍率应用与单条弹幕实例化。
class_name BarrageArea
extends Control

@export var barrage_view_scene: PackedScene
@onready var _spawn_timer: Timer = $SpawnTimer

var _speech_selector: NormalSpeechSelector = NormalSpeechSelector.new()
var _current_level_profile: LevelProfile
var _normal_generation_enabled: bool = false
var _count_multiplier: float = 1.0
var _frequency_multiplier: float = 1.0
var _movement_speed_multiplier: float = 1.0

## 连接本组件的批次 Timer 超时信号。
func _ready() -> void:
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

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

	var record: BarrageRuntimeRecord = BarrageRuntimeRecord.new()
	record.text = speech.text
	record.source_id = level_profile.streamer_id
	record.tendency_id = speech.tendency_id
	record.strength = 1.0
	record.original_sentence_id = speech.original_sentence_id

	var view: BarrageView = barrage_view_scene.instantiate() as BarrageView
	if view == null:
		push_error("BarrageArea: 弹幕表现 Scene 根节点需要 BarrageView。")
		return null
	var effective_move_speed: float = level_profile.base_move_speed_pixels_per_second * _movement_speed_multiplier
	view.setup(record, effective_move_speed)
	add_child(view)
	var start_x: float = size.x - view.size.x
	if start_x < 0.0:
		start_x = 0.0
	view.position = Vector2(start_x, maxf((size.y - view.size.y) * 0.5, 0.0))
	return view

## 按四舍五入后的批次数量倍率生成当前批次。
func _spawn_normal_batch() -> void:
	if not _normal_generation_enabled or _current_level_profile == null or _frequency_multiplier <= 0.0:
		return
	var batch_count: int = roundi(float(_current_level_profile.base_batch_count) * _count_multiplier)
	if batch_count <= 0:
		return
	for _index in range(batch_count):
		var speech: LevelSpeech = _speech_selector.select_next_normal_speech(_current_level_profile)
		if speech == null:
			return
		spawn_normal_barrage(_current_level_profile, speech)

## 根据当前频率倍率更新时间间隔；零频率时保留已开启状态并暂停 Timer。
func _restart_spawn_timer() -> void:
	if not _normal_generation_enabled or _current_level_profile == null or _frequency_multiplier <= 0.0:
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
	_spawn_normal_batch()
