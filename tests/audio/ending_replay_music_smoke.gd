extends Node
var failures := 0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()
# 由外部隔离APPDATA；解锁仅用于可达的回放路由夹具，不声称自然通关。
func _run() -> void:
	get_tree().current_scene=null
	SettingsManager.mark_ending_replay_unlocked()
	_check(SceneRouter.goto_comic(&"opening")==OK,"opening route")
	await _settle()
	_check(AudioManager.get_music_event_id()==&"music_comic_street","opening uses Street")
	SceneRouter.goto_main_menu()
	await _settle()
	_check(AudioManager.get_music_event_id()==&"music_title_cafe","title uses Cafe")
	_check(SceneRouter.goto_comic(&"ending")==OK,"ending replay route")
	await _settle()
	_check(AudioManager.get_music_event_id()==EndingMusicPresenter.EVENT,"ending replay uses Tendoh")
	_check(AudioManager.get_music_position()<4.0,"ending replay starts from beginning")
	var comic = get_tree().current_scene
	comic.set_playback_paused(true)
	var position = AudioManager.get_music_position()
	await get_tree().create_timer(0.3).timeout
	_check(absf(AudioManager.get_music_position()-position)<0.08,"ending music pauses")
	comic.set_playback_paused(false)
	await get_tree().create_timer(0.3).timeout
	_check(AudioManager.get_music_position()>position+0.1,"ending music resumes")
	SceneRouter.goto_main_menu()
	await _settle()
	_check(AudioManager.get_music_event_id()==&"music_title_cafe","leaving replay restores title music")
	# 直接实例化正常后两幕，核对同曲从已有20秒位置交接；不伪造通关事实。
	AudioManager.stop_music()
	AudioManager.change_music(EndingMusicPresenter.EVENT,0.0,20.0,0.0,false)
	await get_tree().create_timer(0.2).timeout
	SceneRouter.comic_kind=&"epilogue"
	var epilogue = load("res://ui/comic/comic_player.tscn").instantiate()
	get_tree().root.add_child(epilogue)
	await get_tree().create_timer(0.2).timeout
	_check(AudioManager.get_music_event_id()==EndingMusicPresenter.EVENT and AudioManager.get_music_position()>20.1,"normal epilogue preserves ending music position")
	epilogue.get("_ending_music").set_handoff(true)
	epilogue.queue_free()
	print("REPLAY_MUSIC_DONE failures=",failures)
	get_tree().quit(failures)
func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
func _check(ok: bool,label: String) -> void:
	print("REPLAY_MUSIC ","PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
