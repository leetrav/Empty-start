extends Control

const AREA = preload("res://systems/barrage_generation/barrage_area.tscn")
const AIM = preload("res://systems/combat_attack/aim_reticle.tscn")
const TOUCH = preload("res://ui/mobile/mobile_touch_aim.tscn")
var _phones: Array[Dictionary] = []
var _replay: bool = false
var _elapsed: float = 0.0
var _step: int = -1
var _media: String = ""
var _captures: Dictionary = {}

class FingerProxy extends Control:
	var point: Vector2
	var active: bool = false
	var radius: float = 60.0
	## 粉色圆只是指腹遮挡模拟，明确叠在真正准心/进度反馈上方。
	func _draw() -> void:
		if active:
			draw_circle(point, radius, Color(0.94, 0.57, 0.55, 0.97))
			draw_arc(point, radius, 0, TAU, 48, Color(1.0, 0.85, 0.8), 3.0, true)


## 六台原生SubViewport并列；没有写生产存档或用PK调试跳过战斗。
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		_replay = _replay or argument == "--replay"
		if argument.begins_with("--media="):
			_media = argument.trim_prefix("--media=")
	if not _media.is_empty():
		assert(_media.replace("\\", "/").to_lower().begins_with("d:/"))
		DirAccess.make_dir_recursive_absolute(_media)
	var bg := ColorRect.new()
	bg.color = Color("151e29")
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	_label(self, Vector2(28, 12), "PTF-05 V0 · A 上方偏置 / B 左上偏置 · 粉色圆模拟指腹 · 真人方案待选", 28)
	_label(self, Vector2(28, 52), "可用鼠标在任一屏内长按、拖动、释放（转换为真实ScreenTouch）；录像为触摸模拟，非Android真机/整局验收", 20)
	for row: int in 3:
		for column: int in 2:
			_create_phone(row, column)
	print("PTF05_MOBILE_READY manual=", not _replay, " variants=2 ratios=16:9,19.5:9,20:9")


## 每台使用正式准心、攻击时序、结算和真实BarrageView；固定目标只用于测位。
func _create_phone(row: int, column: int) -> void:
	var widths: Array[int] = [1920, 2340, 2400]
	var dpis: Array[float] = [320.0, 480.0, 640.0]
	var ratios: Array[String] = ["16:9", "19.5:9", "20:9"]
	var variant: String = "a" if column == 0 else "b"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(widths[row], 1080)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var canvas := Control.new()
	canvas.size = Vector2(viewport.size)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("273a4b")
	background.size = canvas.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	var profile: LevelProfile = load("res://data/level_configuration/level_001.tres")
	var numerics: CombatNumericsConfig = load("res://data/combat_stage/combat_numerics.tres").duplicate(true)
	# MovieWriter慢于实时，测位目标在内存延长寿命；0.8秒攻击时序仍用正式值。
	for strength: int in [1, 2, 3]:
		numerics.lifetimes_by_type_seconds["word_strength_%d" % strength] = 120.0
	var area: BarrageArea = AREA.instantiate()
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(100, 180)
	area.size = Vector2(viewport.size.x - 200, 780)
	canvas.add_child(area)
	area.configure_combat_numerics(numerics)
	var target: BarrageView = area.spawn_normal_barrage(profile, profile.get_normal_speech_pool()[0], [], true)
	target.position = Vector2(area.size.x * 0.5, 350)
	var aim: AimReticle = AIM.instantiate()
	canvas.add_child(aim)
	var attack := AttackChargeInput.new()
	canvas.add_child(attack)
	attack.configure_target_query(aim, area)
	attack.configure_attack_timing(numerics.create_attack_timing_config())
	attack.configure_combat_aim_radii(numerics)
	var hit := HitResolution.new(0.5, 0.0, 1.0, numerics.positive_pk_shot_cap, numerics.negative_pk_shot_cap, numerics)
	attack.configure_hit_resolution(hit)
	attack.charge_state_changed.connect(func(p: float, held: bool, full: bool, _phase: int): aim.set_charge_visual_state(p, held, full))
	var overlay: MobileTouchAim = TOUCH.instantiate()
	overlay.layout = load("res://data/test_only/ptf05/mobile_layout_%s.tres" % variant)
	canvas.add_child(overlay)
	assert(overlay.bind_attack_input(attack))
	var inset: float = [0.0, 72.0, 96.0][row]
	overlay.set_preview_metrics(dpis[row], Rect2(inset, 24, viewport.size.x - inset * 2.0, 1032))
	overlay.configure_regions(Rect2(100, 180, viewport.size.x - 200, 780))
	assert(overlay.set_enabled(true))
	var finger := FingerProxy.new()
	finger.size = canvas.size
	finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finger.radius = dpis[row] / 25.4 * 5.0
	canvas.add_child(finger)
	var index: int = _phones.size()
	var phone: Dictionary = {"viewport": viewport, "area": area, "aim": aim, "attack": attack, "overlay": overlay, "finger": finger, "target": target, "shots": 0, "variant": variant, "ratio": ratios[row], "dpi": dpis[row], "profile": profile}
	_phones.append(phone)
	attack.shot_snapshot_created.connect(_on_snapshot.bind(index))
	var pane := TextureRect.new()
	pane.position = Vector2(24 + column * 948, 130 + row * 310)
	pane.size = Vector2(920, 280)
	pane.texture = viewport.get_texture()
	pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pane.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	pane.gui_input.connect(_on_manual_input.bind(index, pane))
	add_child(pane)
	_label(self, pane.position - Vector2(0, 30), "%s / %s / DPI%.0f / 刘海安全区模拟 · 真实固定目标" % [variant.to_upper(), ratios[row], dpis[row]], 21)


