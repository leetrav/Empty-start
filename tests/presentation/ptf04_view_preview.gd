## PTF-04 可交互正式 Sandbox 与排版诊断；诊断结果不代表玩家验收通过。
extends Control

const SANDBOX = preload("res://scenes/sandbox/sandbox.tscn")
var _sandbox: Control
var _hud: Control
var _output: String = ""
var _mode: String = "play"
var _bottom_anchor: bool = false
var _elapsed: float = 0.0
var _playing: bool = false
var _held: bool = false
var _target: BarrageView
var _last_log_second: int = -1
var _movie_frames: Array[Dictionary] = []
var _capture_busy: bool = false
var _next_frame_time: float = 0.0
var _encoding: bool = false
var _encode_data: Dictionary = {}
var _encode_view: TextureRect
var _encode_index: int = -1
var _scenario_target: BarrageView
var _scenario_count: int = 0
var _drop_started: bool = false
var _drop_finished: bool = false
var _drop_finished_at: float = -1.0


# 只向外部 D 盘保存证据，默认保留真实输入供手动试玩。
func _ready() -> void:
	get_window().title = "PTF04 Lane D Preview"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_window().size = Vector2i(1920, 1080)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ptf-output="):
			_output = argument.trim_prefix("--ptf-output=")
		if argument.begins_with("--ptf-mode="):
			_mode = argument.trim_prefix("--ptf-mode=")
		if argument == "--small":
			get_window().size = Vector2i(1280, 720)
			get_window().content_scale_size = Vector2i(1280, 720)
		if argument == "--wide":
			get_window().size = Vector2i(1600, 720)
			get_window().content_scale_size = Vector2i(2400, 1080)
		if argument == "--anchor-bottom":
			_bottom_anchor = true
	get_window().title = "PTF04 Lane D %s" % _mode
	if not _output.to_lower().replace("\\", "/").begins_with("d:/"):
		_output = ""
	if not _output.is_empty():
		DirAccess.make_dir_recursive_absolute(_output)
	call_deferred("_start")


# 直接实例化当前正式场景，未通过 debug PK 构造战斗进度。
func _start() -> void:
	if _mode == "encode":
		_encode_data = JSON.parse_string(FileAccess.get_file_as_string(_output.path_join("frames.json")))
		_encode_view = TextureRect.new()
		add_child(_encode_view)
		_encode_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_encode_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_encode_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_encoding = true
		return
	_sandbox = SANDBOX.instantiate()
	add_child(_sandbox)
	_hud = _sandbox.get_node("BattleHud")
	_hud.dialogue_bubble_presented.connect(_on_bubble_presented)
	await get_tree().process_frame
	await capture("initial")
	if _mode == "layout" or _mode == "read" or _mode == "read-proof":
		await _layout_samples()
		if _mode == "layout":
			get_tree().quit()
		else:
			var entry := BubbleDialogueEntry.new()
			for index: int in range(1, 31):
				entry.text += "%02d  晚上好晚上好，刚来的先坐\n" % index
			entry.display_duration_seconds = 600.0
			var bubble: StreamerBubbleView = _hud.show_dialogue_bubble(entry)
			await get_tree().create_timer(0.3).timeout
			await capture("scroll_initial")
			if _mode == "read-proof":
				var label: RichTextLabel = bubble.get_node("Text")
				label.scroll_to_line(label.get_line_count() - 1)
				await get_tree().process_frame
				print("PTF04 FULL TEXT preserved=%s chars=%d scroll=%.1f" % [label.text == entry.text, entry.text.length(), label.get_v_scroll_bar().value])
				await capture("scroll_last_line_30")
				get_tree().quit()
	elif _mode == "anchors":
		await _anchor_samples()
		get_tree().quit()
	elif _mode == "events":
		# 独立事件契约回归；明确记录为合成 Tier 通知，不计入玩家验收。
		_sandbox.get("_timed_opponent_dialogue_presenter").set_process(false)
		_hud.set_opponent_portrait_connected(true)
		var presenter: Node = _sandbox.get("_combat_state_dialogue_presenter")
		presenter.set("_attempt_active", true)
		presenter.set("_last_tier", 2)
		presenter.call("_on_tier_changed", 1, 0.57)
		await get_tree().create_timer(0.3).timeout
		await capture("tier2_to_tier1_formal_reply")
		get_tree().quit()
	else:
		var echo: StreamerBubbleHitEchoPresenter = _sandbox.get("_hit_echo_presenter")
		if _mode.begins_with("record-A"):
			echo.configure_policy(StreamerBubbleHitEchoPresenter.EchoPolicy.SPECIAL_THROTTLED, 6.0)
		elif _mode.begins_with("record-B"):
			echo.configure_policy(StreamerBubbleHitEchoPresenter.EchoPolicy.STORY_WITH_IDLE, 6.0)
		var caption := Label.new()
		caption.text = "PTF-04 待选 %s | 受控输入/正式假卡实例 | 预览限频6秒 | F8截图/F9退出" % _mode
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -28.0
		caption.offset_bottom = 0.0
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 18)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
		_playing = true
		if _mode.begins_with("record-") and not _output.is_empty():
			DirAccess.make_dir_recursive_absolute(_output.path_join("frames"))


