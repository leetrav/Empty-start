extends RefCounted

## 按气泡真实文本合成短促、非语言的电子啾声；不生成可辨认词句。
const SAMPLE_RATE: int = 22050
const MAX_VOICE_SECONDS: float = 1.2
const MAX_UNIT_SECONDS: float = 0.055

const SPEAKER_PROFILES: Dictionary = {
	"hamster": {"pitch": 690.0, "harmonic_2": 0.20, "harmonic_3": 0.08},
	"alien": {"pitch": 390.0, "harmonic_2": 0.30, "harmonic_3": 0.16},
	"kiwi": {"pitch": 570.0, "harmonic_2": 0.14, "harmonic_3": 0.22},
	"frog": {"pitch": 430.0, "harmonic_2": 0.34, "harmonic_3": 0.10},
	"fox": {"pitch": 620.0, "harmonic_2": 0.24, "harmonic_3": 0.13},
}

const PUNCTUATION_WEIGHTS: Dictionary = {
	"，": 1.6,
	"、": 1.4,
	"；": 1.8,
	"：": 1.5,
	"。": 2.4,
	"！": 2.2,
	"？": 2.2,
	",": 1.6,
	";": 1.8,
	":": 1.5,
	".": 2.4,
	"!": 2.2,
	"?": 2.2,
}


## 依字数分配短音节，标点只占停顿；整句上限1.2秒。
static func build_stream(text: String, speaker_id: StringName) -> AudioStreamWAV:
	var tokens: Array[Dictionary] = _make_tokens(text)
	var total_weight: float = 0.0
	var has_voice: bool = false
	for token: Dictionary in tokens:
		total_weight += float(token["weight"])
		has_voice = has_voice or str(token["kind"]) == "voice"
	if not has_voice or total_weight <= 0.0:
		return null

	var seconds_per_weight: float = minf(MAX_UNIT_SECONDS, MAX_VOICE_SECONDS / total_weight)
	var sample_counts: Array[int] = []
	var total_sample_count: int = 0
	for token: Dictionary in tokens:
		var count: int = maxi(1, roundi(seconds_per_weight * float(token["weight"]) * SAMPLE_RATE))
		sample_counts.append(count)
		total_sample_count += count

	var samples := PackedByteArray()
	samples.resize(total_sample_count * 2)
	var profile: Dictionary = SPEAKER_PROFILES.get(str(speaker_id), SPEAKER_PROFILES["hamster"])
	var cursor: int = 0
	for index: int in tokens.size():
		var token: Dictionary = tokens[index]
		var sample_count: int = sample_counts[index]
		if str(token["kind"]) == "voice":
			var voiced_count: int = maxi(1, int(float(sample_count) * 0.72))
			_write_syllable(samples, cursor, voiced_count, profile, int(token["seed"]))
		cursor += sample_count

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream


static func _make_tokens(text: String) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	for index: int in text.length():
		var character: String = text.substr(index, 1)
		if PUNCTUATION_WEIGHTS.has(character):
			tokens.append({"kind": "pause", "weight": float(PUNCTUATION_WEIGHTS[character]), "seed": 0})
		elif character.strip_edges().is_empty():
			tokens.append({"kind": "pause", "weight": 0.65, "seed": 0})
		else:
			tokens.append({"kind": "voice", "weight": 1.0, "seed": character.hash() + index * 17})
	return tokens


static func _write_syllable(
		output: PackedByteArray,
		offset: int,
		sample_count: int,
		profile: Dictionary,
		seed: int
	) -> void:
	var edge_length: float = maxf(1.0, float(sample_count) * 0.2)
	var pitch_offset: float = float(posmod(seed, 9) - 4) * 8.0
	var base_pitch: float = float(profile["pitch"]) + pitch_offset
	for index: int in sample_count:
		var progress: float = float(index) / float(sample_count)
		var attack: float = minf(1.0, float(index) / edge_length)
		var release: float = minf(1.0, float(sample_count - index) / edge_length)
		var envelope: float = minf(attack, release)
		var pitch: float = base_pitch * (1.0 + 0.055 * sin(progress * PI))
		var phase: float = TAU * pitch * float(index) / float(SAMPLE_RATE)
		var wave: float = sin(phase) * 0.62 \
			+ sin(phase * 2.0 + 0.18) * float(profile["harmonic_2"]) \
			+ sin(phase * 3.0 + 0.37) * float(profile["harmonic_3"])
		var value: int = roundi(clampf(wave * envelope * 0.24, -1.0, 1.0) * 32767.0)
		output.encode_s16((offset + index) * 2, value)
