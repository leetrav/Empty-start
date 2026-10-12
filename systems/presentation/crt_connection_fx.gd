class_name CrtConnectionFx
extends Control

signal connection_finished()

const IMPACT_MARK: Texture2D = preload("res://assets/ui/combat/impact_marks/impact_01_razor.png")

@export var blackout_color: Color = Color(0.018, 0.024, 0.045, 1.0)
@export var beam_color: Color = Color(0.91, 0.98, 1.0, 1.0)
@export_range(0.02, 0.3, 0.01) var line_seconds: float = 0.10
@export_range(0.05, 0.6, 0.01) var unfold_seconds: float = 0.30
@export_range(0.02, 0.3, 0.01) var flash_seconds: float = 0.11
@export_range(0.02, 0.4, 0.01) var settle_seconds: float = 0.17
@export_range(0.0, 1.0, 0.01) var scanline_opacity: float = 0.34
@export_range(0.0, 1.0, 0.01) var noise_opacity: float = 0.28
@export_range(0.0, 1.0, 0.01) var flash_opacity: float = 0.50
@export_range(0.05, 0.5, 0.01) var impact_size_ratio: float = 0.28
## 漫画符号中心相对直播画面中心的偏移比例，窗口缩放时保持相对位置。
@export var impact_offset_ratio: Vector2 = Vector2(0.32, -0.32)
@export_range(0.0, 12.0, 0.5) var horizontal_distortion_pixels: float = 3.0

enum Mode { DISCONNECTED, CONNECTING, CONNECTED }

var _mode: Mode = Mode.CONNECTED
var _elapsed: float = 0.0
var _video_layers: Array[CanvasItem] = []
var _saved_materials: Array[Material] = []
var _signal_material: ShaderMaterial


# 临时材质只作用于注入的直播背景与立绘，结束或中断后恢复原材质。
func bind_video_layers(layers: Array[CanvasItem]) -> void:
	_video_layers = layers
	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform float displacement = 0.0;
