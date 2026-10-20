extends SceneTree
const HOST = preload("res://systems/plan_b/battle/plan_b_battle_host.gd")
var failures: int = 0
class Population extends Node:
	var counts: Dictionary = {"player":61,"opponent":4,"neutral":3}
	func get_faction_counts() -> Dictionary: return counts
	func set_active(_enabled: bool) -> void: pass
# 验证权威PK的累计与终点事件，不用调试直接置满代替真实update_pk路径。
func _initialize() -> void:
	_check_case("upper epsilon",0.999995,{"player":61,"opponent":4,"neutral":3},1.0/60.0,1,1.0,"enter_contradiction")
	_check_case("lower epsilon",0.000000001,{"player":4,"opponent":61,"neutral":3},1.0/60.0,1,0.0,"failed")
	_check_case("ordinary gain",0.8,{"player":48,"opponent":47,"neutral":1},1.0/60.0,1000,0.8+3.0/96.0/60.0/100.0*1000.0,"")
	_check_case("tiny gain",0.5,{"player":61,"opponent":4,"neutral":3},0.000001,1000,0.5+3.0*57.0/68.0*0.000001/100.0*1000.0,"")
	_check_case("balanced",0.8,{"player":47,"opponent":47,"neutral":2},1.0/60.0,100,0.8,"")
	for initial: float in [0.999995,0.000000001]:
		var host = HOST.new()
		var population := Population.new()
		host.set("_simulation",population)
		host.set("_battle_state",HOST.BattleState.RUNNING)
		host.set("_pk",initial)
		var events: Array = []
		host.battle_ended.connect(func(result): events.append(str(result)))
		var target: float = 1.0 if initial > 0.5 else 0.0
		_check(host.set_player_pk_for_debug(target) and host.get_pk_fraction() == target,"debug endpoint assigned exactly")
		_check(events.size() == 1,"debug terminal once")
		host.set_player_pk_for_debug(target)
		_check(events.size() == 1,"debug repeated terminal rejected")
		host.free()
		population.free()
	print("PK_BOUNDARY_UNIT_DONE failures=",failures)
	quit(failures)
func _check_case(label: String,initial: float,counts: Dictionary,delta: float,ticks: int,expected: float,event: String) -> void:
	var host = HOST.new()
	var population := Population.new()
	population.counts = counts
	host.set("_simulation",population)
	host.set("_battle_state",HOST.BattleState.RUNNING)
	host.set("_pk",initial)
	var events: Array = []
	host.battle_ended.connect(func(result): events.append(str(result)))
	for tick: int in range(ticks): host.update_pk(delta)
	_check(absf(host.get_pk_fraction()-expected)<0.0000000001,label+" exact accumulation")
	_check(events == ([] if event.is_empty() else [event]),label+" terminal events")
	for tick: int in range(100):
		if not event.is_empty(): host.update_pk(delta)
	_check(events.size() == (0 if event.is_empty() else 1),label+" no duplicate end")
	print("PK_BOUNDARY_UNIT ",label," value=",host.get_pk_fraction()," events=",events)
	host.free()
	population.free()
func _check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
