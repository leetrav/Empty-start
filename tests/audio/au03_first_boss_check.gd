extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/sandbox/sandbox.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var audio: Node = root.get_node("AudioManager")
	await create_timer(0.2).timeout
	assert(audio.get_music_event_id() == &"music_alien_low")
	print("PASS 正式费米开局低段")
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
	assert(audio.get_music_event_id() == &"music_alien_low")
	print("PASS 正式重开回低段")
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
