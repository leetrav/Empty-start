extends SceneTree

const CATALOG_PATH := "res://data/level_configuration/level_catalog.tres"
const EXPECTED_STREAMERS := ["alien", "kiwi", "frog", "fox"]


func _initialize() -> void:
	# 只验收正式目录实际引用的数据；TEST_ONLY 夹具不参与本检查。
	var failures: Array[String] = []
	var catalog: Resource = load(CATALOG_PATH)
	if catalog == null:
		_fail("正式关卡目录无法加载：%s" % CATALOG_PATH)
		quit(1)
		return

	var profiles_value = catalog.get("profiles")
	if not profiles_value is Array:
		_fail("正式关卡目录没有可读取的 profiles 数组")
		quit(1)
		return
	var profiles: Array = profiles_value
	var actual_streamers: Array[String] = []
	if profiles.size() != EXPECTED_STREAMERS.size():
		failures.append("正式关卡数量应为 4，实际为 %d" % profiles.size())

	for index in profiles.size():
		var profile: Resource = profiles[index]
		if profile == null:
			failures.append("目录第 %d 项为空" % (index + 1))
			continue
		var streamer_id := str(profile.get("streamer_id"))
		var level_id := str(profile.get("level_id"))
		var expected_level_id := "level_%03d" % (index + 1)
		actual_streamers.append(streamer_id)
		if level_id != expected_level_id:
			failures.append("第 %d 项 level_id 应为 %s，实际为 %s" % [index + 1, expected_level_id, level_id])
		if int(profile.get("level_order")) != index + 1:
			failures.append("%s 的 level_order 与目录顺序不一致" % level_id)
		if streamer_id != EXPECTED_STREAMERS[index]:
			failures.append("%s 应关联主播 %s，实际为 %s" % [level_id, EXPECTED_STREAMERS[index], streamer_id])
		_check_user_visible_data(profile, level_id, failures)

	if actual_streamers != EXPECTED_STREAMERS:
		failures.append("正式主播顺序应为 alien → kiwi → frog → fox，实际为 %s" % " → ".join(actual_streamers))

	if failures.is_empty():
		print("PASS INT-15 production catalog: 4 ordered levels, usable words and contradictions")
		quit(0)
		return

	for failure in failures:
		_fail(failure)
	print("FAIL INT-15 production catalog: %d issue(s)" % failures.size())
	quit(1)


func _check_user_visible_data(profile: Resource, level_id: String, failures: Array[String]) -> void:
	var visible_values := [str(profile.get("streamer_name")), str(profile.get("stream_topic"))]
	for value in visible_values:
		if value.strip_edges().is_empty() or _looks_like_placeholder(value):
			failures.append("%s 含空白或示例占位主播信息" % level_id)
			break

	var speeches_value = profile.call("get_normal_speech_pool")
	if not speeches_value is Array:
		failures.append("%s 的普通词库无法读取" % level_id)
		return
	var speeches: Array = speeches_value
	if speeches.is_empty():
		failures.append("%s 没有关联可用普通词库" % level_id)
	else:
		var usable_speech_count := 0
		for speech in speeches:
			if speech == null:
				continue
			var speech_text := str(speech.get("text"))
			if not speech_text.strip_edges().is_empty() and not _looks_like_placeholder(speech_text):
				usable_speech_count += 1
		if usable_speech_count == 0:
			failures.append("%s 的普通词库只有空文本或示例占位词" % level_id)

	for field_name in ["true_contradictions", "false_contradictions"]:
		var contradictions: Array = profile.get(field_name)
		var has_usable_text := false
		for contradiction in contradictions:
			if contradiction == null:
				continue
			var contradiction_text := str(contradiction.get("text"))
			if not contradiction_text.strip_edges().is_empty() and not _looks_like_placeholder(contradiction_text):
				has_usable_text = true
		if not has_usable_text:
			failures.append("%s 缺少可用 %s 数据" % [level_id, field_name])


func _looks_like_placeholder(value: String) -> bool:
	var normalized := value.to_lower()
	for marker in ["test_only", "sample", "示例", "待替换", "待策划", "待填写", "占位"]:
		if normalized.contains(marker):
			return true
	return false


func _fail(message: String) -> void:
	push_error("INT-15 PREFLIGHT: " + message)