uniform float phase = 0.0;
void fragment() {
    vec2 shifted_uv = UV;
    float band = step(0.82, sin(UV.y * 87.0 + phase * 43.0));
    shifted_uv.x = clamp(UV.x + band * sin(phase * 59.0) * displacement, 0.0, 1.0);
    COLOR *= texture(TEXTURE, shifted_uv);
}
"""
	_signal_material = ShaderMaterial.new()
	_signal_material.shader = shader


func _restore_video_materials() -> void:
	for index: int in range(_saved_materials.size()):
		if is_instance_valid(_video_layers[index]):
			_video_layers[index].material = _saved_materials[index]
	_saved_materials.clear()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	set_process(false)


# 离开画面时撤销临时材质；不让共享画面节点保留信号干扰。
func _exit_tree() -> void:
	_restore_video_materials()


# T0 保留一整块未连线暗屏；角色 PNG 和背景本身不改色。
func reset_disconnected() -> void:
	_restore_video_materials()
	_mode = Mode.DISCONNECTED
	_elapsed = 0.0
	visible = true
	set_process(false)
	queue_redraw()


func reset_connected() -> void:
	_restore_video_materials()
	_mode = Mode.CONNECTED
	_elapsed = 0.0
	visible = false
	set_process(false)
	queue_redraw()


func play_connection() -> void:
	_restore_video_materials()
	if _signal_material != null:
		for layer: CanvasItem in _video_layers:
			_saved_materials.append(layer.material)
			layer.material = _signal_material
	_mode = Mode.CONNECTING
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func is_connecting() -> bool:
	return _mode == Mode.CONNECTING


func _process(delta: float) -> void:
	_elapsed += delta
	if _signal_material != null:
		var strength: float = 1.0 - clampf(_elapsed / maxf(line_seconds + unfold_seconds + flash_seconds + settle_seconds, 0.001), 0.0, 1.0)
		_signal_material.set_shader_parameter("phase", _elapsed)
		_signal_material.set_shader_parameter("displacement", horizontal_distortion_pixels * strength / maxf(size.x, 1.0))
	if _elapsed >= line_seconds + unfold_seconds + flash_seconds + settle_seconds:
		reset_connected()
		connection_finished.emit()
		return
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _mode == Mode.CONNECTED:
		return
	if _mode == Mode.DISCONNECTED:
		draw_rect(Rect2(Vector2.ZERO, size), blackout_color)
		return
	var unfold_start: float = line_seconds
	var flash_start: float = unfold_start + unfold_seconds
	var settle_start: float = flash_start + flash_seconds
	if _elapsed < line_seconds:
		draw_rect(Rect2(Vector2.ZERO, size), blackout_color)
		var line_t: float = _smooth(_elapsed / line_seconds)
		var half_width: float = size.x * lerpf(0.10, 0.49, line_t)
		var center_y: float = size.y * 0.5
		var glow: Color = beam_color
		glow.a = 0.22 * line_t
		draw_rect(Rect2(size.x * 0.5 - half_width, center_y - 7.0, half_width * 2.0, 14.0), glow)
		draw_line(Vector2(size.x * 0.5 - half_width, center_y), Vector2(size.x * 0.5 + half_width, center_y), beam_color * Color(1, 1, 1, line_t), 3.0, true)
		return
	var opening: float = 1.0
	var interference: float = 0.0
	if _elapsed < flash_start:
		opening = _smooth((_elapsed - unfold_start) / unfold_seconds)
		interference = 1.0 - 0.30 * opening
	elif _elapsed < settle_start:
		interference = 0.65
	else:
		interference = 0.65 * (1.0 - _smooth((_elapsed - settle_start) / settle_seconds))
	var half_height: float = maxf(2.0, size.y * 0.5 * opening)
	var top: float = size.y * 0.5 - half_height
	var bottom: float = size.y * 0.5 + half_height
	if top > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, top), blackout_color)
	if bottom < size.y:
		draw_rect(Rect2(0.0, bottom, size.x, size.y - bottom), blackout_color)
	var edge: Color = beam_color
	edge.a = 0.66 * (1.0 - opening) + 0.08
	draw_line(Vector2(0.0, top), Vector2(size.x, top), edge, 2.0, true)
	draw_line(Vector2(0.0, bottom), Vector2(size.x, bottom), edge, 2.0, true)
	_draw_interference(top, bottom, interference)
	if _elapsed >= flash_start and _elapsed < settle_start:
		var flash_t: float = (_elapsed - flash_start) / flash_seconds
		var flash: Color = beam_color
		flash.a = flash_opacity * (1.0 - _smooth(flash_t))
		draw_rect(Rect2(Vector2.ZERO, size), flash)
		var impact_side: float = minf(size.x, size.y) * impact_size_ratio
		var impact_modulate: Color = Color(1, 1, 1, 0.82 * (1.0 - _smooth(flash_t)))
		var impact_center: Vector2 = size * (Vector2(0.5, 0.5) + impact_offset_ratio)
		draw_texture_rect(IMPACT_MARK, Rect2(impact_center - Vector2.ONE * impact_side * 0.5, Vector2.ONE * impact_side), false, impact_modulate)


# 扫描线与短暂信号条只覆盖已经展开的直播画面，不改变底层立绘。
func _draw_interference(top: float, bottom: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var spacing: float = maxf(5.0, size.y * 0.022)
	var count: int = int(ceilf((bottom - top) / spacing))
	for i: int in range(count):
		var y: float = top + float(i) * spacing
		if y >= bottom:
			break
		var scan: Color = Color(0.035, 0.055, 0.09, scanline_opacity * strength)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), scan, 2.0)
	for i: int in range(5):
		var fraction: float = float((i * 37 + 11) % 97) / 97.0
		var y: float = lerpf(top, bottom, fraction)
		var width: float = size.x * (0.16 + 0.10 * float(i % 3))
		var x: float = size.x * float((i * 23 + 7) % 71) / 100.0
		var noise: Color = Color(0.84, 0.97, 1.0, noise_opacity * strength)
		draw_rect(Rect2(x, y, minf(width, size.x - x), maxf(1.0, size.y * 0.006)), noise)


func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
