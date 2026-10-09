extends SceneTree

# 一次核对正式源正文、12 个稳定 ID 与 4/4/4 映射。
func _init() -> void:
	var source := FileAccess.open("res://data/source_tables/01_身份配置.csv", FileAccess.READ)
	var header := source.get_csv_line()
	var ids: Array[StringName] = []
	var counts := {"orthodox": 0, "heretical": 0, "absurd": 0}
	while not source.eof_reached():
		var row := source.get_csv_line()
		if row.size() != header.size():
			continue
		var identity_id := StringName(row[header.find("identity_id")])
		var option := IdentityOptions.find_option(identity_id)
		assert(option != null and IdentityOptions.CARDS.has(option))
		assert(not ids.has(identity_id))
		ids.append(identity_id)
		assert(option.display_name == row[header.find("display_name")])
		assert(option.description == row[header.find("description")])
		var tendency := row[header.find("tendency")]
		if tendency == "heresy":
			tendency = "heretical"
		assert(option.tendency_id == tendency)
		counts[tendency] += 1
	assert(ids.size() == 12 and IdentityOptions.CARDS.size() == 12)
	assert(counts == {"orthodox": 4, "heretical": 4, "absurd": 4})
	print("PASS ID-08: 12 exact CSV identities; orthodox/heretical/absurd = 4/4/4")
	quit()
