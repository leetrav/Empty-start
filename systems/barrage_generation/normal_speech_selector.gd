## 从当前关卡普通话语池中按倾向比例和单句权重选择下一句。
class_name NormalSpeechSelector
extends RefCounted

var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_random.randomize()

## 每次都读取传入配置的当前词库，不缓存，保证有效内容变化后立即生效。
func select_next_normal_speech(current_level: LevelProfile, neutral_weight_multiplier: float = 1.0) -> LevelSpeech:
	if current_level == null:
		return null

	var active_tendency_ids: Array[String] = []
	var active_tendency_weights: Array[float] = []
	var total_tendency_weight: float = 0.0
	var tendency_ids: Array[String] = ["orthodox", "heretical", "absurd", "neutral"]

	for tendency_id in tendency_ids:
		var ratio: float = _get_tendency_ratio(current_level, tendency_id)
		if tendency_id == "neutral":
			# 只缩放本次 neutral 类别权重，其他三类继续使用关卡原始比例。
			ratio *= maxf(neutral_weight_multiplier, 0.0)
		if ratio <= 0.0:
			continue
		if _collect_candidates(current_level, tendency_id).is_empty():
			continue
		active_tendency_ids.append(tendency_id)
		active_tendency_weights.append(ratio)
		total_tendency_weight += ratio

	if total_tendency_weight <= 0.0:
		return null

	var category_roll: float = _random.randf() * total_tendency_weight
	var selected_tendency_id: String = active_tendency_ids[active_tendency_ids.size() - 1]
	for index in range(active_tendency_ids.size()):
		if category_roll < active_tendency_weights[index]:
			selected_tendency_id = active_tendency_ids[index]
			break
		category_roll -= active_tendency_weights[index]

	return _pick_weighted_speech(_collect_candidates(current_level, selected_tendency_id))

## 只将有原句 ID、文本和正权重的话语作为候选。
func _collect_candidates(current_level: LevelProfile, tendency_id: String) -> Array[LevelSpeech]:
	var candidates: Array[LevelSpeech] = []
	for speech in current_level.normal_speech_pool:
		if speech == null or speech.tendency_id != tendency_id:
			continue
		if speech.original_sentence_id.is_empty() or speech.text.is_empty():
			continue
		if speech.appearance_weight <= 0.0:
			continue
		candidates.append(speech)
	return candidates

## 把共享稳定倾向 ID 映射到当前关配置的对应比例。
func _get_tendency_ratio(current_level: LevelProfile, tendency_id: String) -> float:
	match tendency_id:
		"orthodox":
			return current_level.orthodox_ratio
		"heretical":
			return current_level.heretical_ratio
		"absurd":
			return current_level.absurd_ratio
		"neutral":
			return current_level.neutral_ratio
	return 0.0

## 按话语相对权重抽取同一倾向内的一句。
func _pick_weighted_speech(candidates: Array[LevelSpeech]) -> LevelSpeech:
	var total_weight: float = 0.0
	for speech in candidates:
		total_weight += speech.appearance_weight
	if total_weight <= 0.0:
		return null

	var speech_roll: float = _random.randf() * total_weight
	for speech in candidates:
		speech_roll -= speech.appearance_weight
		if speech_roll < 0.0:
			return speech
	return candidates[candidates.size() - 1]
