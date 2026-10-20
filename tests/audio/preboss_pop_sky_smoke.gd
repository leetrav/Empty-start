extends Node
var _failures: int = 0

# 正式Plan B四关验证：真实音乐事件、播放增益、暂停、开场接管与退出清理。
func _ready() -> void:
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	for index: int in 4:
		SaveManager.new_game()
		SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
		SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
		SaveManager.data.next_normal_level_order = index + 1
		for previous: int in index:
			SaveManager.data.completed_normal_level_ids.append(catalog.profiles[previous].level_id)
		AudioManager.change_music(&"music_rest_room")
		var scene: Node = load("res://scenes/sandbox/sandbox_plan_b.tscn").instantiate()
		add_child(scene)
		await get_tree().create_timer(0.12).timeout
		var id: String = catalog.profiles[index].streamer_id
		var music: TierMusicPresenter = scene.get("_battle_music") as TierMusicPresenter
		_check(music != null and music.profile.streamer_id == StringName(id), id + " uses actual profile")
		_check(AudioManager.get_music_event_id() == TierMusicPresenter.PREBOSS_EVENT, id + " T0 Pop Sky")
		var initial_gain: float = _playing_gain()
		_check(initial_gain < 0.08, id + " starts quietly")
		await get_tree().create_timer(1.55).timeout
		_check(_playing_gain() > 0.24, id + " reaches -12dB after 1.5s")
		var player: AudioStreamPlayer = AudioManager.get("_music_player") as AudioStreamPlayer
		_check(player.stream is AudioStreamOggVorbis and player.stream.loop, id + " native loop enabled")
		music.request_tier(0)
		var pos: float = AudioManager.get_music_position()
		_check(pos > 1.0, id + " duplicate T0 does not restart")
		music.set_paused(true)
		await get_tree().create_timer(0.15).timeout
		_check(absf(AudioManager.get_music_position() - pos) < 0.1, id + " pause freezes music")
		music.set_paused(false)
		music.begin_connection()
		var expected: StringName = music.profile.entrance_event_id if music.profile.entrance_event_id != &"" else music.profile.event_ids[0]
		_check(AudioManager.get_music_event_id() == expected, id + " Boss entrance takes over")
		await get_tree().create_timer(0.2).timeout
		_check(music.owns_music(), id + " keeps ownership after handoff")
		scene.queue_free()
		await get_tree().process_frame
		_check(AudioManager.get_music_event_id() == &"", id + " exit stops owned music")
	print("PREBOSS_DONE failures=", _failures)
	get_tree().quit(_failures)

func _playing_gain() -> float:
	var player: AudioStreamPlayer = AudioManager.get("_music_player") as AudioStreamPlayer
	return player.volume_linear

func _check(ok: bool, label: String) -> void:
	print("PREBOSS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		_failures += 1
