## CB-17 的弹幕与准星视觉组合；真假事实由宿主持有，本组件只接收候选并呈现。
class_name ContradictionBarragePresentation
extends Control

signal aimed_view_changed(view_instance_id: int)

const CANDIDATE_COUNT: int = 6
const AIM_FEEDBACK_SCALE: float = 1.06
const AIM_FEEDBACK_SECONDS: float = 0.16

var _barrage_area: BarrageArea
var _aim_reticle: AimReticle
var _slot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visible_views: Array[BarrageView] = []
var _aimed_instance_id: int = 0
var _presentation_active: bool = false


func _ready() -> void:
	_slot_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## 绑定正式流程已持有的区域与准星；本组件只观察视图生成和真实准星几何。
func bind_battle_nodes(barrage_area: BarrageArea, aim_reticle: AimReticle) -> bool:
	if barrage_area == null or aim_reticle == null:
		return false
	if is_instance_valid(_barrage_area) and _barrage_area.barrage_generated.is_connected(_on_barrage_generated):
		_barrage_area.barrage_generated.disconnect(_on_barrage_generated)
	_reset_visual_state()
	_barrage_area = barrage_area
	_aim_reticle = aim_reticle
	if not _barrage_area.barrage_generated.is_connected(_on_barrage_generated):
		_barrage_area.barrage_generated.connect(_on_barrage_generated)
	_try_activate_fixed_set()
	return true


## 显示一条真句与五条假句；只把整组视图放进六个现有槽位，不传递真假标签。
func present_candidates(
	level_profile: LevelProfile,
	true_lines: Array[LevelContradiction],
	false_lines: Array[LevelContradiction],
	window_config: ContradictionWindowConfig
) -> bool:
	_reset_visual_state()
	if not is_instance_valid(_barrage_area) or level_profile == null or window_config == null:
		return false
	if not _barrage_area.start_contradiction_generation(level_profile, true_lines, false_lines, window_config):
		return false
	return _try_activate_fixed_set()


## 清理本组件的视觉追踪；弹幕区域生命周期仍归 BarrageArea 与宿主所有。
func clear_presentation() -> void:
	_reset_visual_state()


## 返回按屏幕视觉位置排序的候选副本，调用方看不到真假分类顺序。
func get_visible_views() -> Array[BarrageView]:
	var sorted_views: Array[BarrageView] = _visible_views.duplicate()
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
	if not _presentation_active:
		return
	for view: BarrageView in _visible_views:
		if not is_instance_valid(view) or view.is_queued_for_deletion():
			_reset_visual_state()
			return
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
		if view.runtime_record.is_contradiction and not view.runtime_record.is_repeat:
			result.append(view)
	return result


## 一次 BarrageArea 生成通知后扫描固定集合；不逐帧遍历普通弹幕。
func _on_barrage_generated(view: BarrageView) -> void:
	if view == null or view.runtime_record == null:
		return
	if not view.runtime_record.is_contradiction or view.runtime_record.is_repeat:
		return
	if _presentation_active and _visible_views.has(view):
		return
	_reset_visual_state()
	_try_activate_fixed_set()


## 只在候选首次齐备时按统一行高排布；运行记录与攻击快照不变。
func _try_activate_fixed_set() -> bool:
	if _presentation_active and _visible_views.size() == CANDIDATE_COUNT:
		return true
	if not is_instance_valid(_barrage_area):
		return false
	var candidates: Array[BarrageView] = _collect_visible_views()
	if candidates.size() != CANDIDATE_COUNT:
		return false
	_visible_views = candidates
	if not _shuffle_visual_slots():
		_reset_visual_state()
		return false
	_presentation_active = true
	_aimed_instance_id = 0
	set_process(true)
	return true


func _reset_visual_state() -> void:
	_presentation_active = false
	_aimed_instance_id = 0
	_visible_views.clear()
	set_process(false)


## 使用最高视图高度建立统一行槽，再用独立 RNG 打乱句子与行槽的映射。
func _shuffle_visual_slots() -> bool:
	var slot_height: float = 48.0
	for view: BarrageView in _visible_views:
		slot_height = maxf(slot_height, view.size.y)
	var row_gap: float = 16.0
	var total_height: float = slot_height * CANDIDATE_COUNT + row_gap * (CANDIDATE_COUNT - 1)
	if total_height > _barrage_area.size.y:
		row_gap = 0.0
		total_height = slot_height * CANDIDATE_COUNT
	if total_height > _barrage_area.size.y:
		return false
	var first_row_y: float = maxf(0.0, minf(48.0, (_barrage_area.size.y - total_height) * 0.5))
	var row_slots: Array[float] = []
	for index: int in CANDIDATE_COUNT:
		row_slots.append(first_row_y + float(index) * (slot_height + row_gap))
	for index: int in range(row_slots.size() - 1, 0, -1):
		var swap_index: int = _slot_rng.randi_range(0, index)
		var previous_slot: float = row_slots[index]
		row_slots[index] = row_slots[swap_index]
		row_slots[swap_index] = previous_slot
	for index: int in _visible_views.size():
		var view: BarrageView = _visible_views[index]
		view.position = Vector2(
			maxf(_barrage_area.size.x - view.size.x, 0.0),
			row_slots[index] + maxf((slot_height - view.size.y) * 0.5, 0.0)
		)
	return true


## 只按准星圆与真实视图矩形筛选；重叠时选择几何中心最近者，真假 ID 不参与。
func _find_aimed_view() -> BarrageView:
	if not is_instance_valid(_aim_reticle) or not _aim_reticle.is_visible_in_tree():
		return null
	var aim_center: Vector2 = _aim_reticle.get_aim_center_global_position()
	var best_view: BarrageView
	var best_distance_squared: float = INF
	for view: BarrageView in _visible_views:
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
