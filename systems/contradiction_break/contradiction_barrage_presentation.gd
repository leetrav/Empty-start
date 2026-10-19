## CB-17 的弹幕与准星视觉组合；真假事实由宿主持有，本组件只接收候选并呈现。
class_name ContradictionBarragePresentation
extends Control

signal aimed_view_changed(view_instance_id: int)

const CANDIDATE_COUNT: int = 6
const AIM_FEEDBACK_SCALE: float = 1.06
const AIM_FEEDBACK_SECONDS: float = 0.16

@onready var _barrage_area: BarrageArea = $BarrageArea
@onready var _aim_reticle: AimReticle = $AimReticle

var _slot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visible_views: Array[BarrageView] = []
var _aimed_instance_id: int = 0


func _ready() -> void:
	_slot_rng.randomize()
	set_process(false)


## 显示一条真句与五条假句；只把整组视图放进六个现有槽位，不传递真假标签。
func present_candidates(
	level_profile: LevelProfile,
	true_lines: Array[LevelContradiction],
	false_lines: Array[LevelContradiction],
	window_config: ContradictionWindowConfig
) -> bool:
	clear_presentation()
	if level_profile == null or window_config == null:
		return false
	if not _barrage_area.start_contradiction_generation(level_profile, true_lines, false_lines, window_config):
		return false
	_visible_views = _collect_visible_views()
	if _visible_views.size() != CANDIDATE_COUNT:
		clear_presentation()
		return false
	for view: BarrageView in _visible_views:
		if view.runtime_record == null or not view.runtime_record.is_contradiction:
			clear_presentation()
			return false
	# 固定六个行槽的集合保持不变；每局打乱句子与槽位的对应关系，消除首条候选占首行的顺序提示。
	_shuffle_visual_slots()
	_aimed_instance_id = 0
	set_process(true)
	return true


## 清理独立演示或宿主重开时的视图与视觉焦点。
func clear_presentation() -> void:
	_aimed_instance_id = 0
	set_process(false)
	if is_instance_valid(_barrage_area):
		_barrage_area.clear_barrages()
	_visible_views.clear()


## 返回按屏幕视觉位置排序的候选副本，调用方看不到真假分类顺序。
func get_visible_views() -> Array[BarrageView]:
	var sorted_views: Array[BarrageView] = _collect_visible_views()
	for index: int in range(1, sorted_views.size()):
		var candidate: BarrageView = sorted_views[index]
		var insert_at: int = index
		while insert_at > 0 and _is_above_or_left(candidate, sorted_views[insert_at - 1]):
			sorted_views[insert_at] = sorted_views[insert_at - 1]
			insert_at -= 1
		sorted_views[insert_at] = candidate
	return sorted_views


## 暴露既有准星节点，供后续宿主输入接线或独立演示使用。
func get_aim_reticle() -> AimReticle:
	return _aim_reticle


func _process(_delta: float) -> void:
	var aimed_view: BarrageView = _find_aimed_view()
	var next_instance_id: int = aimed_view.get_instance_id() if aimed_view != null else 0
	if next_instance_id == _aimed_instance_id:
		return
	_aimed_instance_id = next_instance_id
	if aimed_view != null:
		# 所有目标使用同一个轻微缩放反馈；命中矩形继续读取 BarrageView 的实际变换。
		aimed_view.pulse_presentation(AIM_FEEDBACK_SCALE, AIM_FEEDBACK_SECONDS)
	aimed_view_changed.emit(_aimed_instance_id)


func _collect_visible_views() -> Array[BarrageView]:
	var result: Array[BarrageView] = []
	if not is_instance_valid(_barrage_area):
		return result
	for child: Node in _barrage_area.get_children():
		var view := child as BarrageView
		if view == null or view.is_queued_for_deletion() or view.runtime_record == null:
			continue
		if view.runtime_record.is_contradiction:
			result.append(view)
	return result


## 用独立 RNG 打乱固定落点，不触碰候选 Resource、运行记录或战斗判定。
func _shuffle_visual_slots() -> void:
	var slots: Array[Vector2] = []
	for view: BarrageView in _visible_views:
		slots.append(view.position)
	for index: int in range(slots.size() - 1, 0, -1):
		var swap_index: int = _slot_rng.randi_range(0, index)
		var previous_slot: Vector2 = slots[index]
		slots[index] = slots[swap_index]
		slots[swap_index] = previous_slot
	for index: int in _visible_views.size():
		_visible_views[index].position = slots[index]


## 只按准星圆与真实视图矩形筛选；重叠时选择几何中心最近者，真假 ID 不参与。
func _find_aimed_view() -> BarrageView:
	var aim_center: Vector2 = _aim_reticle.get_aim_center_global_position()
	var best_view: BarrageView
	var best_distance_squared: float = INF
	for view: BarrageView in _collect_visible_views():
		var target_rect: Rect2 = view.get_global_rect()
		if not _aim_reticle.intersects_target_area(target_rect):
			continue
		var distance_squared: float = target_rect.get_center().distance_squared_to(aim_center)
		if (distance_squared < best_distance_squared - 0.01
				or (is_equal_approx(distance_squared, best_distance_squared)
					and best_view != null and _is_above_or_left(view, best_view))):
			best_view = view
			best_distance_squared = distance_squared
	return best_view


## 用画面位置打破等距反馈平局，不读取候选生成次序。
func _is_above_or_left(first_view: BarrageView, second_view: BarrageView) -> bool:
	if not is_equal_approx(first_view.position.y, second_view.position.y):
		return first_view.position.y < second_view.position.y
	return first_view.position.x < second_view.position.x
