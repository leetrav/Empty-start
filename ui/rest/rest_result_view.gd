class_name RestResultView
extends CanvasLayer

signal continue_requested
signal stop_streaming_requested
signal result_performance_finished

var _result_active: bool = false
var _menu_input_enabled: bool = false
var _route_choice_dispatched: bool = false
var _base_result_description: String = ""
var _presentation_id: int = 0
var _battle_aim: AimReticle
var _aim_input_was_enabled: bool = false
var _aim_suspended: bool = false
var _room_music: RoomMusicPresenter

@onready var _overlay: Control = %Overlay
@onready var _room_environment: RestRoomEnvironment = %RoomEnvironment
@onready var _result_title: Label = %ResultTitle
@onready var _result_description: Label = %ResultDescription
@onready var _live_result: Label = %LiveResult
@onready var _continue_button: Button = %ContinueButton
@onready var _stop_streaming_button: Button = %StopStreamingButton


# 隐藏结果面板并连接 Continue / Stop 请求。
func _ready() -> void:
	_room_music = RoomMusicPresenter.new()
	add_child(_room_music)
	_overlay.hide()
	_continue_button.pressed.connect(_on_continue_pressed)
	_stop_streaming_button.pressed.connect(_on_stop_streaming_pressed)
	_set_menu_input_enabled(false)


# 场景离树时只取消待完成展示；子控件已离树，不能再访问 Viewport 或抢焦点。
func _exit_tree() -> void:
	_result_active = false
	_presentation_id += 1


# 保留未击破专用入口；没有周目数据时只显示本场说明。
func show_unbroken_result(session: RestSession) -> bool:
	if session == null or not session.is_open():
		return false
	var result_snapshot: Dictionary = session.get_result_snapshot()
	if String(result_snapshot.get("result_kind", "")) != "pk_win_unbroken":
		return false
	return show_result(session)


# 每次打开只冻结并显示本场结果；显示页面不负责提交奖励或推进关卡。
func show_result(
		session: RestSession,
		run_data: SaveData = null,
		wait_for_performance: bool = false
	) -> bool:
	if session == null or not session.is_open():
		return false
	_route_choice_dispatched = false
	var result_kind: String = String(session.get_result_snapshot().get("result_kind", ""))
	if run_data == null and result_kind != "pk_win_unbroken":
		return false
	if result_kind == "pk_win_unbroken":
		_result_title.text = "PK 胜利 · 矛盾未击破"
		_result_description.text = "你赢下了本场 PK，但未能确认真正的矛盾。\n本场没有神谕或击败奖励，仍可继续后续流程。"
	else:
		_result_title.text = "本场直播结束"
		_result_description.text = "本场结果已保存。"
	_base_result_description = _result_description.text
	# 首次展示冻结真实数据；重复查看只读同一快照，粉丝提交仍归 PK 胜利入口。
	session.capture_live_result(run_data)
	_render_live_result(session.get_live_result_snapshot())
	# 环境只消费 17 已提交的主导倾向，不读取精确分数或本场暂存。
	var tendency_id: String = ""
	if run_data != null and run_data.tendency_state != null:
		tendency_id = run_data.tendency_state.get_primary_tendency_id()
	_room_environment.apply_tendency(tendency_id)
	_overlay.show()
	_result_active = true
	_room_music.start(true)
	_suspend_battle_aim()
	_presentation_id += 1
	_set_menu_input_enabled(false)
	# 当前为静态展示，布局完成后开放菜单；外部演出可显式报告结束。
	if not wait_for_performance:
		_finish_static_performance(_presentation_id)
	return true


# 缺失数据保持明确空态，零增量与未知增量分开显示。
func _render_live_result(result: Dictionary) -> void:
	if result.is_empty():
		_live_result.text = "本场直播数据暂不可用。"
		return
	var fan_delta: Variant = result["fan_delta"]
	var fan_change: String = "本场粉丝变化记录暂缺"
	if fan_delta != null:
		fan_change = "本场粉丝 +%d" % int(fan_delta)
	_live_result.text = "观看 %d · 点赞 %d · 评论 %d\n%s · 总粉丝 %d" % [
		int(result["viewer_count"]), int(result["like_count"]), int(result["comment_count"]),
		fan_change, int(result["fan_count"]),
	]


