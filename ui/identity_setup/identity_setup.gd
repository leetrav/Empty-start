extends Control

# 已交付的演出组件通过公开信号接入；缺少正式素材的环节由玩家正常继续。
signal player_name_pawprint_presentation_requested(streamer_name: String)
signal player_name_pawprint_presentation_completed(streamer_name: String)
signal room_computer_transition_requested(identity_id: StringName)
signal room_computer_transition_completed

# 保存成功的事实通知；RS-12 接收后通过 SceneRouter 打开真正的开局房间。
signal opening_saved(run_data: SaveData)

enum Step { STREAMER, PLAYER_PRESENTATION, IDENTITY, ROOM_TRANSITION, FAN_GROUP }

const ROOM_ENVIRONMENT: PackedScene = preload("res://ui/rest/rest_room_environment.tscn")

var _step: Step = Step.STREAMER
var _run_data: SaveData
var _confirmation_state := IdentityConfirmationState.new()
var _selected_option: IdentityOption
var _busy := false
var _completed := false
var _player_presentation_is_completed := false
var _room_transition_is_completed := false
var _streamer_page: Control
var _player_presentation_page: Control
var _room_transition_page: Control
var _room_environment: Control
var _fan_page: Control
var _streamer_name_input: LineEdit
var _fan_group_name_input: LineEdit
var _streamer_continue: Button
var _confirm_button: Button
var _fan_back: Button
var _identity_back: Button
var _player_presentation_status: Label
var _room_transition_status: Label
var _room_transition_action: Button
var _status_label: Label
var _room_music: RoomMusicPresenter

@onready var _selection: Control = $IdentitySelection


# 所有步骤由同一场景持有，回退仅切换页面并保留名称、卡片与身份选择。
func _ready() -> void:
	_room_music = RoomMusicPresenter.new()
	add_child(_room_music)
	opening_saved.connect(_on_opening_saved)
	_run_data = SaveManager.data
	_identity_back = $IdentitySelection.get_node("%BackButton")
	_identity_back.show()
	_identity_back.text = "返回主播介绍"
	$IdentitySelection.get_node("Margins/Content/Title").text = "选择你的身份"
	$IdentitySelection.get_node("%NextButton").text = "确认身份"
	_identity_back.pressed.connect(_back_to_player_presentation)
	_selection.next_requested.connect(_advance_identity)
	_selection.selection_changed.connect(func(option: IdentityOption): _selected_option = option)

	_streamer_page = _build_name_page("StreamerPage", "我的名字是……")
	_streamer_name_input = _streamer_page.get_node("Center/Panel/Content/NameInput")
	_streamer_continue = _streamer_page.get_node("Center/Panel/Content/Continue")
	_streamer_continue.text = "确认名字"
	_streamer_continue.pressed.connect(_advance_streamer)
	_streamer_name_input.text_submitted.connect(func(_value: String): _advance_streamer())

	_player_presentation_page = _build_message_page(
		"PlayerPresentationPage",
		"认识新主播",
		"",
		"继续选择身份",
		"返回修改名字"
	)
	_player_presentation_status = _player_presentation_page.get_node("Center/Panel/Content/Status")
	_player_presentation_status.theme_type_variation = &"StreamerNameLabel"
	_player_presentation_page.get_node("Center/Panel/Content/Action").pressed.connect(complete_player_presentation)
	_player_presentation_page.get_node("Center/Panel/Content/Back").pressed.connect(_back_to_streamer)

	_room_transition_page = _build_message_page(
		"RoomComputerTransitionPage",
		"回到房间",
		"",
		"继续粉丝团命名",
		"返回身份选择"
	)
	# 身份确认后复用正式房间背景与桌面，衔接粉丝团命名步骤。
	_room_environment = ROOM_ENVIRONMENT.instantiate()
	_room_transition_page.add_child(_room_environment)
	_room_transition_page.move_child(_room_environment, 0)
	_room_transition_page.get_child(1).queue_free()
	_room_transition_status = _room_transition_page.get_node("Center/Panel/Content/Status")
	_room_transition_action = _room_transition_page.get_node("Center/Panel/Content/Action")
	_room_transition_action.pressed.connect(complete_room_computer_transition)
	_room_transition_page.get_node("Center/Panel/Content/Back").pressed.connect(_back_to_identity)

	_fan_page = _build_name_page("FanGroupPage", "我想让支持我的人们叫……")
	_fan_group_name_input = _fan_page.get_node("Center/Panel/Content/NameInput")
	_confirm_button = _fan_page.get_node("Center/Panel/Content/Continue")
	_confirm_button.text = "确认并保存"
	_confirm_button.pressed.connect(_confirm_opening)
	_fan_group_name_input.text_submitted.connect(func(_value: String): _confirm_opening())
	_fan_back = _fan_page.get_node("Center/Panel/Content/Back")
	_fan_back.text = "返回房间转场"
	_fan_back.show()
	_fan_back.pressed.connect(_back_to_room_transition)
	_status_label = _fan_page.get_node("Center/Panel/Content/Status")
	_bind_selection_audio(self)

	if _run_data != null:
		_streamer_name_input.text = _run_data.streamer_name
		_fan_group_name_input.text = _run_data.fan_group_name
		if not _run_data.identity_id.is_empty():
			_restore_confirmed_run()
			return
	_show_step(Step.STREAMER)
	if _run_data == null:
		_streamer_page.get_node("Center/Panel/Content/Status").text = "请从主菜单开始新周目。"
		_streamer_continue.disabled = true


