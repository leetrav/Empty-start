extends Node
var failures := 0
var events: Array[StringName] = []
var capture := AudioEffectCapture.new()

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	AudioManager.event_played.connect(func(id: StringName, _player: AudioStreamPlayer): events.append(id))
	capture.buffer_length=8.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"UI"),capture)
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

# 正式页面、真实鼠标和Tab/Enter输入，检查选择与点击两类实际播放事件。
func _run() -> void:
	SaveManager.new_game()
	_check(SceneRouter.goto_identity_setup()==OK,"identity route")
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	var page := get_tree().current_scene
	var input: LineEdit=page.get("_streamer_name_input")
	input.text="音效试听"
	await _wait()
	events.clear()
	await _click(page.get("_streamer_continue"))
	_check(events.count(&"ui_name_confirm")==1 and events.count(&"ui_click")==0,"name confirmation once without generic double sound")
	var panel: Control=page.get("_player_presentation_page")
	var action: Button=panel.get_node("Center/Panel/Content/Action")
	var back: Button=panel.get_node("Center/Panel/Content/Back")
	await _move(Vector2(10,10))
	await _wait()
	events.clear()
	await _move(_point(back))
	_check(events.count(&"ui_menu_hover")==1,"real mouse hover plays bubble")
	await _key(KEY_TAB)
	_check(back.has_focus() and events.count(&"ui_menu_hover")==1,"Tab focus on hovered item does not double play")
	await _move(Vector2(10,10))
	await _wait()
	events.clear()
	await _key(KEY_TAB)
	_check(action.has_focus() and events.count(&"ui_menu_hover")==1,"keyboard selection plays bubble")
	events.clear()
	await _key(KEY_ENTER)
	_check(events.count(&"ui_click")==1 and not panel.visible,"keyboard confirmation plays click and advances")
	# 返回后使用真正鼠标点击，确认没有重复监听或页面重建。
	page.call("_back_to_player_presentation")
	await _wait()
	await _move(Vector2(10,10))
	await _wait()
	events.clear()
	await _click(back)
	_check(events.count(&"ui_click")==1 and page.get("_streamer_page").visible,"mouse back plays click and preserves flow")
	await _wait()
	var peak := 0.0
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	_check(peak>0.01,"UI bus has actual audio output")
	print("AU08_DONE failures=",failures," ui_peak_db=",linear_to_db(peak))
	get_tree().quit(failures)

func _point(button: Button) -> Vector2:
	return button.get_global_rect().get_center()*Vector2(get_window().size)/get_viewport().get_visible_rect().size
func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
func _click(button: Button) -> void:
	await _move(_point(button))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=_point(button)
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _wait() -> void:
	await get_tree().create_timer(0.12).timeout
func _check(ok: bool, message: String) -> void:
	print("AU08 ","PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
