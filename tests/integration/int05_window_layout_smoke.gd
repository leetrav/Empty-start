## TEST_ONLY：真实图形窗口逐次缩放，检查 HUD 可读性、几何比例与准心事件映射。
extends Node

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

# 复用隔离战斗夹具；不提交奖励，不保存用户周目。
func _run() -> void:
	SaveManager.new_game()
	var battle: Control = preload("res://tests/integration/int_04_test_only_sandbox.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	var hud: Control = battle.get_node("BattleHud")
	var aim: AimReticle = battle.get_node("%AimReticle")
	var output_dir: String = "res://.godot/int05-layout"
	DirAccess.make_dir_recursive_absolute(output_dir)
	get_window().mode = Window.MODE_WINDOWED
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1440, 900), Vector2i(1920, 810), Vector2i(960, 540), Vector2i(1920, 1080)]:
		get_window().size = dimensions
		for frame in range(8):
			await get_tree().process_frame
		var transform: Transform2D = get_viewport().get_final_transform() * hud.get_global_transform_with_canvas()
		var pixels: Vector2 = transform.get_scale().abs()
		hud.refresh_attack(1.0, AttackChargeInput.AttackPhase.READY)
		_check(is_equal_approx(pixels.x, pixels.y), "HUD 等比 " + str(dimensions))
		for path: String in ["BattleArea/TopBattleStatus/PKBar/PlayerPK", "BattleArea/TopBattleStatus/PKBar/OpponentPK", "BattleArea/TopBattleStatus/Tier", "BattleArea/ChargeFeedback/ChargeState"]:
			var label: Label = hud.get_node(path)
			_check(label.get_theme_font_size("font_size") * pixels.y >= 17.9, "文字像素下限 " + path + str(dimensions))
			_check(label.size.y >= label.get_minimum_size().y, "文字无垂直裁切 " + path + str(dimensions))
			_check(label.size.x >= label.get_minimum_size().x, "状态文字无水平裁切 " + path + str(dimensions))
		for side: String in ["PlayerStreamerArea/LiveDataHud", "OpponentStreamerArea/OpponentLiveDataHud"]:
			var metric: RichTextLabel = hud.get_node(side + "/Metrics/ViewerMetric")
			_check(metric.get_theme_font_size("normal_font_size") * pixels.y >= 17.9, "直播数据像素下限 " + side + str(dimensions))
		var area: Control = battle.get_node("%BarrageArea")
		for fraction: Vector2 in [Vector2(0.05, 0.05), Vector2(0.95, 0.05), Vector2(0.5, 0.5), Vector2(0.05, 0.95), Vector2(0.95, 0.95)]:
			var expected: Vector2 = area.get_global_rect().position + area.get_global_rect().size * fraction
			var raw: Vector2 = get_viewport().get_final_transform() * expected
			var event := InputEventMouseButton.new()
			event.position = raw
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			# 使用正式攻击输入分发，但不推进蓄力；验证布局改变后按下坐标仍一致。
			battle.process_mode = Node.PROCESS_MODE_INHERIT
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			_check(aim.get_aim_center_global_position().distance_to(expected) < 0.1, "准心映射 " + str(fraction) + str(dimensions))
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			battle.process_mode = Node.PROCESS_MODE_DISABLED
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir + "/%dx%d.png" % [dimensions.x, dimensions.y])
		if dimensions == Vector2i(960, 540):
			hud.show_failure()
			await get_tree().process_frame
			var restart: Button = battle.get_node("%RestartButton")
			_check(get_viewport().get_visible_rect().encloses(restart.get_global_rect()), "小窗口失败按钮可达")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output_dir + "/960x540-failure.png")
			battle.get_node("%FailureOverlay").hide()
			var pause_menu = battle.get_node("%PauseMenu")
			pause_menu.pause_game()
			await get_tree().process_frame
			for name: String in ["ResumeButton", "SettingsButton", "MainMenuButton", "ReloadButton"]:
				var button: Button = pause_menu.get_node("%" + name)
				_check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "小窗口暂停按钮可达 " + name)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output_dir + "/960x540-pause.png")
			pause_menu.resume_game()
		print("INT05_LAYOUT window=", get_window().size, " viewport=", get_viewport().get_visible_rect().size, " scale=", pixels)
	if DisplayServer.get_name().to_lower() == "windows":
		get_window().size = Vector2i(320, 180)
		for frame in range(4):
			await get_tree().process_frame
		_check(get_window().size.x >= 960 and get_window().size.y >= 540, "Windows 最小客户区保护")
	# 缩放后立即离树，验证延迟尺寸回调不会读已销毁的 HUD。
	get_window().size = Vector2i(1280, 720)
	battle.queue_free()
	for frame in range(4):
		await get_tree().process_frame
	print("INT05_LAYOUT checks=%d failures=%d (synthetic input; not physical mouse acceptance)" % [checks, failures])
	get_tree().quit(1 if failures else 0)

# 失败继续汇总所有窗口条件，保留每种尺寸的截图。
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INT05_LAYOUT " + message)
