extends Control

const IDENTITY_OPTIONS: Array[IdentityOption] = [
	preload("res://data/identity/identity_orthodox_placeholder.tres"),
	preload("res://data/identity/identity_heretical_placeholder.tres"),
	preload("res://data/identity/identity_absurd_placeholder.tres"),
]

var _confirmation_state: IdentityConfirmationState = IdentityConfirmationState.new()
var _selected_option: IdentityOption = null
var _option_buttons: Array[Button] = []

@onready var _streamer_name_input: LineEdit = %StreamerNameInput
@onready var _identity_options_container: HBoxContainer = %IdentityOptions
@onready var _status_label: Label = %StatusLabel
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	# 页面只设置和提交本周目身份，不负责创建新周目或切换场景。
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	_build_identity_options()
	_restore_saved_identity()
	if not _confirmation_state.has_confirmed_identity():
		_streamer_name_input.grab_focus()


# 从三份身份 Resource 创建可键盘聚焦、鼠标可点选的选项卡。
func _build_identity_options() -> void:
	for option in IDENTITY_OPTIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(330.0, 220.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"SecondaryButton"
		button.toggle_mode = true
		button.icon = option.icon
		button.text = _build_option_text(option)
		button.pressed.connect(_on_identity_option_pressed.bind(option, button))
		_identity_options_container.add_child(button)
		_option_buttons.append(button)


# 正式图标尚未提供时，以倾向字标占位；有图标后 Button 会显示 Resource 中的图像。
func _build_option_text(option: IdentityOption) -> String:
	var marker := _get_tendency_marker(option.tendency_id)
	var tendency_name := _get_tendency_name(option.tendency_id)
	if option.icon != null:
		marker = ""
	return "%s\n%s\n倾向：%s" % [marker, option.display_name, tendency_name]


# 将资源中的稳定倾向 ID 转为玩家可读的名称。
func _get_tendency_name(tendency_id: String) -> String:
	match tendency_id:
		"orthodox":
			return "正统"
		"heretical":
			return "异端"
		"absurd":
			return "荒谬"
		_:
			return tendency_id


# 无图标时用倾向字标占位，后续正式图标由 IdentityOption Resource 替换。
func _get_tendency_marker(tendency_id: String) -> String:
	match tendency_id:
		"orthodox":
			return "正"
		"heretical":
			return "异"
		"absurd":
			return "谬"
		_:
			return "选"


# 切换可见选中态；最终是否允许确认仍由身份状态对象裁决。
func _on_identity_option_pressed(option: IdentityOption, clicked_button: Button) -> void:
	if _confirmation_state.has_confirmed_identity():
		return
	_selected_option = option
	for button in _option_buttons:
		button.button_pressed = button == clicked_button
	_status_label.text = "已选择：%s。确认后本周目内固定。" % option.display_name


# 如果本周目已有身份 ID，重开页面时恢复同一身份并锁住修改控件。
func _restore_saved_identity() -> void:
	if SaveManager.data == null:
		_status_label.text = "当前还没有新周目数据；主菜单接线完成后即可开始设置。"
		return

	_streamer_name_input.text = SaveManager.data.streamer_name
	var saved_identity_id: StringName = SaveManager.data.identity_id
	if saved_identity_id.is_empty():
		_status_label.text = "输入主播名并选择身份后确认。空白名字会使用默认名“新主播”。"
		return

	var identity_ids := _get_identity_ids()
	if not _confirmation_state.confirm_identity(saved_identity_id, identity_ids):
		_status_label.text = "存档身份 ID 不在当前选项数据中；为保留本周目记录，页面已锁定。"
		_lock_confirmed_controls()
		return

	for index in range(IDENTITY_OPTIONS.size()):
		var option: IdentityOption = IDENTITY_OPTIONS[index]
		if option.identity_id == saved_identity_id:
			_selected_option = option
			_option_buttons[index].button_pressed = true
			break
	_status_label.text = "本周目身份已确认：%s。点击下方按钮继续。" % _selected_option.display_name
	_lock_identity_controls()


# 从身份资源取得当前允许使用的稳定 ID 列表，避免 UI 自己维护第二份 ID 配置。
func _get_identity_ids() -> Array[StringName]:
	var identity_ids: Array[StringName] = []
	for option in IDENTITY_OPTIONS:
		identity_ids.append(option.identity_id)
	return identity_ids


# 确认名字、锁定身份并写入当前 SaveData；场景切换留给 ID-06。
func _on_confirm_button_pressed() -> void:
	if SaveManager.data == null:
		_status_label.text = "当前没有新周目数据，请从主菜单开始新周目。"
		return
	if not _confirmation_state.has_confirmed_identity():
		if _selected_option == null:
			_status_label.text = "请先选择一个身份。"
			return

		var streamer_name: String = IdentityNameRules.confirm_streamer_name(_streamer_name_input.text)
		if not _confirmation_state.confirm_identity(_selected_option.identity_id, _get_identity_ids()):
			_status_label.text = "身份确认失败；请检查身份选项数据。"
			return

		var identity_error: Error = SaveManager.set_identity_data(
			streamer_name,
			_confirmation_state.get_confirmed_identity_id()
		)
		if identity_error != OK:
			_status_label.text = "身份数据未能写入当前周目。"
			return

		_streamer_name_input.text = streamer_name
		_status_label.text = "已确认：%s · %s。正在保存。" % [streamer_name, _selected_option.display_name]
		_lock_identity_controls()
	elif SaveManager.data.identity_id != _confirmation_state.get_confirmed_identity_id():
		_status_label.text = "当前周目数据与已确认身份不一致，无法继续。"
		return

	var save_error: Error = SaveManager.save_game()
	if save_error != OK:
		_status_label.text = "身份已确认，但存档失败。再次点击可重试。"
		return

	var scene_error: Error = SceneRouter.goto_game()
	if scene_error != OK:
		_status_label.text = "身份已保存，但无法进入 Game。再次点击可重试。"
		return


# 首次确认后允许重试保存或进入 Game，只锁定主播名和身份选项。
func _lock_identity_controls() -> void:
	_streamer_name_input.editable = false
	for button in _option_buttons:
		button.disabled = true


# 身份已写入当前周目后锁住输入和选项，避免页面显示与存档分离。
func _lock_confirmed_controls() -> void:
	_lock_identity_controls()
	_confirm_button.disabled = true
