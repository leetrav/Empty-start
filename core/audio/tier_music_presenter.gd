class_name TierMusicPresenter
extends Node

## 场景拥有的音乐消费者：不创建播放器，不计算PK，退出即取消待切换目标。
signal group_changed(group: int)

@export var profile: TierMusicProfile = preload("res://data/audio/fermi_tier_music.tres")
var _host: Node
var _active: bool = false
var _paused: bool = false
var _opening_active: bool = false
var _waiting_for_tier_visual: bool = false
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


# 新局按Profile选择T0引子或静音；中途恢复非T0时从实际战斗组开始。
func start_battle(tier: int = 0) -> void:
	_active = true
	_paused = false
	_opening_active = false
	_waiting_for_tier_visual = false
	_group = -1
	_target = profile.group_for_tier(tier)
	_lower_elapsed = 0.0
	_boundary_remaining = -1.0
	AudioManager.stop_music()
	if tier > 0:
		_play_group(_target, 0.0, true)
	elif profile.intro_before_connection:
		_opening_active = true
		_play_group(0, 0.0, true)


# 同组信号不重播；向更低组连续计时，取消时只保留最新目标。
func request_tier(tier: int, wait_for_visual: bool = false) -> void:
	if not _active:
		return
	var target: int = profile.group_for_tier(tier)
	if tier == 0:
		if profile.intro_before_connection:
			_target = 0
			_opening_active = true
			_waiting_for_tier_visual = false
			if _group != 0 or not owns_music():
				_play_group(0, 0.0, true)
			return
		# 对手离线/等待时撤销引子和所有延迟切曲，保留普通操作音效。
		var owned: bool = owns_music()
		_group = -1
		_target = target
		_opening_active = false
		_waiting_for_tier_visual = false
		_lower_elapsed = 0.0
		_boundary_remaining = -1.0
		if owned:
			AudioManager.stop_music()
		return
	if _opening_active:
		# 对白结束前只更新后续战斗目标，不让Tier覆盖柔和引子。
		_target = target
		_waiting_for_tier_visual = wait_for_visual
		return
	_waiting_for_tier_visual = wait_for_visual and target > _group
	if _group < 0:
		_target = target
		_play_group(target, 0.0, true)
		return
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


# 连线演出开始时调用，先播柔和引子；开场对白完成前持续保持。
func begin_connection() -> void:
	if not _active or _opening_active:
		return
	_opening_active = true
	_play_group(0, 0.0, true)


# 真实对白气泡呈现时，从原色出场版切到同一进度的柔和版，不猜秒数。
func begin_connection_dialogue() -> void:
	if not _active or not _opening_active or profile.entrance_event_id == &"":
		return
	if AudioManager.get_music_event_id() != profile.entrance_event_id:
		return
	var position: float = AudioManager.get_music_position()
	AudioManager.change_music(profile.event_ids[0], profile.dialogue_mix_seconds, position)
	AudioManager.set_music_paused(_paused)
	_last_position = position


# 仅由本次真实开场对白完成事实放行，空对白也走同一完成路径。
func finish_connection_dialogue() -> void:
	if not _active or not _opening_active:
		return
	_opening_active = false
	if _target == 0:
		_target = profile.group_for_tier(1)
	if profile.intro_before_connection:
		# 费米仅由真实箭头放行，不能拿对白完成替代升档视觉。
		_opening_active = true
	_boundary_remaining = -1.0
	_last_position = AudioManager.get_music_position()


func is_waiting_for_connection() -> bool:
	return _active and _group < 0


func is_opening_dialogue_active() -> bool:
	return _opening_active


# 当前真实升档箭头开始淡出后才启动音乐淡变，不再额外等待小节。
func release_tier_visual(tier: int) -> void:
	if not _active or not profile.intro_before_connection or tier <= 0:
		return
	if profile.group_for_tier(tier) != _target:
		return
	_opening_active = false
	_waiting_for_tier_visual = false
	if _group != _target:
		_play_group(_target)


# F3无命中清场和箭头链路，显式直接试听当前档，避免卡在待放行状态。
func skip_connection_for_debug(tier: int) -> void:
	if not _active or not profile.intro_before_connection or tier <= 0:
		return
	_opening_active = false
	_waiting_for_tier_visual = false
	_target = profile.group_for_tier(tier)
	if _group != _target:
		_play_group(_target, 0.0, true)


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
	if _group < 0:
		return false
	var event_id: StringName = AudioManager.get_music_event_id()
	return event_id == profile.event_ids[_group] or (_group == 0 and profile.entrance_event_id != &"" and event_id == profile.entrance_event_id)


func _process(delta: float) -> void:
	if not _active or _paused or not owns_music():
		return
	var position: float = AudioManager.get_music_position()
	var audio_delta: float = position - _last_position
	if audio_delta < -0.1:
		audio_delta += AudioManager.get_music_length() - AudioManager.get_music_loop_offset()
	audio_delta = maxf(audio_delta, 0.0)
	_last_position = position
	if _opening_active or _waiting_for_tier_visual or _target == _group:
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
	var leaving_intro: bool = _group == 0 and group > 0
	_group = group
	# 柔和引子单独淡入；战斗段由对应对白/箭头事实放行。
	var fade_in: float = profile.intro_fade_seconds if initial and group == 0 else -1.0
	var event_id: StringName = profile.event_ids[group]
	if initial and group == 0 and profile.entrance_event_id != &"":
		event_id = profile.entrance_event_id
		fade_in = profile.entrance_fade_seconds
	if not AudioManager.change_music(event_id, profile.cross_fade_seconds, from_position, fade_in, profile.overlap_battle and not leaving_intro):
		_active = false
		_group = -1
		return
	AudioManager.set_music_paused(_paused)
	_last_position = from_position
	_lower_elapsed = 0.0
	_boundary_remaining = -1.0
	group_changed.emit(group)


# 失败与普通离场淡出；满PK取消Tier等待，直接交给高段与原击破流程。
func finish_battle(result: StringName) -> void:
	if not _active:
		return
	_active = false
	_opening_active = false
	_boundary_remaining = -1.0
	_lower_elapsed = 0.0
	set_paused(false)
	if result == &"enter_contradiction":
		var high_group: int = profile.group_for_tier(5)
		if _group != high_group:
			_target = high_group
			_play_group(high_group)
	elif owns_music():
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
func _on_music_changed(_event_id: StringName) -> void:
	if _group >= 0 and not owns_music():
		_active = false
		_boundary_remaining = -1.0


func _exit_tree() -> void:
	_active = false
	_boundary_remaining = -1.0
	if owns_music():
		AudioManager.stop_music()
