## 显示单条弹幕，并按自己的截止时间和所属区域管理自然结束。
class_name BarrageView
extends Label

var runtime_record: BarrageRuntimeRecord
var _move_speed_pixels_per_second: float = 0.0
var _active_area: Control

## 绑定本次弹幕的运行记录、移动速度和实际所属区域。
func setup(barrage_record: BarrageRuntimeRecord, move_speed_pixels_per_second: float, active_area: Control) -> void:
	runtime_record = barrage_record
	text = barrage_record.text
	_move_speed_pixels_per_second = move_speed_pixels_per_second
	_active_area = active_area

## 到期或整个视图离开所属区域时释放节点，tree_exited 会归还普通容量。
func _process(delta: float) -> void:
	if runtime_record == null:
		return
	if Time.get_ticks_msec() >= runtime_record.expires_at_msec:
		queue_free()
		return

	position.x -= _move_speed_pixels_per_second * delta
	if not is_instance_valid(_active_area):
		queue_free()
		return
	var active_rect: Rect2 = Rect2(Vector2.ZERO, _active_area.size)
	if not active_rect.intersects(Rect2(position, size)):
		queue_free()
