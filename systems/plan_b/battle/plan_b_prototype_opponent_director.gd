class_name PlanBPrototypeOpponentDirector
extends RefCounted

## PB-01 临时费米请求器：模拟 PB-03 公开接口，最终发表始终由 A 执行。

signal publish_word_requested(word_id: String, neutral_unit_id: String)

var speech_enabled: bool = true
var _content_catalog: Object
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _initial_speech_delay: float = 3.0
var _speech_cooldown: float = 11.5
var _speech_remaining: float = 0.0
var _configured: bool = false


func configure(content_catalog: Object, seed_value: int = 1) -> bool:
	# 重新注入内容与随机种子，也重置本局的费米发言时钟。
	_configured = false
	_content_catalog = content_catalog
	if content_catalog == null or not content_catalog.has_method("get_opponent_config"):
		return false
	var profile: Dictionary = content_catalog.call("get_opponent_config", "fermi")
	if profile.is_empty():
		return false
	speech_enabled = bool(profile.get("speech_enabled", true))
	_initial_speech_delay = maxf(float(profile.get("initial_speech_delay_seconds", 0.0)), 0.0)
	_speech_cooldown = maxf(float(profile.get("speech_cooldown_seconds", 11.5)), 0.1)
	_speech_remaining = _initial_speech_delay
	_rng.seed = seed_value
	_configured = true
	return true


func update_speech(
	delta: float,
	neutral_unit_snapshots: Array[Dictionary],
	available_opponent_word_ids: Array[String]
) -> void:
	# C 只请求发言候选；A 收到请求后仍统一校验和提交。
	if not _configured or not speech_enabled or delta <= 0.0:
		return
	_speech_remaining = maxf(_speech_remaining - delta, 0.0)
	if _speech_remaining > 0.0:
		return
	var neutral_unit_ids: Array[String] = []
	for snapshot: Dictionary in neutral_unit_snapshots:
		if String(snapshot.get("team", "")) == "neutral":
			neutral_unit_ids.append(String(snapshot.get("unit_id", "")))
	if neutral_unit_ids.is_empty() or available_opponent_word_ids.is_empty():
		_speech_remaining = _speech_cooldown
		return
	var word_index: int = _rng.randi_range(0, available_opponent_word_ids.size() - 1)
	var unit_index: int = _rng.randi_range(0, neutral_unit_ids.size() - 1)
	_speech_remaining = _speech_cooldown
	publish_word_requested.emit(
		available_opponent_word_ids[word_index], neutral_unit_ids[unit_index]
	)
