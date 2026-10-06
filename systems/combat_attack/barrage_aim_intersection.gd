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
	var distance_squared: float = closest_point.distance_squared_to(aim_center)
	var radius_squared: float = radius * radius
	# 缩放逆变换可能让恰好接触边缘的坐标略有误差，近似相等仍按接触处理。
	return distance_squared <= radius_squared or is_equal_approx(distance_squared, radius_squared)