# 身份流程的静态卡片与动态按钮共用选定声。
func _bind_selection_audio(root: Node) -> void:
	# 等动态页面构建完成后统一绑定，所有步骤复用同一轻气泡反馈。
	if root is BaseButton:
		AudioManager.bind_ui_selection(root)
	for child: Node in root.get_children():
		_bind_selection_audio(child)


# 构建仅由现有主题与控件组成的演出占位页，未来美术可替换显示层。
func _build_message_page(node_name: String, title_text: String, status_text: String, action_text: String, back_text: String) -> Control:
	var page := Control.new()
	page.name = node_name
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var background := preload("res://ui/theme/paper_background.tscn").instantiate()
	page.add_child(background)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(700, 0)
	# 全页已有空白卡纸面，内容区只保留留白，不再盖深色占位框。
	var paper := StyleBoxEmpty.new()
	paper.content_margin_left = 32
	paper.content_margin_right = 32
	paper.content_margin_top = 28
	paper.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", paper)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.theme_type_variation = &"TitleLabel"
	content.add_child(title)
	var status := Label.new()
	status.name = "Status"
	status.text = status_text
	status.custom_minimum_size.y = 96
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(status)
	var action := Button.new()
	action.name = "Action"
	action.text = action_text
	action.custom_minimum_size.y = 64
	content.add_child(action)
	var back := Button.new()
	back.name = "Back"
	back.text = back_text
	back.custom_minimum_size.y = 56
	content.add_child(back)
	return page


# 名称输入沿用统一主题，主播名和粉丝团名都只在各自页面暂存。
func _build_name_page(node_name: String, title_text: String) -> Control:
	var page := Control.new()
	page.name = node_name
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var background := preload("res://ui/theme/paper_background.tscn").instantiate()
	page.add_child(background)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(560, 0)
	# 全页已有空白卡纸面，内容区只保留留白，不再盖深色占位框。
	var paper := StyleBoxEmpty.new()
	paper.content_margin_left = 32
	paper.content_margin_right = 32
	paper.content_margin_top = 28
	paper.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", paper)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"TitleLabel"
	content.add_child(title)
	var input := LineEdit.new()
	input.name = "NameInput"
	input.theme_type_variation = &"StreamerNameInput"
	input.custom_minimum_size.y = 58
	input.placeholder_text = "留空使用默认名称"
	content.add_child(input)
	var status := Label.new()
	status.name = "Status"
	status.text = "空白名称沿用默认值。"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	var next := Button.new()
	next.name = "Continue"
	next.text = "继续"
	next.custom_minimum_size.y = 64
	content.add_child(next)
	var back := Button.new()
	back.name = "Back"
	back.text = "返回身份选择"
	back.hide()
	content.add_child(back)
	return page


