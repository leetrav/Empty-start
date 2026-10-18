extends SceneTree

func _initialize() -> void:
	call_deferred("_check_pack")

func _check_pack() -> void:
	var rows: String = FileAccess.get_file_as_string("res://data/source_tables/17_音频事件.csv")
	var total: int = 0
	for id: StringName in BossMusicCatalog.PROFILES:
		var profile: TierMusicProfile = BossMusicCatalog.find_profile(id)
		var event_ids: Array[StringName] = profile.event_ids.duplicate()
		if profile.entrance_event_id != &"":
			event_ids.append(profile.entrance_event_id)
		for event_id: StringName in event_ids:
			var found: bool = false
			for line: String in rows.split("\n"):
				if line.begins_with(String(event_id) + ",music,"):
					var path: String = line.get_slice(",", 2)
					var stream: AudioStreamOggVorbis = load("res://" + path)
					assert(stream != null and stream.loop and stream.get_length() > 1.0)
					found = true
					break
			assert(found)
			total += 1
	assert(FileAccess.get_file_as_string("res://assets/audio/music/README.md").contains("FELT LOVE"))
	var ending: PackedScene = load("res://ui/ending/ending_page.tscn")
	var page: Node = ending.instantiate()
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("煉獄庭園"))
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("FELT LOVE"))
	page.free()
	print("AU03_PACK_PASS loops=%d CSV=true credit=true" % total)
	quit(0)
