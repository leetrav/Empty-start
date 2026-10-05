## 按对象实例身份维护一组弹幕容量；不同用途分别持有独立账本。
class_name BarrageCapacityLedger
extends RefCounted

var _occupants: Dictionary = {}

## 同一份身份集合共享上限；对象已登记时重复请求保持成功。
func try_register(occupant: Object, capacity_limit: int) -> bool:
	if occupant == null:
		return false
	var occupant_id: int = occupant.get_instance_id()
	if _occupants.has(occupant_id):
		return true
	if _occupants.size() >= capacity_limit:
		return false
	_occupants[occupant_id] = occupant
	return true

## 按对象身份释放容量，未登记对象不会改变占用数量。
func release(occupant: Object) -> bool:
	if not has_occupant(occupant):
		return false
	_occupants.erase(occupant.get_instance_id())
	return true

## 判断对象是否已经登记占用。
func has_occupant(occupant: Object) -> bool:
	return occupant != null and _occupants.has(occupant.get_instance_id())

## 判断上限内是否还有可用容量。
func has_capacity(capacity_limit: int) -> bool:
	return _occupants.size() < capacity_limit
