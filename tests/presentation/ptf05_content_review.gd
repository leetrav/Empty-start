extends Control

const CARD_ROW = preload("res://ui/rest/loser_card_history_row.tscn")
const ENDING_VIEW = preload("res://ui/ending/ending_sequence_view.tscn")
var _collection := LoserCardData.new()
var _catalog: LoserCardCatalog
var _content: Control
var _status: Label
var _ending: EndingSequenceView
var _media: String = ""
var _replay: bool = false


## 只使用本地TEST_ONLY资料和内存周目；生产14/16表及SaveManager均不改。
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		_replay = _replay or argument == "--replay"
		if argument.begins_with("--media="):
			_media = argument.trim_prefix("--media=")
	if not _media.is_empty():
		assert(_media.replace("\\", "/").to_lower().begins_with("d:/"))
		DirAccess.make_dir_recursive_absolute(_media)
	var background := ColorRect.new()
	background.size = Vector2(1920, 1080)
	background.color = Color("17212c")
	add_child(background)
	var title := Label.new()
	title.text = "PTF-05 · 本地V0内容审核 · 卡面/时序待真人批准 · 正式剧情仍缺"
	title.position = Vector2(24, 15)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(24, 72)
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	_button(buttons, "卡面A · 日常立绘", _show_cards.bind("a"))
	_button(buttons, "卡面B · 击败立绘", _show_cards.bind("b"))
	_button(buttons, "结束A · 1.2秒快切", _show_ending.bind("a"))
	_button(buttons, "结束B · 2秒淡入", _show_ending.bind("b"))
	_button(buttons, "模拟仅赢PK", _grant_demo.bind(false))
	_button(buttons, "模拟击破+确认", _grant_demo.bind(true))
	_content = Control.new()
	_content.position = Vector2(24, 160)
	_content.size = Vector2(1872, 800)
	add_child(_content)
	_status = Label.new()
	_status.position = Vector2(24, 980)
	_status.size = Vector2(1872, 90)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 25)
	add_child(_status)
	var production: LoserCardCatalog = load("res://data/loser_card/loser_card_catalog.tres")
	assert(production.profiles.is_empty())
	_show_cards("a")
	if _replay:
		_run_review.call_deferred()


## 复用已有卡片行，展示真实图片/原主播名；空描述继续显示现有资料暂缺状态。
func _show_cards(variant: String) -> void:
	_clear_content()
	_catalog = load("res://data/test_only/ptf05/loser_cards_%s.tres" % variant)
	var row := HBoxContainer.new()
	row.size = _content.size
	row.add_theme_constant_override("separation", 20)
	_content.add_child(row)
	for profile: LoserCardProfile in _catalog.profiles:
		var card: LoserCardHistoryRow = CARD_ROW.instantiate()
		card.custom_minimum_size = Vector2(448, 680)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		card.show_card({"streamer_id": profile.streamer_id, "profile": profile})
	_status.text = "卡面%s：复用已入库角色图，正式介绍仍空；审核展示4份资料，演示周目已获%d张。生产14仍全禁用。" % [variant.to_upper(), _collection.acquired_streamer_ids.size()]
	print("PTF05_CARD_REVIEW variant=", variant, " catalog=", _catalog.profiles.size(), " acquired=", _collection.acquired_streamer_ids.size())


## 实际调用既有发卡入口；条件只在审核演示内设置，绝不冒称正式战斗完成。
func _grant_demo(broken_and_confirmed: bool) -> void:
	if _catalog == null:
		_catalog = load("res://data/test_only/ptf05/loser_cards_a.tres")
	var count: int = 0
	for index: int in _catalog.profiles.size():
		var profile: LoserCardProfile = _catalog.profiles[index]
		if _collection.grant_on_true_defeat(StringName("level_%03d" % (index + 1)), profile.streamer_id, broken_and_confirmed, broken_and_confirmed, _catalog):
			count += 1
	_status.text = "TEST_ONLY条件演示：击破+确认=%s，本次新增%d张，内存周目共%d张；正式生产目录保持空。" % [broken_and_confirmed, count, _collection.acquired_streamer_ids.size()]
	print("PTF05_CARD_GRANT broken_confirmed=", broken_and_confirmed, " new=", count, " total=", _collection.acquired_streamer_ids.size())


## 结束预览仅回顾已有击败图/主角，不借用开场P5/P6或编写正式剧情。
func _show_ending(variant: String) -> void:
	_clear_content()
	_ending = ENDING_VIEW.instantiate()
	_ending.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_ending.size = _content.size
	_content.add_child(_ending)
	var sequence: ComicSequence = load("res://data/test_only/ptf05/ending_review_%s.tres" % variant)
	assert(_ending.play_sequence(sequence))
	_status.text = "结束%s：5页现有素材回顾，点击可快进；这是待审演出V0。独立正式剧情页、九教名、四判词、三主图仍缺。" % variant.to_upper()


## 原生按钮支持人类手动选择与复播；没有自动固化生产方案。
func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


## 清理当前子演出，旧Timer不会影响下一个卡面/序列。
func _clear_content() -> void:
	if is_instance_valid(_ending):
		_ending.stop()
	_ending = null
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


## GPU复播证明发卡规则和时序可运行；不把条件演示写成真实玩家通关验收。
func _run_review() -> void:
	_grant_demo(false)
	assert(_collection.acquired_streamer_ids.is_empty())
	assert(not _collection.grant_on_true_defeat(&"level_001", &"alien", true, false, _catalog))
	_grant_demo(true)
	assert(_collection.acquired_streamer_ids.size() == 4)
	_grant_demo(true)
	assert(_collection.acquired_streamer_ids.size() == 4)
	await get_tree().create_timer(0.6).timeout
	await _capture("cards_a")
	_show_cards("b")
	await get_tree().create_timer(0.6).timeout
	await _capture("cards_b")
	_show_ending("a")
	await get_tree().create_timer(0.9).timeout
	await _capture("ending_a_1")
	await get_tree().create_timer(2.2).timeout
	await _capture("ending_a_3")
	await _ending.sequence_finished
	_show_ending("b")
	await get_tree().create_timer(1.0).timeout
	await _capture("ending_b_1")
	await get_tree().create_timer(3.6).timeout
	await _capture("ending_b_3")
	await _ending.sequence_finished
	var official: ComicSequence = load("res://data/ending/ending_comic.tres")
	assert(official.frames.is_empty())
	print("PTF05_CONTENT_REVIEW_PASS cards=4 grant_qualified_only=true duplicate_grant=0 ending_v0=2 official_content_pending=true")
	get_tree().quit()


## 只保存真实GPU视口，媒体留在调用方指定D盘。
func _capture(label: String) -> void:
	if _media.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(_media.path_join(label + ".png")) == OK)
