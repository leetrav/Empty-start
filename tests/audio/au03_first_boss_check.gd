extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

var _connected_complete: bool = false

# 完成事件来自真实气泡对白队列，不用定时器伪造对白结束。
func _on_dialogue_completed(event_id: StringName, _sequence: StringName, _side: int) -> void:
	if event_id == &"combat_connected":
		_connected_complete = true

func _run() -> void:
	var scene: Node = load("res://scenes/sandbox/sandbox.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var audio: Node = root.get_node("AudioManager")
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT)
	print("PASS 正式费米开局Pop Sky")
	scene.dialogue_event_sequence_completed.connect(_on_dialogue_completed)
	var flow: Node = scene.get_node("BattleAttemptFlow")
	# 直接驱动PK事实测试正式连线路径，F3调档绕过对白的场景另验。
	flow.get_hit_resolution().set_player_pk_for_debug(0.58)
	await process_frame
	assert(audio.get_music_event_id() == &"music_alien_intro")
	# 调试PK不制造命中清场，借用现有公开流程完成连线视觉阶段。
	assert(flow.begin_tier_breakthrough_transition(0, 1))
	scene.get_node("BattleHud").tier_breakthrough_finished.emit(0, 1, true)
	await create_timer(3.0).timeout
	assert(not _connected_complete and audio.get_music_event_id() == &"music_alien_intro")
	print("PASS 正式开场对白期间保持柔和引子")
	var remaining: float = 45.0
	while not _connected_complete and remaining > 0.0:
		await create_timer(0.2).timeout
		remaining -= 0.2
	assert(_connected_complete, "真实连线对白应完成")
	await create_timer(2.8).timeout
	assert(audio.get_music_event_id() == &"music_alien_intro")
	print("PASS 费米T1保持开场到下一次升档")
	scene.debug_set_player_pk(0.66)
	await create_timer(2.8).timeout
	assert(audio.get_music_event_id() == &"music_alien_mid")
	print("PASS 正式PK到T2切中段")
	var pause: Node = scene.get_node("PauseMenu")
	pause.pause_game()
	await create_timer(0.15).timeout
	var pos: float = audio.get_music_position()
	await create_timer(0.3).timeout
	assert(absf(audio.get_music_position() - pos) < 0.05)
	pause.resume_game()
	await create_timer(0.2).timeout
	assert(audio.get_music_position() > pos)
	print("PASS 正式暂停续播")
	scene.debug_set_player_pk(0.92)
	await create_timer(2.8).timeout
	assert(audio.get_music_event_id() == &"music_alien_high")
	print("PASS 正式PK到T5切高段")
	scene.restart_current_attempt()
	await create_timer(0.15).timeout
	assert(audio.get_music_event_id() == &"")
	print("PASS 正式重开回静音")
	scene.debug_set_player_pk(0.0)
	await create_timer(0.8).timeout
	assert(audio.get_music_event_id() == &"")
	print("PASS 正式失败淡出")
	scene.restart_current_attempt()
	await create_timer(0.15).timeout
	# 与F3面板完全相同的入口：跨档后不应卡在等待对白的引子。
	scene.debug_set_player_pk(0.58)
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == &"music_alien_low")
	scene.debug_set_player_pk(0.92)
	await create_timer(2.8).timeout
	assert(audio.get_music_event_id() == &"music_alien_high")
	print("PASS F3跨档无对白时低段和高段正常跟随")
	var normal_gain: float = _audible_music_gain(audio)
	scene.debug_set_player_pk(1.0)
	await create_timer(0.3).timeout
	assert(_audible_music_gain(audio) <= normal_gain * 0.3)
	assert(_audible_music_gain(audio) > 0.01)
	print("PASS 击破转场压低BGM至25%且不静音")
	assert(audio.get_music_event_id() == &"music_alien_high")
	print("PASS 正式满PK沿用高段")
	var wait_remaining: float = 6.0
	while not scene.get_contradiction_oracle_flow().is_contradiction_active() and wait_remaining > 0.0:
		await create_timer(0.1).timeout
		wait_remaining -= 0.1
	assert(scene.get_contradiction_oracle_flow().is_contradiction_active())
	await create_timer(0.4).timeout
	assert(_audible_music_gain(audio) >= normal_gain * 0.95)
	print("PASS 特效结束进入矛盾操作窗口恢复BGM")
	scene.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == &"")
	print("AU03_FIRST_BOSS_PASS")
	quit(0)

# 观察实际输出增益，不改玩家Music总线或访问管理器私有字段。
func _audible_music_gain(audio: Node) -> float:
	var gain: float = 0.0
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer and child.bus == &"Music" and child.playing:
			gain += child.volume_linear
	return gain