# 录像只操纵真实生成目标的输入；不改 PK、Tier、寿命或生成位置。
func _process(delta: float) -> void:
	if _encoding:
		_encode_frame(delta)
		return
	if not _playing:
		return
	_elapsed += delta
	var flow: BattleAttemptFlow = _sandbox.get_battle_attempt_flow()
	if int(_elapsed) != _last_log_second:
		_last_log_second = int(_elapsed)
		print("PTF04 LIVE t=%.1f tier=%d source_pk=%.6f hud=%s opponent=%s" % [_elapsed, flow.get_current_tier(), flow.get_hit_resolution().get_player_pk(), _hud.get_pk_display_snapshot(), _sandbox.get_node("%OpponentLiveDataHud").get_display_snapshot()])
	if _mode.begins_with("record-"):
		_add_comparison_target(flow)
		_drive_real_input(flow)
		if not _capture_busy and _elapsed >= _next_frame_time:
			_next_frame_time = _elapsed + 0.125
			_capture_movie_frame()
		var should_finish: bool = _elapsed >= 60.0
		if _mode.ends_with("-down"):
			should_finish = (_drop_finished_at >= 0.0 and _elapsed >= _drop_finished_at + 6.0) or _elapsed >= 180.0
		if should_finish:
			_playing = false
			_finish_movie_capture()


# 实时采集当前 GPU 帧，不使用 MovieWriter 的固定步长改变战斗时间。
func _capture_movie_frame() -> void:
	if _output.is_empty():
		return
	_capture_busy = true
	await RenderingServer.frame_post_draw
	var file_name: String = "frames/%05d.jpg" % _movie_frames.size()
	get_viewport().get_texture().get_image().save_jpg(_output.path_join(file_name), 0.88)
	_movie_frames.append({"time": _elapsed, "file": file_name})
	_capture_busy = false


# 采集时间戳只用于原样回放真实帧，保留掉帧时的实际停留时间。
func _finish_movie_capture() -> void:
	await get_tree().process_frame
	while _capture_busy:
		await get_tree().process_frame
	var file := FileAccess.open(_output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"duration": _elapsed, "frames": _movie_frames}))
	print("PTF04 REALTIME CAPTURE duration=%.2f frames=%d" % [_elapsed, _movie_frames.size()])
	get_tree().quit()


# 无 FFmpeg 环境下复用原生 MovieWriter，把带时间戳的真实帧封装为视频。
func _encode_frame(delta: float) -> void:
	_elapsed += delta
	var frames: Array = _encode_data["frames"]
	var index: int = maxi(_encode_index, 0)
	while index + 1 < frames.size() and float(frames[index + 1]["time"]) <= _elapsed:
		index += 1
	if index != _encode_index:
		_encode_index = index
		_encode_view.texture = ImageTexture.create_from_image(Image.load_from_file(_output.path_join(frames[index]["file"])))
	if _elapsed >= float(_encode_data["duration"]):
		get_tree().quit()


