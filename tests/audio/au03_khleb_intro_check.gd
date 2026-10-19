extends SceneTree

## 延长真实播放等待复现对白长于引子；不缩短曲目或用seek伪造循环。
var _audio: Node
var _music: Node
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		_failures += 1

func _wait_wrap(event_id: StringName, timeout: float) -> void:
	var previous: float = _audio.get_music_position()
	var remain: float = timeout
	while remain > 0.0:
		await create_timer(0.05).timeout
		remain -= 0.05
		var pos: float = _audio.get_music_position()
		if pos + 1.0 < previous:
			_check(_audio.get_music_event_id() == event_id and pos >= 7.40, "回绕只到伴奏段，不重播原曲开头")
			return
		previous = pos
	_check(false, "等待真实回绕超时")

func _run() -> void:
	create_timer(70.0).timeout.connect(func(): quit(2))
	_audio = root.get_node("AudioManager")
	_music = load("res://core/audio/tier_music_presenter.gd").new()
	_music.profile = BossMusicCatalog.find_profile(&"fox")
	root.add_child(_music)
	_music.start_battle()
	_music.begin_connection()
	_music.request_tier(1)
	await create_timer(0.2).timeout
	_check(_audio.get_music_event_id() == &"music_fox_entrance" and _audio.get_music_position() < 1.0, "首次从0秒播列巴开头")
	_check(absf(_audio.get_music_loop_offset() - 7.432290249433106) < 0.001, "原色出场配置伴奏循环点")
	await _wait_wrap(&"music_fox_entrance", 18.0)
	var pos: float = _audio.get_music_position()
	_music.begin_connection_dialogue()
	await create_timer(0.2).timeout
	_check(_audio.get_music_event_id() == &"music_fox_intro" and _audio.get_music_position() >= pos, "长出场后开口对白仍保持进度")
	_check(_audio.get_music_loop_offset() > 7.4, "对白混音配置同一伴奏循环点")
	_music.set_paused(true)
	await create_timer(0.1).timeout
	pos = _audio.get_music_position()
	await create_timer(0.3).timeout
	_check(absf(_audio.get_music_position() - pos) < 0.05, "伴奏等待期暂停不走时钟")
	_music.set_paused(false)
	await _wait_wrap(&"music_fox_intro", 9.0)
	await _wait_wrap(&"music_fox_intro", 9.0)
	_check(_music.is_opening_dialogue_active(), "对白未结束时保持伴奏，未提前进入战斗段")
	_music.finish_connection_dialogue()
	await create_timer(_music.profile.bar_seconds() + 0.8).timeout
	_check(_audio.get_music_event_id() == &"music_fox_intro", "对白结束仍保持开场伴奏，不切低段")
	_music.request_tier(2, true)
	await create_timer(0.2).timeout
	_check(_audio.get_music_event_id() == &"music_fox_intro", "第二次升档等待箭头淡出，不提前切段")
	_music.release_tier_visual(2)
	await create_timer(0.8).timeout
	_check(_audio.get_music_event_id() == &"music_fox_mid", "第二次箭头放行才切中段")
	_music.start_battle()
	_music.begin_connection()
	_music.request_tier(1)
	_music.finish_battle(&"failed")
	await create_timer(0.8).timeout
	_music.finish_connection_dialogue()
	await create_timer(0.3).timeout
	_check(_audio.get_music_event_id() == &"", "失败取消长对白等待，旧完成不能重播")
	_music.start_battle()
	_music.begin_connection()
	_music.set_paused(true)
	_music.start_battle()
	await create_timer(0.2).timeout
	_check(_audio.get_music_event_id() == &"", "暂停中重开回T0静音")
	_music.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("AU03_KHLEB_INTRO_PASS" if _failures == 0 else "AU03_KHLEB_INTRO_FAIL %d" % _failures)
	quit(0 if _failures == 0 else 1)
