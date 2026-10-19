extends SceneTree

func _initialize() -> void:
	call_deferred("_check_pack")

func _check_pack() -> void:
	var rows: String = FileAccess.get_file_as_string("res://data/source_tables/17_音频事件.csv")
	var total: int = 0
	for id: StringName in BossMusicCatalog.PROFILES:
		var profile: TierMusicProfile = BossMusicCatalog.find_profile(id)
		assert(profile.hold_intro_through_first_tier)
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
					if id == &"alien" and event_id == &"music_alien_intro":
						assert(absf(stream.loop_offset - 4.8) < 0.001)
					if id == &"fox" and event_id in [&"music_fox_intro", &"music_fox_entrance"]:
						assert(absf(stream.loop_offset - 7.432290249433106) < 0.001)
					found = true
					break
			assert(found)
			total += 1
	assert(FileAccess.get_file_as_string("res://assets/audio/music/README.md").contains("FELT LOVE"))
	var rest: AudioStreamOggVorbis = load("res://assets/audio/music/rest/pure_soul.ogg")
	assert(rest != null and rest.loop and rest.get_length() > 10.0)
	assert(rows.contains("music_rest_room,music,assets/audio/music/rest/pure_soul.ogg"))
	assert(FileAccess.get_file_as_string("res://assets/audio/music/rest/README.md").contains("Pure Soul"))
	var tendoh: AudioStreamOggVorbis = load("res://assets/audio/music/ending/tendoh.ogg")
	assert(tendoh != null and tendoh.loop and tendoh.get_length() > 1.0)
	assert(rows.contains("music_ending_tendoh,music,assets/audio/music/ending/tendoh.ogg"))
	assert(FileAccess.get_file_as_string("res://assets/audio/music/ending/README.md").contains("Tendoh"))
	var ending: PackedScene = load("res://ui/ending/ending_page.tscn")
	var page: Node = ending.instantiate()
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("煉獄庭園"))
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("FELT LOVE"))
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("Pure Soul"))
	assert(page.get_node("Margin/PageScroll/Content/MusicCredit").text.contains("天導"))
	page.free()
	print("AU03_PACK_PASS loops=%d rest=true ending=true CSV=true credit=true" % total)
	quit(0)
