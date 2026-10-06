## 显示单条弹幕，并按自己的截止时间和所属区域管理自然结束。
class_name BarrageView
extends Label

var runtime_record: BarrageRuntimeRecord
var _move_speed_pixels_per_second: float = 0.0
var _active_area: Control
var _pause_started_msec: int = -1

## 绑定本次弹幕的运行记录、移动速度和实际所属区域。
func setup(barrage_record: BarrageRuntimeRecord, move_speed_pixels_per_second: float, active_area: Control) -> void:
	runtime_record = barrage_record
	text = barrage_record.text
	_move_speed_pixels_per_second = move_speed_pixels_per_second
	_active_area = active_area
	# 继续观察全局暂停状态，移动和寿命仍由本函数显式冻结。
	process_mode = Node.PROCESS_MODE_ALWAYS

## 暂停时记录起点；恢复后按暂停时长补偿截止时间。
func _update_pause_compensation(is_tree_paused: bool, current_time_msec: int) -> bool:
	if is_tree_paused:
		if _pause_started_msec < 0:
			_pause_started_msec = current_time_msec
		return true
	if _pause_started_msec >= 0:
		runtime_record.expires_at_msec += current_time_msec - _pause_started_msec
		_pause_started_msec = -1
	return false
## 暂停时跳过移动与移除；运行时到期或离开区域后释放节点。
func _process(delta: float) -> void:
	if runtime_record == null:
		return
	var current_time_msec: int = Time.get_ticks_msec()
	if _update_pause_compensation(get_tree().paused, current_time_msec):
		return
	if current_time_msec >= runtime_record.expires_at_msec:
		queue_free()
		return

	position.x -= _move_speed_pixels_per_second * delta
	if not is_instance_valid(_active_area):
		queue_free()
		return
	var active_rect: Rect2 = Rect2(Vector2.ZERO, _active_area.size)
	if not active_rect.intersects(Rect2(position, size)):
		queue_free()
