extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var router := root.get_node("SceneRouter")
	var audio := root.get_node("AudioManager")
	var settings := root.get_node("SettingsManager")
	# 用真实菜单按钮验证三个入口；回看不改变首次观看事实。
	settings.opening_comic_seen = false
	for button_name in ["ReplayFullOpeningButton", "ReplayOpeningButton", "ReplayEndingButton"]:
		assert(router.goto_main_menu() == OK)
		await process_frame
		await process_frame
		var button := current_scene.find_child(button_name, true, false) as Button
		assert(button != null and button.visible)
		button.pressed.emit()
		await process_frame
		await process_frame
		var comic := current_scene
		assert(audio.get_music_event_id() == &"music_comic_street")
		var expected_count: int = 19 if button_name == "ReplayFullOpeningButton" else (6 if button_name == "ReplayEndingButton" else 13)
		assert(comic.get_playback_control().panel_count == expected_count)
		assert(audio.get_music_position() > 40.0 if button_name == "ReplayEndingButton" else audio.get_music_position() < 2.0)
		await create_timer(0.2).timeout
		comic.set_playback_paused(true)
		var before: float = audio.get_music_position()
		await create_timer(0.2).timeout
		assert(absf(audio.get_music_position() - before) < 0.1)
		comic.set_playback_paused(false)
		await create_timer(0.2).timeout
		assert(audio.get_music_position() > before)
		# 公开快进接口完成演出，检查返回菜单与淡出。
		for index in range(expected_count * 2):
			if not is_instance_valid(comic) or comic.is_queued_for_deletion() or not comic.is_inside_tree():
				break
			comic.advance()
		await process_frame
		await create_timer(0.4).timeout
		assert(current_scene.scene_file_path.ends_with("main_menu.tscn"))
		assert(audio.get_music_event_id() == &"")
		assert(not settings.opening_comic_seen)
		print("OPENING_REPLAY_ROUTE_PASS ", button_name)
	# 真首次启动会播放完整开场；跳过后记录已观看，第二次启动进菜单。
	assert(router.get_tree().change_scene_to_file("res://core/boot/boot.tscn") == OK)
	await process_frame
	await process_frame
	await process_frame
	assert(router.comic_kind == &"intro")
	assert(current_scene.scene_file_path.ends_with("comic_player.tscn"))
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	current_scene._input(esc)
	await process_frame
	await create_timer(0.4).timeout
	assert(settings.opening_comic_seen)
	assert(change_scene_to_file("res://core/boot/boot.tscn") == OK)
	await process_frame
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path.ends_with("main_menu.tscn"))
	print("OPENING_STREET_INTEGRATION_PASS")
	quit(0)
