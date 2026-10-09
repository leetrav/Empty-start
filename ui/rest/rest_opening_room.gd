extends Control

var _run_data: SaveData
var _starting := false

@onready var _environment: RestRoomEnvironment = $RoomEnvironment
@onready var _names: Label = %Names
@onready var _status: Label = %Status
@onready var _start_button: Button = %StartLiveButton

# 独立开局页面只读取已确认资料；没有 RestSession、关卡或战斗输入节点。
func _ready() -> void:
	_run_data = SaveManager.data
	_start_button.pressed.connect(start_live)
	if _run_data == null or _run_data.identity_id.is_empty() or _run_data.tendency_state == null:
		_status.text = "开局资料暂不可用，请从主菜单完成身份确认。"
		_start_button.disabled = true
		_environment.apply_tendency("")
		return
	_names.text = "主播：%s\n粉丝团：%s" % [_run_data.streamer_name, _run_data.fan_group_name]
	_environment.apply_tendency(_run_data.tendency_state.get_primary_tendency_id())
	_start_button.grab_focus()

# 请求成功后直到页面退出都保持锁定，同帧连点和直接重复调用只启动一次。
func start_live() -> Error:
	if _starting:
		return ERR_ALREADY_IN_USE
	if _run_data == null or SaveManager.data != _run_data or _run_data.identity_id.is_empty() or _run_data.tendency_state == null:
		_status.text = "当前周目已变化，请从主菜单重新开始。"
		_start_button.disabled = true
		return ERR_UNCONFIGURED
	_starting = true
	_start_button.disabled = true
	_status.text = "正在开始直播……"
	var error := SceneRouter.goto_game()
	if error != OK:
		_starting = false
		_status.text = "开始直播失败：%s。可重试。" % error_string(error)
		_start_button.disabled = false
		_start_button.grab_focus()
	return error
