extends SceneTree

func _initialize() -> void:
	call_deferred("_check_pack")

func _check_pack() -> void:
	var rows: String = FileAccess.get_file_as_string("res://data/source_tables/17_音频事件.csv")
	var total: int = 0
	for group: String in ["intro", "low", "mid", "high"]:
		assert(rows.contains("music_alien_" + group + ",music,assets/audio/music/fermi/teek_" + group + ".ogg"))
		var stream: Resource = load("res://assets/audio/music/fermi/teek_" + group + ".ogg")
		assert(stream != null and stream.get("loop") and absf(stream.call("get_length") - 19.2) < 0.002)
		total += 1
	var ending: PackedScene = load("res://ui/ending/ending_page.tscn")
	var page: Node = ending.instantiate()
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("煉獄庭園"))
	page.free()
	print("AU03_PACK_PASS loops=%d CSV=true credit=true" % total)
	quit(0)