# 每个步骤切换只隐藏其他视图，保留名称、身份卡翻开状态和当前选择。
func _show_step(step: Step) -> void:
	# 当前确认输入只属于旧步骤，不能继续传到新显示的身份卡。
	get_viewport().set_input_as_handled()
	_step = step
	# 身份确认后的房间与命名共用休息曲；回退离开房间时只淡出自己持有的音乐。
	if step in [Step.ROOM_TRANSITION, Step.FAN_GROUP] and _run_data != null and _selected_option != null:
		_room_music.start(_run_data.next_normal_level_order > 1)
	else:
		_room_music.stop()
	_streamer_page.visible = step == Step.STREAMER
	_player_presentation_page.visible = step == Step.PLAYER_PRESENTATION
	_selection.visible = step == Step.IDENTITY
	_room_transition_page.visible = step == Step.ROOM_TRANSITION
	_fan_page.visible = step == Step.FAN_GROUP
	match step:
		Step.STREAMER:
			AudioManager.focus_ui_silently(_streamer_name_input)
		Step.PLAYER_PRESENTATION:
			AudioManager.focus_ui_silently(_player_presentation_page.get_node("Center/Panel/Content/Action"))
		Step.IDENTITY:
			_selection.restore_selection(_selected_option.identity_id if _selected_option != null else &"")
			_selection.focus_selection()
		Step.ROOM_TRANSITION:
			_room_transition_action.text = "继续粉丝团命名"
			AudioManager.focus_ui_silently(_room_transition_action)
			# 复用房间已有背景做淡入，作为身份确认后的自然过渡。
			_room_environment.modulate.a = 0.0
			create_tween().tween_property(_room_environment, "modulate:a", 1.0, 0.45)
		Step.FAN_GROUP:
			AudioManager.focus_ui_silently(_fan_group_name_input)


# 主播名只暂存于输入控件；确认后请求姓名展示，再由玩家继续。
func _advance_streamer() -> void:
	if _step != Step.STREAMER or _busy or _run_data == null:
		return
	_streamer_name_input.text = IdentityNameRules.confirm_streamer_name(_streamer_name_input.text)
	AudioManager.play_event(&"ui_name_confirm")
	_player_presentation_is_completed = false
	_player_presentation_status.text = "欢迎，%s。" % _streamer_name_input.text
	_show_step(Step.PLAYER_PRESENTATION)
	player_name_pawprint_presentation_requested.emit(_streamer_name_input.text)


# 玩家继续后发出姓名展示完成事实，并进入身份卡选择。
func complete_player_presentation() -> void:
	if _step != Step.PLAYER_PRESENTATION or _busy or _player_presentation_is_completed:
		return
	_player_presentation_is_completed = true
	player_name_pawprint_presentation_completed.emit(_streamer_name_input.text)
	# 正式动机漫画尚未交付时直接进入正式身份卡选择，不展示虚构分镜。
	_show_step(Step.IDENTITY)


# 身份页下一步确认当前选项，随后展示真实房间环境。
func _advance_identity(option: IdentityOption) -> void:
	if _step != Step.IDENTITY or _busy or not IdentityOptions.CARDS.has(option):
		return
	_selected_option = option
	_room_transition_is_completed = false
	AudioManager.play_event(&"ui_identity_confirm")
	_room_transition_status.text = "身份已选定：%s" % option.display_name
	_room_transition_action.text = "继续粉丝团命名"
	_show_step(Step.ROOM_TRANSITION)
	room_computer_transition_requested.emit(option.identity_id)


# 玩家继续后发出房间转场完成事实并打开粉丝团命名页。
func complete_room_computer_transition() -> void:
	if _step != Step.ROOM_TRANSITION or _busy:
		return
	if _room_transition_is_completed:
		_show_step(Step.FAN_GROUP)
		return
	_room_transition_is_completed = true
	room_computer_transition_completed.emit()
	_show_step(Step.FAN_GROUP)


# 从主播介绍返回姓名输入后，再次确认会显示更新后的名称。
func _back_to_streamer() -> void:
	if _step == Step.PLAYER_PRESENTATION and not _busy:
		_show_step(Step.STREAMER)