## 实体鼠标/触屏在缩略屏内转换成该原生Viewport坐标，复播和手动共用入口。
func _on_manual_input(event: InputEvent, index: int, pane: TextureRect) -> void:
	if _replay:
		return
	var phone: Dictionary = _phones[index]
	var viewport: SubViewport = phone["viewport"]
	var factor: float = minf(pane.size.x / viewport.size.x, pane.size.y / viewport.size.y)
	var origin: Vector2 = (pane.size - Vector2(viewport.size) * factor) * 0.5
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var touch := InputEventScreenTouch.new()
		touch.position = (event.position - origin) / factor
		touch.pressed = event.pressed
		_send(index, touch)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var drag := InputEventScreenDrag.new()
		drag.position = (event.position - origin) / factor
		_send(index, drag)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		var converted: InputEvent = event.duplicate()
		converted.set("position", (event.position - origin) / factor)
		_send(index, converted)


## 真实ScreenTouch经过_input/gui/unhandled_input管线，未直接调用业务私有处理。
func _send(index: int, event: InputEvent) -> void:
	var phone: Dictionary = _phones[index]
	var proxy: FingerProxy = phone["finger"]
	if event is InputEventScreenTouch and event.index == 0:
		proxy.active = event.pressed and not event.canceled
		proxy.point = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		proxy.point = event.position
	proxy.queue_redraw()
	(phone["viewport"] as SubViewport).push_input(event, true)
	if _replay and event is InputEventScreenTouch and event.pressed:
		print("PTF05_TOUCH_INPUT panel=", index, " finger=", event.index, " position=", event.position, " held=", (phone["attack"] as AttackChargeInput).is_charge_held())


## 复播只移动指针并等待真实0.8秒；不修改PK、蓄力进度或目标选择结果。
func _process(delta: float) -> void:
	if not _replay:
		return
	_elapsed += delta
	var step: int = 0 if _elapsed < 0.5 else (1 if _elapsed < 1.55 else (2 if _elapsed < 2.4 else (3 if _elapsed < 2.65 else 4)))
	if step != _step:
		_step = step
		for index: int in _phones.size():
			if step in [1, 3]:
				var down := InputEventScreenTouch.new()
				down.position = _finger_for_target(index)
				down.pressed = true
				_send(index, down)
			elif step in [2, 4]:
				var up := InputEventScreenTouch.new()
				up.position = _finger_for_target(index)
				_send(index, up)
	if step == 1:
		for index: int in _phones.size():
			var drag := InputEventScreenDrag.new()
			drag.position = _finger_for_target(index) + Vector2(sin(_elapsed * 2.0) * 18.0, 0)
			_send(index, drag)
	if _elapsed > 1.02 and not _captures.has("partial"):
		_capture("partial")
	if _elapsed > 1.42 and not _captures.has("full"):
		_capture("full")
	if _elapsed > 3.1 and not _captures.has("release"):
		_capture("release")
	if _elapsed > 4.0 and not _captures.has("boundary_checks"):
		_captures["boundary_checks"] = true
		_run_boundaries()
	if _elapsed > 6.0:
		for phone: Dictionary in _phones:
			if phone["shots"] != 1:
				push_error("PTF05_REPLAY_FAIL shots=%d variant=%s ratio=%s" % [phone["shots"], phone["variant"], phone["ratio"]])
				get_tree().quit(1)
				return
		print("PTF05_MOBILE_REPLAY_PASS six_viewports=true real_shots=6 undercharge_cancelled=true synthetic_touch=true physical_android=false")
		get_tree().quit()


