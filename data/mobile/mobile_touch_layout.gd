class_name MobileTouchLayout
extends Resource

## 触点到准心的密度换算偏置；正式方案批准前保持零，由宿主显式注入。
@export var aim_offset_mm: Vector2 = Vector2.ZERO
## 独立状态条相对安全区的位置，避开实际手指。
@export var feedback_anchor: Vector2 = Vector2(0.5, 0.1)
@export var feedback_width_mm: float = 42.0
@export var feedback_font_mm: float = 2.6
@export var edge_margin_mm: float = 3.0
