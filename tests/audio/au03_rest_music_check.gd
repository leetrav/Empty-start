extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


# 只在隔离APPDATA运行；身份与结果作为UI输入，不制造真实获奖或完成记录。
func _run() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	var save := root.get_node("SaveManager")
	var audio := root.get_node("AudioManager")
	var router := root.get_node("SceneRouter")
	save.new_game()
	# 从真实姓名/身份页面进入截图中的房间，不跳过此前漏接的开局步骤。
	assert(router.goto_identity_setup() == OK)
	await process_frame
	await process_frame
	var setup := current_scene
	assert(audio.get_music_event_id() == &"")
	setup.get_node("StreamerPage/Center/Panel/Content/NameInput").text = "音乐测试"
	setup.get_node("StreamerPage/Center/Panel/Content/Continue").pressed.emit()
	setup.complete_player_presentation()
	setup.get_node("IdentitySelection").next_requested.emit(IdentityOptions.CARDS[0])
	await create_timer(0.3).timeout
	assert(setup.get_node("RoomComputerTransitionPage").visible)
	assert(audio.get_music_event_id() == &"music_rest_room")
	assert(audio.get_music_position() >= 2.35)
	# 回退身份页会淡出；再次回房间、命名及保存进入开播房间均正常接管。
	setup.get_node("RoomComputerTransitionPage/Center/Panel/Content/Back").pressed.emit()
	await create_timer(1.7).timeout
	assert(audio.get_music_event_id() == &"")
	setup.get_node("IdentitySelection").next_requested.emit(IdentityOptions.CARDS[0])
	await create_timer(0.3).timeout
	var setup_position: float = audio.get_music_position()
	setup.complete_room_computer_transition()
	await create_timer(0.2).timeout
	assert(audio.get_music_position() > setup_position)
	setup.get_node("FanGroupPage/Center/Panel/Content/Back").pressed.emit()
	setup.complete_room_computer_transition()
	setup.get_node("FanGroupPage/Center/Panel/Content/NameInput").text = "测试团"
	setup_position = audio.get_music_position()
	setup.get_node("FanGroupPage/Center/Panel/Content/Continue").pressed.emit()
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	assert(current_scene.scene_file_path.ends_with("rest_opening_room.tscn"))
	assert(audio.get_music_position() > setup_position)
	print("PASS 身份后回到房间起曲/回退淡出/命名不重播/保存后同曲交接")
	var room := current_scene
	assert(audio.get_music_event_id() == &"music_rest_room")
	assert(audio.get_music_position() >= 2.35)
	await create_timer(0.4).timeout
	var pause := room.get_node("PauseMenu")
	pause.pause_game()
	await create_timer(0.1).timeout
	var position: float = audio.get_music_position()
	await create_timer(0.3).timeout
	assert(absf(audio.get_music_position() - position) < 0.05)
	pause.resume_game()
	await create_timer(0.2).timeout
	assert(audio.get_music_position() > position)
	assert(room.start_live() == OK)
	await process_frame
	await process_frame
	var game := current_scene
	assert(game.scene_file_path.ends_with("sandbox.tscn"))
	await create_timer(2.0).timeout
	assert(audio.get_music_event_id() == &"")
	print("PASS 实际房间起曲/暂停/继续/开播后T0淡出")
	var view: Node = game.get_rest_result_view()
	var catalog: Resource = load("res://data/level_configuration/level_catalog.tres")
	var cards: Resource = load("res://data/loser_card/loser_card_catalog.tres")
	for kind in ["pk_win_unbroken", "breakthrough_oracle_complete"]:
		var session := RestSession.new()
		assert(session.open_result({"level_id": catalog.profiles[0].level_id, "result_kind": kind}))
		assert(view.show_result(session, save.data, catalog, cards))
		await process_frame
		await process_frame
		assert(audio.get_music_event_id() == &"music_rest_after_pk")
		await create_timer(0.3).timeout
		position = audio.get_music_position()
		assert(view.show_result(session, save.data, catalog, cards))
		await create_timer(0.2).timeout
		assert(audio.get_music_position() > position)
		for entry in ["Scripture", "LoserCard"]:
			view.get_node("%" + entry + "HistoryButton").pressed.emit()
			await create_timer(0.2).timeout
			view.get_node("%" + entry + "HistoryView").back_requested.emit()
		assert(audio.get_music_position() > position and audio.get_music_event_id() == &"music_rest_after_pk")
		pause = game.get_node("PauseMenu")
		pause.pause_game()
		await create_timer(0.1).timeout
		position = audio.get_music_position()
		await create_timer(0.2).timeout
		assert(absf(audio.get_music_position() - position) < 0.05)
		pause.resume_game()
		view.hide_result()
		await create_timer(2.0).timeout
		assert(audio.get_music_event_id() == &"")
		print("PASS 休息结果/重复展示/历史往返/实际暂停/隐藏淡出 ", kind)
	# 原生循环真实回绕；只seek到末尾缩短验证等待，不声称已试听整首。
	var stream: AudioStreamOggVorbis = load("res://assets/audio/music/rest/pure_soul.ogg")
	assert(stream.loop and stream.get_length() > 10.0)
	assert(absf(stream.loop_offset - 2.35) < 0.001)
	assert(audio.change_music(&"music_rest_room", 0.0, stream.get_length() - 0.3, 0.0))
	await create_timer(0.8).timeout
	assert(audio.get_music_position() >= 2.35 and audio.get_music_position() < 3.85)
	var after_pk: AudioStreamOggVorbis = load("res://assets/audio/music/rest/yume_akari.ogg")
	assert(after_pk.loop and after_pk.loop_offset == 0.0)
	audio.stop_music()
	assert(audio.change_music(&"music_rest_after_pk", 0.0, after_pk.get_length() - 0.3, 0.0))
	await create_timer(0.8).timeout
	assert(audio.get_music_position() < 1.5)
	# 新曲接管后，旧结果关闭不能停止新曲。
	var session := RestSession.new()
	assert(session.open_result({"level_id": catalog.profiles[0].level_id, "result_kind": "pk_win_unbroken"}))
	assert(view.show_result(session, save.data, catalog, cards))
	audio.change_music(&"music_alien_mid", 0.0)
	view.hide_result()
	await create_timer(1.7).timeout
	assert(audio.get_music_event_id() == &"music_alien_mid")
	assert(save.data.completed_normal_level_ids.is_empty())
	assert(save.data.scripture_data.get_ordered_entries().is_empty())
	# 战后结果回到后续开播房间时续播；旧场景淡出不结束新房间同曲。
	save.data.next_normal_level_order = 2
	assert(view.show_result(session, save.data, catalog, cards))
	await create_timer(0.2).timeout
	position = audio.get_music_position()
	assert(router.goto_opening_room() == OK)
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	assert(audio.get_music_event_id() == &"music_rest_after_pk" and audio.get_music_position() > position)
	current_scene.get_node("PauseMenu").pause_game()
	assert(router.goto_main_menu() == OK)
	await process_frame
	await process_frame
	await create_timer(2.0).timeout
	assert(audio.get_music_event_id() == &"" and not paused)
	audio.stop_music()
	print("AU03_REST_MUSIC_PASS")
	quit(0)
