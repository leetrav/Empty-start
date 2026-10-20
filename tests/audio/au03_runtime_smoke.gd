extends Node

## 真实AudioManager/播放器运行验收，覆盖延迟变更被撤销和生命周期清理。
var _failures: int = 0
var _music: TierMusicPresenter


func _ready() -> void:
	await get_tree().process_frame
	_music = TierMusicPresenter.new()
	add_child(_music)
	_music.start_battle()
	await _wait(0.15)
	_check(AudioManager.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT, "费米T0黑屏保持Pop Sky")
	_music.begin_connection()
	_music.request_tier(1, true)
	_music.release_tier_visual(1)
	await _wait(20.0)
	_check(AudioManager.get_music_event_id() == &"music_alien_intro" and AudioManager.get_music_position() > 4.8, "56%开屏起曲，循环跳过静音前缀")
	_music.finish_connection_dialogue()
	await _wait(0.4)
	_check(AudioManager.get_music_event_id() == &"music_alien_intro", "对白结束不切段")
	_music.request_tier(2, true)
	await _wait(0.4)
	_check(AudioManager.get_music_event_id() == &"music_alien_intro", "64%未收到箭头淡出仍保持引子")
	_music.release_tier_visual(2)
	var overlapped: bool = false
	var old_retained: bool = false
	var elapsed: float = 0.0
	while elapsed < 3.3:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var audible: int = 0
		for child: Node in AudioManager.get_children():
			if child is AudioStreamPlayer and child.bus == &"Music" and child.playing:
				if child.volume_linear > 0.001:
					audible += 1
				if elapsed > 3.1 and child.stream.resource_path.ends_with("teek_intro.ogg"):
					old_retained = true
		overlapped = overlapped or audible > 1
	_check(not overlapped and not old_retained, "第二次箭头放行引子接中段无旋律重叠且旧播放器停止")
	_check(AudioManager.get_music_event_id() == &"music_alien_mid", "64%第二次箭头淡出才切中段")
	var pos: float = AudioManager.get_music_position()
	_music.request_tier(1)
	await _wait(0.15)
	_check(AudioManager.get_music_position() > pos, "同组战斗音乐正常推进")
	_music.request_tier(4)
	_music.request_tier(2)
	await _wait(2.7)
	_check(_music.get_current_group() == 2, "同小节多次变更只保留最新目标")
	_music.request_tier(1)
	await _wait(0.4)
	_music.request_tier(3)
	await _wait(2.6)
	_check(_music.get_current_group() == 2, "短暂降档取消")
	_music.request_tier(5)
	await _wait(2.7)
	_check(_music.get_current_group() == 3, "跨组升档高段")
	_music.request_tier(2)
	await _wait(0.5)
	_music.set_paused(true)
	await _wait(0.12)
	pos = AudioManager.get_music_position()
	await _wait(2.2)
	_check(absf(AudioManager.get_music_position() - pos) < 0.05, "暂停音乐位置冻结")
	_check(_music.get_current_group() == 3, "暂停不消耗降档等待")
	_music.set_paused(false)
	await _wait(0.5)
	_check(_music.get_current_group() == 3, "恢复保留剩余等待")
	_music.request_tier(0)
	await _wait(4.3)
	_check(AudioManager.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT, "退回T0恢复Pop Sky")
	_music.request_tier(5)
	_music.finish_battle(&"failed")
	await _wait(2.9)
	_check(AudioManager.get_music_event_id() == &"", "失败取消等待并静音")
	_music.start_battle(4)
	await _wait(0.2)
	_check(_music.get_current_group() == 3, "中途恢复使用真实Tier")
	_music.set_paused(true)
	_music.start_battle()
	await _wait(0.2)
	_check(AudioManager.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT, "暂停中重开回T0Pop Sky")
	_music.finish_battle(&"enter_contradiction")
	await _wait(0.7)
	_check(AudioManager.get_music_event_id() == &"music_alien_high", "矛盾延续高段")
	AudioManager.fade_to_silence()
	await _wait(0.5)
	_check(AudioManager.get_music_event_id() == &"", "击破沿用静音接口")
	_music.start_battle()
	_music.request_tier(5)
	_music.queue_free()
	await _wait(2.7)
	_check(AudioManager.get_music_event_id() == &"", "退出无遗留请求")
	# 在真实费米组合场景验证主控生命周期信号，未修改PK或感染逻辑。
	var scene: Node = load("res://scenes/plan_b/fermi_battle_demo.tscn").instantiate()
	add_child(scene)
	var host: Node = scene.get_node("BattleHost")
	host.start_battle(Vector2(900, 490))
	await _wait(0.15)
	_check(AudioManager.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT, "真实费米主控开局Pop Sky")
	host.pause_battle()
	await _wait(0.15)
	pos = AudioManager.get_music_position()
	await _wait(0.2)
	_check(absf(AudioManager.get_music_position() - pos) < 0.05, "真实主控暂停接线")
	host.restart_battle(Vector2(900, 490))
	await _wait(0.15)
	host.end_battle(&"enter_contradiction")
	await _wait(0.15)
	_check(AudioManager.get_music_event_id() == &"music_alien_high", "真实主控矛盾接线")
	scene.queue_free()
	await _wait(0.15)
	_check(AudioManager.get_music_event_id() == &"", "真实场景释放停止音乐")
	var bus: int = AudioServer.get_bus_index(&"Music")
	var original_db: float = AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, -12.0)
	AudioServer.set_bus_mute(bus, true)
	AudioManager.change_music(&"music_alien_mid", 0.6)
	AudioManager.duck_music()
	await _wait(0.25)
	AudioManager.restore_music()
	await _wait(0.35)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -12.0) and AudioServer.is_bus_mute(bus), "切曲和压低保留玩家音量静音")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, original_db)
	AudioManager.stop_music()
	await _wait(0.2)
	print("AU03_RUNTIME_PASS" if _failures == 0 else "AU03_RUNTIME_FAIL %d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(passed: bool, message: String) -> void:
	print("PASS " + message if passed else "FAIL " + message)
	if not passed:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