## 固定目标测量偏置；输入到命中仍走真实组件，目标没有被调试命令消除。
func _finger_for_target(index: int) -> Vector2:
	var phone: Dictionary = _phones[index]
	var target: BarrageView = phone["target"]
	var viewport: SubViewport = phone["viewport"]
	var layout: MobileTouchLayout = (phone["overlay"] as MobileTouchAim).layout
	var offset: Vector2 = layout.aim_offset_mm * float(phone["dpi"]) / 25.4
	return target.get_global_rect().get_center() - offset


## 同一真实释放快照必须和实际可见准心同点，并且命中当前真实BarrageView。
func _on_snapshot(snapshot: AttackTargetSnapshot, index: int) -> void:
	var phone: Dictionary = _phones[index]
	phone["shots"] += 1
	assert(snapshot.get_aim_center_global_position().distance_to((phone["aim"] as AimReticle).get_aim_center_global_position()) < 0.1)
	assert(snapshot.get_target_instance_ids().has((phone["target"] as BarrageView).get_instance_id()))
	print("PTF05_TOUCH_SHOT ", phone["variant"], " ", phone["ratio"], " aim=", snapshot.get_aim_center_global_position())


## 边界复核为模拟事件，不把它写成真实系统返回/硬件焦点验收。
func _run_boundaries() -> void:
	for index: int in _phones.size():
		var phone: Dictionary = _phones[index]
		var attack: AttackChargeInput = phone["attack"]
		var overlay: MobileTouchAim = phone["overlay"]
		var down := InputEventScreenTouch.new()
		down.position = _finger_for_target(index)
		down.pressed = true
		_send(index, down)
		var extra := InputEventScreenTouch.new()
		extra.index = 1
		extra.position = Vector2(400, 400)
		extra.pressed = true
		var original: Vector2 = overlay.get_aim_viewport_position()
		_send(index, extra)
		assert(overlay.get_aim_viewport_position() == original)
		extra.pressed = false
		_send(index, extra)
		var duplicate_mouse := InputEventMouseButton.new()
		duplicate_mouse.device = InputEvent.DEVICE_ID_EMULATION
		duplicate_mouse.button_index = MOUSE_BUTTON_LEFT
		duplicate_mouse.position = down.position
		(phone["viewport"] as SubViewport).push_input(duplicate_mouse, true)
		assert(attack.is_charge_held())
		var cancel := InputEventScreenTouch.new()
		cancel.position = down.position
		cancel.canceled = true
		_send(index, cancel)
		assert(not attack.is_charge_held())
		_send(index, down)
		overlay.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		assert(not attack.is_charge_held())
		_send(index, down)
		(phone["viewport"] as SubViewport).size += Vector2i(2, 0)
		await get_tree().process_frame
		assert(not attack.is_charge_held())
		(phone["finger"] as FingerProxy).active = false
		(phone["finger"] as FingerProxy).queue_redraw()
	print("PTF05_BOUNDARIES_PASS extra_finger_ignored=true touch_cancel=true focus_notification=true viewport_change=true")


## 直接保存真实GPU渲染的三个屏比例，截图全部在D盘。
func _capture(label: String) -> void:
	_captures[label] = true
	if _media.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	for phone: Dictionary in _phones:
		var path: String = _media.path_join("mobile_%s_%s_%s.png" % [phone["variant"], String(phone["ratio"]).replace(":", "-"), label])
		assert((phone["viewport"] as SubViewport).get_texture().get_image().save_png(path) == OK)
	assert(get_viewport().get_texture().get_image().save_png(_media.path_join("comparison_%s.png" % label)) == OK)


## 说明标签属于审核场景，不进入生产HUD或正式剧情文案。
func _label(parent: Node, point: Vector2, text: String, font_size: int) -> void:
	var label := Label.new()
	label.position = point
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
