class_name BarrageAimIntersection
extends RefCounted


# 用同一准心直径计算圆形准心区域与弹幕矩形区域是否相交，边缘接触算相交。
static func circle_overlaps_rect(
	aim_center: Vector2,
	aim_diameter: float,
	target_area: Rect2
) -> bool:
	var closest_point: Vector2 = aim_center.clamp(target_area.position, target_area.end)
	var radius: float = aim_diameter * 0.5
	return closest_point.distance_squared_to(aim_center) <= radius * radius