# 重开时收起结果面板并释放本次上下文。
func hide_result() -> void:
	_room_music.stop()
	_result_active = false
	_route_choice_dispatched = false
	_restore_battle_aim()
	_presentation_id += 1
	_set_menu_input_enabled(false)
	_overlay.hide()
	_room_environment.apply_tendency("")


# 共享暂停菜单由组合根转发，Rest 音乐沿用同一上下文。
func set_music_paused(paused: bool) -> void:
	_room_music.set_paused(paused)


# 继续流程由外层组合方决定；路由完成前保留结果提示。
func _on_continue_pressed() -> void:
	if not _claim_route_choice():
		return
	continue_requested.emit()


# 暂时下播沿用同一完成快照，只切换到房间路由。
func _on_stop_streaming_pressed() -> void:
	if not _claim_route_choice():
		return
	stop_streaming_requested.emit()


# 两个选项共享一个一次性边界，连点不会重复请求进度提交。
func _claim_route_choice() -> bool:
	if not _menu_input_enabled or _route_choice_dispatched:
		return false
	_route_choice_dispatched = true
	_result_description.text = _base_result_description
	_set_menu_input_enabled(false)
	return true


# 存档或路由失败时保留诊断信息，并重新开放选择供玩家重试。
func release_route_choice_for_retry(message: String) -> void:
	if not _result_active:
		return
	_route_choice_dispatched = false
	_result_description.text = "%s\n%s" % [_base_result_description, message]
	_set_menu_input_enabled(true)
	_continue_button.grab_focus()


# 等待静态展示布局完成；关闭或重开后旧等待不能解锁新页面。
func _finish_static_performance(presentation_id: int) -> void:
	await get_tree().process_frame
	if presentation_id == _presentation_id:
		finish_result_performance()


# 演出拥有者报告完成，仅开放 Rest 菜单，战斗启停继续归外层场景。
func finish_result_performance() -> void:
	if not _result_active or _menu_input_enabled:
		return
	_set_menu_input_enabled(true)
	_continue_button.grab_focus()
	result_performance_finished.emit()


# 菜单同时受展示阶段与资料上下文约束。
func _set_menu_input_enabled(enabled: bool) -> void:
	_menu_input_enabled = enabled
	_continue_button.disabled = not enabled
	_stop_streaming_button.disabled = not enabled
	if not enabled:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner != null:
			focus_owner.release_focus()


# 展示时拦截操作；菜单阶段让原生 GUI 完整接收点击、悬停与滚动。
func _input(event: InputEvent) -> void:
	# 转场期间屏蔽结果操作，但ESC始终交给共享暂停组件。
	if _result_active and not _menu_input_enabled and not event.is_action("pause"):
		get_viewport().set_input_as_handled()


# 外层注入准心，Rest 不依赖 Sandbox 内部节点路径；攻击仍由战斗所有者关闭。
func configure_battle_aim(aim: AimReticle) -> void:
	_restore_battle_aim()
	_battle_aim = aim
	if _result_active:
		_suspend_battle_aim()


# 进入休息时暂停准心事件，避免结果菜单期间继续攻击。
func _suspend_battle_aim() -> void:
	if not _aim_suspended and is_instance_valid(_battle_aim):
		_aim_input_was_enabled = _battle_aim.is_processing_input()
		_battle_aim.set_process_input(false)
		_aim_suspended = true


# 离开休息时恢复进入前的准心处理状态，攻击启停由外层独立决定。
func _restore_battle_aim() -> void:
	if _aim_suspended and is_instance_valid(_battle_aim):
		_battle_aim.set_process_input(_aim_input_was_enabled)
	_aim_suspended = false
