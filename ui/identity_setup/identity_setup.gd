extends Control

# 保存成功的事实通知；RS-12 接收后通过 SceneRouter 打开真正的开局房间。
signal opening_saved(run_data: SaveData)

enum Step { STREAMER, IDENTITY, FAN_GROUP }

var _step: Step = Step.STREAMER
var _run_data: SaveData
var _confirmation_state := IdentityConfirmationState.new()
var _selected_option: IdentityOption
var _busy := false
var _completed := false
var _streamer_page: Control
var _fan_page: Control
var _streamer_name_input: LineEdit
var _fan_group_name_input: LineEdit
var _streamer_continue: Button
var _confirm_button: Button
var _fan_back: Button
var _status_label: Label

@onready var _selection: Control = $IdentitySelection
@onready var _identity_back: Button = $IdentitySelection.get_node("%BackButton")

# 三页共享一个流程持有者，中间步骤只保存控件内的临时值。
func _ready() -> void:
	_run_data = SaveManager.data
	_identity_back.show()
	_streamer_page = _build_name_page("StreamerPage", "① 你叫什么？")
	_streamer_name_input = _streamer_page.get_node("Center/Panel/Content/NameInput")
	_streamer_continue = _streamer_page.get_node("Center/Panel/Content/Continue")
	_streamer_continue.pressed.connect(_advance_streamer)
	_streamer_name_input.text_submitted.connect(func(_value: String): _advance_streamer())
	_fan_page = _build_name_page("FanGroupPage", "③ 粉丝团叫什么？")
	_fan_group_name_input = _fan_page.get_node("Center/Panel/Content/NameInput")
	_confirm_button = _fan_page.get_node("Center/Panel/Content/Continue")
	_confirm_button.text = "确认并保存"
	_confirm_button.pressed.connect(_confirm_opening)
	_fan_group_name_input.text_submitted.connect(func(_value: String): _confirm_opening())
	_fan_back = _fan_page.get_node("Center/Panel/Content/Back")
	_fan_back.show()
	_fan_back.pressed.connect(_back_to_identity)
	_status_label = _fan_page.get_node("Center/Panel/Content/Status")
	_identity_back.pressed.connect(_back_to_streamer)
	_selection.next_requested.connect(_advance_identity)
	_selection.selection_changed.connect(func(option: IdentityOption): _selected_option = option)
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

# 旧纸色面板和统一主题构成名称页；仅显示当前步骤的一个输入框。
func _build_name_page(node_name: String, title_text: String) -> Control:
	var page := Control.new()
	page.name = node_name
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var background := ColorRect.new()
	background.color = Color("191611")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(background)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(560, 0)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("453b2c")
	paper.border_color = Color("bba477")
	paper.set_border_width_all(2)
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

# 控件持续存在，回退保留临时输入与选择；正式数据只在第三步提交。
func _show_step(step: Step) -> void:
	_step = step
	_streamer_page.visible = step == Step.STREAMER
	_selection.visible = step == Step.IDENTITY
	_fan_page.visible = step == Step.FAN_GROUP
	match step:
		Step.STREAMER:
			_streamer_name_input.grab_focus()
		Step.IDENTITY:
			_selection.restore_selection(_selected_option.identity_id if _selected_option != null else &"")
			_selection.focus_selection()
		Step.FAN_GROUP:
			_fan_group_name_input.grab_focus()

# 第一步前进不会写入存档，重复信号必须仍处于本步骤才生效。
func _advance_streamer() -> void:
	if _step != Step.STREAMER or _busy or _run_data == null:
		return
	_streamer_name_input.text = IdentityNameRules.confirm_streamer_name(_streamer_name_input.text)
	_show_step(Step.IDENTITY)

# 复用 ID-08 给出的正式 Resource，第三页可回看已确认的主播名与身份。
func _advance_identity(option: IdentityOption) -> void:
	if _step != Step.IDENTITY or _busy or not IdentityOptions.CARDS.has(option):
		return
	_selected_option = option
	_status_label.text = "%s · %s" % [IdentityNameRules.confirm_streamer_name(_streamer_name_input.text), option.display_name]
	_show_step(Step.FAN_GROUP)

# 回到主播名步骤时保留卡片选择及粉丝团原始输入。
func _back_to_streamer() -> void:
	if _step == Step.IDENTITY and not _busy:
		_show_step(Step.STREAMER)

# 正式提交后关闭回退，存档失败只重试保存。
func _back_to_identity() -> void:
	if _step == Step.FAN_GROUP and not _busy and not _confirmation_state.has_confirmed_identity():
		_show_step(Step.IDENTITY)

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
	if _step != Step.FAN_GROUP or _busy or _completed:
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
	_status_label.text = "身份已保存。开局房间尚未接入（RS-12），当前流程停在此处。"
	opening_saved.emit(_run_data)

# 名称与身份只在正式提交后锁定，重试保存沿用同一周目对象。
func _lock_inputs() -> void:
	_streamer_name_input.editable = false
	_fan_group_name_input.editable = false
	_fan_back.disabled = true
	_identity_back.disabled = true
	_selection.restore_selection(_run_data.identity_id, true)