# 自动跟随自然生成实例完成真实蓄力与释放；此录像标为受控输入，不能替代真人手感。
func _drive_real_input(flow: BattleAttemptFlow) -> void:
	var attack: AttackChargeInput = flow.get_attack_input()
	var area: BarrageArea = flow.get_barrage_area()
	# 补充录像在首次 T2 暂停自动攻击，让真实回拉自然降到 T1，验证正式降档台词。
	if _mode.ends_with("-down"):
		if flow.get_current_tier() == 2 and not _held and not _drop_started:
			_drop_started = true
		if _drop_started and not _drop_finished:
			if flow.get_current_tier() <= 1:
				_drop_finished = true
				_drop_finished_at = _elapsed
			else:
				return
	if not _held and attack.can_start_charging():
		_target = null
		for child: Node in area.get_children():
			if child is BarrageView and child.runtime_record != null and not child.runtime_record.is_repeat:
				if _target == null or child.runtime_record.strength > _target.runtime_record.strength:
					_target = child
		if is_instance_valid(_scenario_target) and not _scenario_target.is_queued_for_deletion():
			_target = _scenario_target
		if is_instance_valid(_target):
			_move_to_target(flow.get_aim_reticle(), _target)
			_send_button(true, flow.get_aim_reticle())
			_held = true
	if _held:
		if is_instance_valid(_target) and not _target.is_queued_for_deletion():
			_move_to_target(flow.get_aim_reticle(), _target)
		if attack.is_fully_charged() or not is_instance_valid(_target):
			_send_button(false, flow.get_aim_reticle())
			_held = false


# A/B 都在相同时段注入两个正式假卡实例，只用于候选策略比较，不冒充自然反击频率。
func _add_comparison_target(flow: BattleAttemptFlow) -> void:
	if _mode.ends_with("-down"):
		return
	if _scenario_count >= 2 or _elapsed < 36.0 + float(_scenario_count) * 3.0 or not flow.get_attack_input().can_start_charging():
		return
	var profile: LevelProfile = flow.get_current_level_profile().duplicate() as LevelProfile
	profile.special_trait_ids = profile.special_trait_ids.duplicate()
	if not profile.special_trait_ids.has("fake_card"):
		profile.special_trait_ids.append("fake_card")
	var traits: Array[StringName] = [BarrageTraitSet.FAKE_CARD]
	_scenario_target = flow.get_barrage_area().spawn_normal_barrage(profile, profile.get_normal_speech_pool()[0], traits)
	if _scenario_target != null:
		_scenario_count += 1
		print("PTF04 COMPARISON FIXTURE actual_fake_card=%d t=%.1f" % [_scenario_count, _elapsed])


# 与现有输入回归相同的窗口坐标转换，只提交输入事件。
func _move_to_target(aim: AimReticle, target: BarrageView) -> void:
	var point: Vector2 = get_viewport().get_final_transform() * (aim.get_canvas_transform() * target.get_global_rect().get_center())
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# 松开时沿用准心已经收到的坐标，不重读系统光标。
func _send_button(pressed: bool, aim: AimReticle) -> void:
	var point: Vector2 = get_viewport().get_final_transform() * (aim.get_canvas_transform() * aim.get_aim_center_global_position())
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# 每条日志来自实际已创建气泡，记录文字、事件与当前真实阶段。
func _on_bubble_presented(side: int, event_id: StringName, text: String) -> void:
	print("PTF04 BUBBLE t=%.1f side=%d event=%s text=%s" % [_elapsed, side, event_id, text])


# 用正式原文的重复副本作压力输入，保持生产台词表不变。
func _layout_samples() -> void:
	_sandbox.get("_timed_opponent_dialogue_presenter").set_process(false)
	_sandbox.get("_battle_attempt_flow").get_barrage_area().stop_normal_generation()
	_sandbox.get("_battle_attempt_flow").get_opponent_pk_bar().stop_pullback()
	_sandbox.get("_battle_attempt_flow").get_attack_input().set_combat_active(false)
	var config: BubbleDialogueConfig = FormalSheetRuntimeConsumer.new().create_dialogue_config("story_level_001")
	var text: String = config.entries[0].text
	for repetitions: int in [1, 3, 8, 30]:
		_hud.clear_dialogue_bubbles()
		var entry := BubbleDialogueEntry.new()
		entry.text = text.repeat(repetitions)
		entry.display_duration_seconds = 60.0
		var bubble: StreamerBubbleView = _hud.show_dialogue_bubble(entry)
		await get_tree().create_timer(0.3).timeout
		var label: RichTextLabel = bubble.get_node("Text")
		print("PTF04 TEXT repeats=%d chars=%d font=%d label_h=%.1f content_h=%d bubble=%s" % [repetitions, entry.text.length(), label.get_theme_font_size("normal_font_size"), label.size.y, label.get_content_height(), bubble.size])
		await capture("text_%d" % repetitions)
		_hud.clear_dialogue_bubbles()
	# Resource 绑定后，旧占位调用不能回退数值；未知项只遮罩显示。
	var session := LiveSessionData.new()
	session.comment_count = 17
	_hud.bind_opponent_live_session(session, ["viewer_count", "like_count", "fan_count"])
	_sandbox.get_node("%OpponentLiveDataHud").set_values(0, 0, 0, 0)
	print("PTF04 BINDING %s" % _sandbox.get_node("%OpponentLiveDataHud").get_display_snapshot())
	await capture("unknown_metrics")
	# UI 输入回归：晚到的旧 Tier 通知不能覆盖新 PK。
	_hud.refresh_pk(0.72, 3)
	await get_tree().create_timer(0.25).timeout
	_hud.on_tier_changed(1, 0.5)
	await get_tree().create_timer(0.25).timeout
	print("PTF04 STALE TIER %s" % _hud.get_pk_display_snapshot())
	await capture("pk_stale_notification")


