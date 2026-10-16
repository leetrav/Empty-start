extends SceneTree

class AudioSink extends Node:
	var music_events: Array[StringName] = []
	## 收集正式音乐请求，不依赖尚未交付的音频素材。
	func change_music(event_id: StringName) -> bool:
		music_events.append(event_id)
		return true
	## 本例只核对音乐事件，升档音效继续保留独立通道。
	func play_event(_event_id: StringName) -> void:
		pass


## 真实 CombatStage 从 T0 升至 T5 再降档，验证 08 原 ID 和重复绑定。
func _initialize() -> void:
	var catalog: CombatStageTierCatalog = load("res://data/combat_stage/tier_catalog.tres")
	var audio := AudioSink.new()
	var stage := CombatStage.new(catalog)
	stage.bind_audio_manager(audio)
	stage.bind_audio_manager(audio)
	stage.begin_combat()
	for pk: float in [0.60, 0.67, 0.75, 0.85, 0.95]:
		assert(stage.update_tier_for_pk(pk))
	assert(not stage.update_tier_for_pk(0.95))
	assert(stage.update_tier_for_pk(0.55))
	var expected: Array[StringName] = []
	for tier: int in range(6):
		var event_id := StringName("music_battle_t%d" % tier)
		assert(catalog.get_tier_config(tier).music_event_id == event_id)
		expected.append(event_id)
	expected.append(&"music_battle_t1")
	assert(audio.music_events == expected)
	assert(stage.get_current_music_event_id() == &"music_battle_t1")
	audio.free()
	print("INT17A_TIER_MUSIC_PASS requests=T0,T1,T2,T3,T4,T5,T1 duplicate_bind=once")
	quit(0)