# 身份页返回主播介绍；身份卡翻开状态由同一页面实例保留。
func _back_to_player_presentation() -> void:
	if _step == Step.IDENTITY and not _busy:
		_player_presentation_is_completed = false
		_player_presentation_status.text = "欢迎，%s。" % _streamer_name_input.text
		_show_step(Step.PLAYER_PRESENTATION)


# 房间转场未完成时返回身份页；重新确认后会再次发送转场请求。
func _back_to_identity() -> void:
	if _step == Step.ROOM_TRANSITION and not _busy:
		_show_step(Step.IDENTITY)


# 从粉丝团名返回已展示的房间环境，不重复触发演出请求。
func _back_to_room_transition() -> void:
	if _step == Step.FAN_GROUP and not _busy and not _confirmation_state.has_confirmed_identity():
		_show_step(Step.ROOM_TRANSITION)


# 已存周目恢复锁定记录；旧 ID 原样保留，未知 ID 禁止重新确认。
func _restore_confirmed_run() -> void:
	_selected_option = IdentityOptions.find_option(_run_data.identity_id)
	_show_step(Step.FAN_GROUP)
	_lock_inputs()
	if _selected_option == null:
		_status_label.text = "已保存身份无法识别，请保留存档并检查配置。"
		_confirm_button.disabled = true
		return
	_confirmation_state.confirm_identity(_run_data.identity_id, [_run_data.identity_id])
	_status_label.text = "本周目身份已锁定；可重试保存并交接开局房间。"
	_confirm_button.grab_focus()


# 唯一最终提交入口；忙碌和完成标记在外部调用前设置，防止同步重入。
func _confirm_opening() -> void:
	if _step != Step.FAN_GROUP or _busy:
		return
	# 保存已经成功时只重试房间路由，保持同一周目及已锁定身份。
	if _completed:
		_on_opening_saved(_run_data)
		return
	if _run_data == null or SaveManager.data != _run_data:
		_status_label.text = "当前周目已变化，请从主菜单重新开始。"
		return
	_busy = true
	if not _confirmation_state.has_confirmed_identity():
		var error := SaveManager.confirm_opening_identity(
			_streamer_name_input.text, _selected_option, _fan_group_name_input.text, _confirmation_state)
		if error != OK:
			_status_label.text = "身份提交失败：%s。可重试。" % error_string(error)
			_busy = false
			return
		_streamer_name_input.text = _run_data.streamer_name
		_fan_group_name_input.text = _run_data.fan_group_name
		_lock_inputs()
	if _run_data.identity_id != _confirmation_state.get_confirmed_identity_id():
		_status_label.text = "当前存档与已确认身份不一致，请保留数据并检查。"
		_busy = false
		return
	var save_error := SaveManager.save_game()
	_busy = false
	if save_error != OK:
		_status_label.text = "身份已锁定，存档失败：%s。点击重试保存。" % error_string(save_error)
		_confirm_button.text = "重试保存"
		_confirm_button.grab_focus()
		return
	_completed = true
	_confirm_button.text = "已保存"
	_confirm_button.disabled = true
	_status_label.text = "身份已保存，正在进入房间。"
	opening_saved.emit(_run_data)


# 接收保存事实后请求顶层切换；失败时允许重试，成功期间拒绝重复请求。
func _on_opening_saved(run_data: SaveData) -> void:
	if _busy:
		return
	if run_data == null or SaveManager.data != run_data:
		_status_label.text = "当前周目已变化，请从主菜单重新开始。"
		_confirm_button.disabled = true
		return
	_busy = true
	_confirm_button.disabled = true
	var error := SceneRouter.goto_opening_room()
	if error != OK:
		_busy = false
		_status_label.text = "进入房间失败：%s。已保存身份保持，可重试。" % error_string(error)
		_confirm_button.text = "重试进入房间"
		_confirm_button.disabled = false
		_confirm_button.grab_focus()


# 名称和身份只在正式提交后锁定，保存重试沿用同一周目对象。
func _lock_inputs() -> void:
	_streamer_name_input.editable = false
	_fan_group_name_input.editable = false
	_fan_back.disabled = true
	_identity_back.disabled = true
	_selection.restore_selection(_run_data.identity_id, true)
