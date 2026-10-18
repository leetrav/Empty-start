class_name TierMusicPresenter
extends Node

## 场景拥有的音乐消费者：不创建播放器，不计算PK，退出即取消待切换目标。
signal group_changed(group: int)

@export var profile: TierMusicProfile = preload("res://data/audio/fermi_tier_music.tres")
var _host: Node
var _active: bool = false
var _paused: bool = false
var _group: int = -1
var _target: int = -1
var _lower_elapsed: float = 0.0
var _boundary_remaining: float = -1.0
var _last_position: float = 0.0


# 由组合根注入当前玩法主控，防止按场景树层级寻找兄弟对象。
func bind_host(host: Node) -> void:
	if is_instance_valid(_host):
		_host.tier_changed.disconnect(request_tier)
		_host.battle_state_changed.disconnect(_on_battle_state_changed)
		_host.battle_ended.disconnect(_on_battle_ended)
	_host = host
	_host.tier_changed.connect(request_tier)
	_host.battle_state_changed.connect(_on_battle_state_changed)
	_host.battle_ended.connect(_on_battle_ended)
	if StringName(_host.get_battle_state()) in [&"running", &"paused"]:
		start_battle(int(_host.get_current_tier()))
		set_paused(StringName(_host.get_battle_state()) == &"paused")


func _ready() -> void:
	AudioManager.music_changed.connect(_on_music_changed)


# 新局从T0黑屏铺垫开始；中途绑定恢复当前真实Tier。
func start_battle(tier: int = 0) -> void:
	_active = true
	_paused = false
	_group = -1
	_target = profile.group_for_tier(tier)
	_lower_elapsed = 0.0
	_boundary_remaining = -1.0
	AudioManager.stop_music()
	_play_group(_target, 0.0, true)


# 同组信号不重播；向更低组连续计时，取消时只保留最新目标。
func request_tier(tier: int) -> void:
	if not _active:
		return
	var target: int = profile.group_for_tier(tier)
	if target == _target:
		return
	var was_lower: bool = _target < _group
	_target = target
	if target >= _group or not was_lower:
		_lower_elapsed = 0.0
	if target == _group:
		_boundary_remaining = -1.0
	elif target < _group and not was_lower:
		_boundary_remaining = -1.0


# 暂停同时冻结播放与稳定计时；用于局部暂停和整棵树暂停。
func set_paused(paused: bool) -> void:
	_paused = paused
	if owns_music():
		AudioManager.set_music_paused(paused)


func get_current_group() -> int:
	return _group


func get_target_group() -> int:
	return _target


func owns_music() -> bool:
	return _group >= 0 and AudioManager.get_music_event_id() == profile.event_ids[_group]


func _process(delta: float) -> void:
	if not _active or _paused or not owns_music():
		return
	var position: float = AudioManager.get_music_position()
	var audio_delta: float = position - _last_position
	if audio_delta < -0.1:
		audio_delta += AudioManager.get_music_length()
	audio_delta = maxf(audio_delta, 0.0)
	_last_position = position
	if _target == _group:
		return
	if _target < _group:
		_lower_elapsed += delta
		if _lower_elapsed < profile.downgrade_hold_seconds:
			return
	if _boundary_remaining < 0.0:
		# 以当前音频播放位置排下一小节；循环资源长度是整小节。
		_boundary_remaining = profile.bar_seconds() - fposmod(position, profile.bar_seconds())
		return
	_boundary_remaining -= audio_delta
	if _boundary_remaining <= 0.0:
		# 帧间越过边界时把小偏移带到新段，避免每次换曲累积一帧漂移。
		_play_group(_target, -_boundary_remaining)


func _play_group(group: int, from_position: float = 0.0, initial: bool = false) -> void:
	_group = group
	# 黑屏等待组用一小节淡入；连线后的战斗段保持原交叉淡化。
	var fade_in: float = profile.intro_fade_seconds if initial and group == 0 else -1.0
	if not AudioManager.change_music(profile.event_ids[group], profile.cross_fade_seconds, from_position, fade_in):
		_active = false
		_group = -1
		return
	_last_position = from_position
	_lower_elapsed = 0.0
	_boundary_remaining = -1.0
	group_changed.emit(group)


# 失败与普通离场淡出；满PK取消Tier等待，直接交给高段与原击破流程。
func finish_battle(result: StringName) -> void:
	if not _active:
		return
	_active = false
	_boundary_remaining = -1.0
	_lower_elapsed = 0.0
	set_paused(false)
	if not owns_music():
		return
	if result == &"enter_contradiction":
		var high_group: int = profile.group_for_tier(5)
		if _group != high_group:
			_target = high_group
			_play_group(high_group)
	else:
		AudioManager.fade_out_music()


# 后续正式矛盾流程可直接调用原AudioManager.fade_to_silence，无需另建播放器。
func _on_battle_ended(result: StringName) -> void:
	finish_battle(result)


func _on_battle_state_changed(state: StringName) -> void:
	match state:
		&"running":
			if _paused:
				set_paused(false)
			else:
				start_battle(int(_host.get_current_tier()))
		&"paused":
			set_paused(true)


# 其他场景接管音乐或击破静音时使旧场景失效，不再重播费米曲。
func _on_music_changed(event_id: StringName) -> void:
	if _group >= 0 and event_id != profile.event_ids[_group]:
		_active = false
		_boundary_remaining = -1.0


func _exit_tree() -> void:
	_active = false
	_boundary_remaining = -1.0
	if owns_music():
		AudioManager.stop_music()
