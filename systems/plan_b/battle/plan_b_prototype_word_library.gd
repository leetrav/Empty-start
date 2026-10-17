class_name PlanBPrototypeWordLibrary
extends RefCounted

## PB-01 临时词库：给 A/D 联调提供稳定查询接口，后续可替换为 PB-03 的正式原型词库。

const PLAYER_WORD_IDS: Array[String] = ["player_a_01", "player_b_01", "player_c_01"]
const OPPONENT_WORD_IDS: Array[String] = ["opponent_a_01", "opponent_b_01", "opponent_c_01"]

const WORDS: Dictionary = {
	"player_a_01": {
		"word_id": "player_a_01", "text": "先把证据摆出来", "battle_type": "type_a",
		"strength": 2, "traits": ["infect"], "tendency": "orthodox",
	},
	"player_b_01": {
		"word_id": "player_b_01", "text": "大家都可以再想想", "battle_type": "type_b",
		"strength": 1, "traits": ["infect"], "tendency": "neutral",
	},
	"player_c_01": {
		"word_id": "player_c_01", "text": "这事还有另一种解释", "battle_type": "type_c",
		"strength": 3, "traits": ["infect"], "tendency": "heretical",
	},
	"opponent_a_01": {
		"word_id": "opponent_a_01", "text": "结论已经很明显了", "battle_type": "type_a",
		"strength": 2, "traits": ["infect"], "tendency": "orthodox",
	},
	"opponent_b_01": {
		"word_id": "opponent_b_01", "text": "先别急着下定论", "battle_type": "type_b",
		"strength": 2, "traits": ["infect"], "tendency": "neutral",
	},
	"opponent_c_01": {
		"word_id": "opponent_c_01", "text": "换个角度看就通了", "battle_type": "type_c",
		"strength": 1, "traits": ["infect"], "tendency": "absurd",
	},
}


## 返回独立值快照，调用方无法改写本地静态词库。
func get_word_definition(word_id: String) -> Dictionary:
	var definition: Dictionary = WORDS.get(word_id, {})
	return definition.duplicate(true)


## 给玩家界面或费米决策读取尚未发表的候选词 ID。
func get_word_ids(available_level: String, team: String) -> Array[String]:
	if available_level != "level_001":
		return []
	return PLAYER_WORD_IDS.duplicate() if team == "player" else OPPONENT_WORD_IDS.duplicate()


func get_available_word_ids(
	team: String, used_word_ids: Array[String], available_level: String = "level_001"
) -> Array[String]:
	var source_ids: Array[String] = PLAYER_WORD_IDS if team == "player" else OPPONENT_WORD_IDS
	var available: Array[String] = []
	if available_level != "level_001":
		return available
	for word_id: String in source_ids:
		if not used_word_ids.has(word_id):
			available.append(word_id)
	return available


## 费米占位控制器按 C 正式接口读取原型发言时序。
func get_opponent_config(opponent_id: String) -> Dictionary:
	if opponent_id != "fermi":
		return {}
	return {
		"speech_enabled": true,
		"initial_speech_delay_seconds": 3.0,
		"speech_cooldown_seconds": 11.5,
	}
