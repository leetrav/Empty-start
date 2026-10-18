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
	assert(audio.get_music_event_id() == &"")
	print("PASS 正式费米开局黑屏静音")
	scene.dialogue_event_sequence_completed.connect(_on_dialogue_completed)
	scene.debug_set_player_pk(0.58)
	await process_frame
	assert(audio.get_music_event_id() == &"music_alien_intro")
	# 调试PK不制造命中清场，借用现有公开流程完成连线视觉阶段。
	var flow: Node = scene.get_node("BattleAttemptFlow")
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
	assert(audio.get_music_event_id() == &"music_alien_low")
	print("PASS 费米T1连线后切入战斗低段")
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
	print("PASS 正式重开回黑屏静音")
	scene.debug_set_player_pk(0.0)
	await create_timer(0.8).timeout
	assert(audio.get_music_event_id() == &"")
	print("PASS 正式失败淡出")
	scene.restart_current_attempt()
	await create_timer(0.15).timeout
	scene.debug_set_player_pk(1.0)
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == &"music_alien_high")
	print("PASS 正式满PK沿用高段")
	scene.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == &"")
	print("AU03_FIRST_BOSS_PASS")
	quit(0)
