extends Node
const FX: PackedScene = preload("res://systems/presentation/paradox_comic_transition.tscn")
var failures: int = 0
var events: Array[Dictionary] = []
var recording_text: bool = false
var ticks: Array[int] = []
var text_capture := AudioEffectCapture.new()
var music_capture := AudioEffectCapture.new()
var impact_capture := AudioEffectCapture.new()
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	get_window().title="AU-07 text tick and contradiction audio"
	AudioManager.event_played.connect(_on_event)
	text_capture.buffer_length=4.0
	music_capture.buffer_length=4.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"UI"),text_capture)
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Music"),music_capture)
	impact_capture.buffer_length=5.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"SFX"),impact_capture)
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

# 正式CSV初始化、真实漫画逐字与真实矛盾判定；表现分镜使用正式组件原时长。
func _run() -> void:
	_check(SceneRouter.goto_comic(&"opening")==OK,"real comic route")
	await _settle()
	var comic: ComicPlayer=get_tree().current_scene as ComicPlayer
	var player: AudioStreamPlayer=comic.get("_sound")
	_check(player.stream.resource_path.ends_with("text_tick.ogg") and player.stream.get_length()<0.08 and player.volume_db==-5.0,"CSV resolves crisp audible replacement")
	text_capture.clear_buffer()
	music_capture.clear_buffer()
	recording_text=true
	await get_tree().create_timer(0.6).timeout
	# 同帧多次请求也只响一次，保证多个旁白块共用短限流。
	var before := ticks.size()
	for index in range(12): comic.call("_play_writing_tick")
	_check(ticks.size()-before<=1,"same-frame writing requests coalesce")
	await _escape()
	before=ticks.size()
	await get_tree().create_timer(0.25).timeout
	_check(get_tree().paused and ticks.size()==before,"pause stops text sounds")
	await _escape()
	await get_tree().create_timer(0.6).timeout
	recording_text=false
	# 保留真实开场BGM，检测两个总线确有输出，避免只测到播放事件却听不到。
	var text_peak := _peak(text_capture)
	var music_peak := _peak(music_capture)
	print("AU07_MIX text_peak_db=",linear_to_db(text_peak)," music_peak_db=",linear_to_db(music_peak))
	_check(text_peak>0.2 and text_peak<1.0,"text output is audible and below clipping")
	_check(music_peak>0.001,"real BGM remains audible during narration")
	_check(ticks.size()>2,"actual progressive narration plays new ticks")
	for index in range(1,ticks.size()): _check(ticks[index]-ticks[index-1]>=65,"text tick is rate limited")
	for index in range(40):
		if SceneRouter.is_transitioning(): break
		comic.advance()
	await _settle()
	AudioManager.stop_music()
	var layer := CanvasLayer.new()
	layer.layer=10
	add_child(layer)
	var fx: ParadoxComicTransition=FX.instantiate() as ParadoxComicTransition
	layer.add_child(fx)
	fx.play_transition()
	await get_tree().create_timer(0.45).timeout
	_check(_count(&"contradiction_slash")==0 and _count(&"contradiction_banner_impact")==0,"opening silence preserved")
	await get_tree().create_timer(0.36).timeout
	_check(_count(&"contradiction_slash")==1 and _count(&"contradiction_banner_impact")==0,"slash starts on visual cue")
	get_tree().paused=true
	await get_tree().create_timer(0.3).timeout
	_check(_count(&"contradiction_banner_impact")==0,"paused visual does not advance to impact")
	get_tree().paused=false
	await get_tree().create_timer(0.65).timeout
	_check(_count(&"contradiction_banner_impact")==1,"title impact sounds once")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/au07-banner.png")
	fx.reset_for_attempt()
	_check(not fx.get("_slash_sound").playing and not fx.get("_impact_sound").playing,"reset cancels owned tails")
	fx.play_transition()
	await get_tree().create_timer(1.5).timeout
	_check(_count(&"contradiction_slash")==2 and _count(&"contradiction_banner_impact")==2,"replay has one cue of each")
	await get_tree().create_timer(0.9).timeout
	impact_capture.clear_buffer()
	await get_tree().create_timer(0.15).timeout
	var sound: AudioStreamPlayer=fx.get("_impact_sound")
	_check(sound.playing and _peak(impact_capture)>0.003,"actual extended tail remains audible during title hold")
	var elapsed: float=fx.get("_elapsed")
	var position := sound.get_playback_position()
	get_tree().paused=true
	await get_tree().create_timer(0.2).timeout
	_check(fx.get("_elapsed")==elapsed and absf(sound.get_playback_position()-position)<0.08,"tail and visual clock pause together")
	get_tree().paused=false
	await get_tree().create_timer(0.45).timeout
	var expected: float=db_to_linear(-3.0)*fx.get_node("Title").modulate.a
	_check(sound.playing and absf(sound.volume_linear-expected)<0.01 and sound.volume_db < -9.0,"tail fades with actual title opacity")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/au09-tail-fade.png")
	await get_tree().create_timer(0.8).timeout
	_check(not fx.visible and not sound.playing,"tail stops when transition disappears")
	# 另录一次不含暂停的完整演出，让用户试听正常节奏；不拼接或合成运行音轨。
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"SFX"),recorder)
	recorder.set_recording_active(true)
	fx.play_transition()
	await get_tree().create_timer(3.8).timeout
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav("D:/src/playtest-20261020/au09-banner-demo.wav")
	fx.reset_for_attempt()
	var presenter: Node=load("res://core/audio/battle_audio_presenter.gd").new()
	add_child(presenter)
	presenter.bind_sources(null,null)
	var system := ContradictionBreakSystem.new()
	add_child(system)
	var catalog: LevelCatalog=load("res://data/level_configuration/level_catalog.tres")
	_check(system.load_level_content(catalog.profiles[0]),"real contradiction content")
	# connect直接绑定同一正式消费者回调，成功事实由原判定系统产生。
	system.outcome_locked.connect(Callable(presenter,"_on_contradiction_result"))
	_check(system.start_window(ContradictionWindowConfig.new()) and system.register_launched_shot(),"real window and shot")
	var hit_ids: Array[String]=[system.get_true_contradictions()[0].original_sentence_id]
	system.resolve_shot_hit_ids(hit_ids)
	_check(_count(&"contradiction_break")==1,"real successful break sounds once")
	system.resolve_shot_hit_ids(hit_ids)
	_check(_count(&"contradiction_break")==1,"duplicate resolution adds no break sound")
	await get_tree().create_timer(0.7).timeout
	print("AU07_DONE failures=",failures," ticks=",ticks.size())
	get_tree().quit(failures)

func _on_event(id: StringName, player: AudioStreamPlayer) -> void:
	events.append({"id":id,"path":player.stream.resource_path,"ms":Time.get_ticks_msec()})
	if id==&"comic_write" and recording_text: ticks.append(Time.get_ticks_msec())
	if id in [&"comic_write",&"contradiction_slash",&"contradiction_banner_impact",&"contradiction_break"]:
		_check(not "typewriter.wav" in player.stream.resource_path,"actual player uses new asset: "+str(id))
	if id==&"contradiction_banner_impact":
		_check(player.stream.resource_path.ends_with("punch_tail.ogg") and player.stream.get_length()>2.5,"banner uses selected extended hit10")
	if id==&"contradiction_break":
		_check(player.stream.resource_path.ends_with("punch_hit.ogg"),"successful hit uses selected hit10 dry sound")
func _count(id: StringName) -> int:
	var count := 0
	for event: Dictionary in events:
		if event.id==id: count+=1
	return count
func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return peak
func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame
func _escape() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ESCAPE
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
func _check(ok: bool,message: String) -> void:
	print("AU07 ","PASS " if ok else "FAIL ",message)
	if not ok:
		failures+=1
		push_error(message)
