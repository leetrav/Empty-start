extends SceneTree

const AREA=preload("res://systems/barrage_generation/barrage_area.tscn")
const NUMERICS=preload("res://data/combat_stage/combat_numerics.tres")
const TIERS=preload("res://data/combat_stage/tier_catalog.tres")
const VIEW=preload("res://systems/barrage_generation/barrage_view.tscn")
var failures:int=0


## 只保护新公开消费端，人工压力与视觉选型由可玩台验收。
func _initialize() -> void:
	call_deferred("_run")


## 沿直属脚本报告真实失败。
func _check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)


## 使用正式关卡/目录/容量，以及真实repeat与矛盾记录覆盖共享运动。
func _run() -> void:
	seed(25503)
	var area:BarrageArea=AREA.instantiate()
	root.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.size=Vector2(1024,1008)
	area.configure_combat_numerics(NUMERICS)
	var catalog:=BarrageTraitCatalog.new()
	catalog.load_production_tables()
	area.configure_trait_catalog(catalog)
	var stage:=CombatStage.new(TIERS)
	stage.bind_barrage_area(area)
	var profile:LevelProfile=load("res://data/level_configuration/level_001.tres")
	area.start_normal_generation(profile)
	area.stop_normal_generation()
	stage.update_tier_for_pk(0.67)
	area.clear_current_barrages()
	area.spawn_normal_batch_now()
	area.clear_current_barrages()
	area.spawn_normal_batch_now()
	_check(_special_count(area)==0,"默认不擅自开启持续压力")
	area.clear_current_barrages()
	_check(area.configure_counterpressure(1.0),"显式压力配置接受")
	area.spawn_normal_batch_now()
	_check(_special_count(area)==3,"已解锁反击持续生成但受正式特殊上限3约束")
	area.spawn_normal_batch_now()
	_check(_special_count(area)==3,"重复批次不能突破特殊容量")
	area.clear_current_barrages()
	stage.update_tier_for_pk(0.60)
	area.spawn_normal_batch_now()
	_check(_special_count(area)==0,"降档停用T2池")
	area.clear_barrages()
	for type_id:int in range(2):
		for mode:int in range(4):
			var facts:=BarrageRuntimeRecord.new()
			facts.text="共享运动接口"
			facts.is_repeat=type_id==0
			facts.is_contradiction=type_id==1
			facts.capture_lifetime_at_spawn(Time.get_ticks_msec(),10.0,1.0)
			var expiry:int=facts.expires_at_msec
			var view:BarrageView=VIEW.instantiate()
			view.setup(facts,45,area,true)
			area.add_child(view)
			view.position=Vector2(500,200)
			_check(view.configure_shared_motion(mode,45,Vector2.LEFT),"共享运动接受真实类型")
			_check(facts.expires_at_msec==expiry and facts.is_repeat==(type_id==0),"运动不改截止或内容类型")
			await create_timer(0.12).timeout
			_check(view.position!=Vector2(500,200),"四种共享运动实际移动")
			area.end_barrage(view.get_instance_id())
	area.queue_free()
	await process_frame
	print("PTF03_CONSUMERS_PASS" if failures==0 else "PTF03_CONSUMERS_FAIL")
	quit(0 if failures==0 else 1)


## 从真实场上实例派生，不复制容量账本。
func _special_count(area:BarrageArea) -> int:
	var count:int=0
	for child:Node in area.get_children():
		if child is BarrageView and not child.is_queued_for_deletion() and not child.runtime_record.trait_set.get_trait_ids().is_empty():
			count+=1
	return count
