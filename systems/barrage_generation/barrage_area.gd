## 当前弹幕区域只负责把一条已选普通话语实例化并放到可视区域。
class_name BarrageArea
extends Control

@export var barrage_view_scene: PackedScene

## 复制静态话语资料为运行时记录，再创建一条可移动的普通弹幕。
func spawn_normal_barrage(level_profile: LevelProfile, speech: LevelSpeech) -> BarrageView:
	if level_profile == null or speech == null:
		push_error("BarrageArea: 生成普通弹幕需要关卡配置和话语定义。")
		return null
	if barrage_view_scene == null:
		push_error("BarrageArea: 未配置弹幕表现 Scene。")
		return null

	var record: BarrageRuntimeRecord = BarrageRuntimeRecord.new()
	record.text = speech.text
	record.source_id = level_profile.streamer_id
	record.tendency_id = speech.tendency_id
	record.strength = 1.0
	record.original_sentence_id = speech.original_sentence_id

	var view: BarrageView = barrage_view_scene.instantiate() as BarrageView
	if view == null:
		push_error("BarrageArea: 弹幕表现 Scene 根节点需要 BarrageView。")
		return null
	view.setup(record, level_profile.base_move_speed_pixels_per_second)
	add_child(view)
	var start_x: float = size.x - view.size.x
	if start_x < 0.0:
		start_x = 0.0
	view.position = Vector2(start_x, maxf((size.y - view.size.y) * 0.5, 0.0))
	return view
