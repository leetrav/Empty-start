class_name PlanBFermiBattleArena
extends Control

## PB-01 临时棋盘视图：只画模拟快照，并把中立观众点击位置交给父场景。

signal arena_pressed(position: Vector2)

const BACKGROUND: Color = Color("#191e2b")
const GRID: Color = Color("#293346")
const PLAYER_COLOR: Color = Color("#54d7b0")
const OPPONENT_COLOR: Color = Color("#ff876f")
const NEUTRAL_COLOR: Color = Color("#b6bfd1")
const SELECTED_COLOR: Color = Color("#ffe28a")

var _snapshots: Array[Dictionary] = []
var _selected_unit_id: String = ""
var _battle_started: bool = false
var _world_origin: Vector2 = Vector2.ZERO


func set_world_origin(origin: Vector2) -> void:
	# 快照使用战斗场景坐标；绘制时换算为本棋盘的局部坐标。
	_world_origin = origin
	queue_redraw()


func set_battle_snapshot(
	snapshots: Array[Dictionary], selected_unit_id: String, battle_started: bool
) -> void:
	_snapshots = snapshots
	_selected_unit_id = selected_unit_id
	_battle_started = battle_started
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	for x_position: float in range(0, int(size.x), 80):
		draw_line(Vector2(x_position, 0.0), Vector2(x_position, size.y), GRID, 1.0)
	for y_position: float in range(0, int(size.y), 80):
		draw_line(Vector2(0.0, y_position), Vector2(size.x, y_position), GRID, 1.0)
	if not _battle_started:
		draw_string(
			ThemeDB.fallback_font, Vector2(24.0, 44.0), "点击「开始战斗」生成观众棋子",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("#d2d9e7")
		)
		return
	for snapshot: Dictionary in _snapshots:
		var team: String = String(snapshot.get("team", "neutral"))
		var unit_position: Vector2 = snapshot.get("position", Vector2.ZERO) - _world_origin
		var unit_color: Color = NEUTRAL_COLOR
		if team == "player":
			unit_color = PLAYER_COLOR
		elif team == "opponent":
			unit_color = OPPONENT_COLOR
		draw_circle(unit_position, 8.5, unit_color)
		if String(snapshot.get("unit_id", "")) == _selected_unit_id:
			draw_circle(unit_position, 12.5, SELECTED_COLOR, false, 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			arena_pressed.emit(mouse_event.position)
			accept_event()