# 正式贴图可见 alpha 边界审计，固定同角色缩放和锚点；此模式明确为资源诊断。
func _anchor_samples() -> void:
	_sandbox.get("_timed_opponent_dialogue_presenter").set_process(false)
	var flow: BattleAttemptFlow = _sandbox.get_battle_attempt_flow()
	flow.stop()
	var assets: PresentationAssetConfig = preload("res://data/shared/presentation_asset_config.tres")
	var consumer := FormalSheetRuntimeConsumer.new()
	var audit: Array[Dictionary] = []
	var catalog: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")
	for profile: LevelProfile in catalog.profiles:
		_hud.reset_for_attempt()
		_hud.configure_portrait_character(profile.streamer_id)
		_hud.configure_streamers("排版诊断", profile.streamer_name)
		_hud.configure_streamer_assets(assets.player_streamer_portrait, assets.player_live_background, null, profile.streamer_portrait, profile.streamer_live_background, null)
		_hud.configure_opponent_tier_textures(profile.streamer_portrait, profile.opponent_tier_01_portrait, profile.opponent_tier_02_portrait, profile.opponent_tier_03_portrait)
		_hud.configure_opponent_result(profile, consumer.get_level_presentation(profile.level_id))
		var tier: OpponentTierPortrait = _hud.opponent_tier_portrait
		tier.visible_anchor_ratio = Vector2(0.5, 1.0) if _bottom_anchor else Vector2(0.5, 0.5)
		_hud.opponent_portrait_motion.set_idle_strength(0.0, 0.0)
		for stage: int in [1, 2, 3, 4, 5]:
			_hud.refresh_pk(0.6, stage)
			tier.reset_for_tier(stage)
			await get_tree().create_timer(0.2).timeout
			var portrait: TextureRect = _hud.get_node("%OpponentPortraitArt")
			var bounds: Rect2 = tier.get("_visible_bounds")[portrait.texture]
			var local_anchor: Vector2 = (bounds.position + bounds.size * tier.visible_anchor_ratio) / portrait.texture.get_size() * portrait.size
			var actual_anchor: Vector2 = portrait.get_global_transform() * local_anchor
			var expected_anchor: Vector2 = tier.get_global_transform() * (tier.size * tier.visible_anchor_ratio)
			audit.append({"role": profile.streamer_id, "tier": stage, "texture": portrait.texture.resource_path, "raw_size": str(portrait.texture.get_size()), "alpha_bounds": str(bounds), "anchor_error_px": actual_anchor.distance_to(expected_anchor)})
			print("PTF04 ANCHOR %s" % audit[-1])
			await capture("%s_t%d" % [profile.streamer_id, stage])
		_hud.play_opponent_result(true)
		await _hud.opponent_result_presentation_finished
		await capture("%s_defeat" % profile.streamer_id)
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("portrait_bounds.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(audit, "\t"))


# 原生 GPU 截图留在本机；可在交互试玩中由按键保存当前状态。
func capture(stem: String) -> void:
	if _output.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(stem + ".png"))


# F8 只采集当前实际输入产生的画面，F9 结束本次预览。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			capture("manual_%d" % Time.get_ticks_msec())
		elif event.keycode == KEY_F9:
			get_tree().quit()
