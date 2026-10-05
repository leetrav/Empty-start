## 显示并移动一条普通弹幕；记录数据由弹幕区域传入。
class_name BarrageView
extends Label

var runtime_record: BarrageRuntimeRecord
var _move_speed_pixels_per_second: float = 0.0

## 绑定本次弹幕运行时记录与当前关基础移动速度。
func setup(barrage_record: BarrageRuntimeRecord, move_speed_pixels_per_second: float) -> void:
	runtime_record = barrage_record
	text = barrage_record.text
	_move_speed_pixels_per_second = move_speed_pixels_per_second

func _process(delta: float) -> void:
	position.x -= _move_speed_pixels_per_second * delta
