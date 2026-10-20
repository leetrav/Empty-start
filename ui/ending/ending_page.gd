class_name EndingPage
extends Control

const SCRIPTURE_ROW: PackedScene = preload("res://ui/ending/ending_scripture_row.tscn")

var _display_data: Dictionary = {}
var _ending_music: EndingMusicPresenter
var _scripture_heading: Control

@onready var _main_art: TextureRect = %MainArt
@onready var _religion_name: Label = %ReligionName
@onready var _scripture_rows: VBoxContainer = %ScriptureRows
@onready var _empty_scripture: Label = %EmptyScripture
@onready var _judgement_section: PanelContainer = %JudgementSection
@onready var _judgement_text: Label = %JudgementText
@onready var _scroll: ScrollContainer = %PageScroll


# 初始化完成后呈现已收到的数据；单独启动时采用空资源的安全显示状态。
func _ready() -> void:
	_build_credits()
	_ending_music = EndingMusicPresenter.new()
	add_child(_ending_music)
	_ending_music.start()
	_apply_display_data()


# 接收 EN-07 的显示结果；允许组合方在入树前设置，页面只持有显示快照。
func show_ending(display_data: Dictionary) -> void:
	_display_data = display_data.duplicate(true)
	if is_node_ready():
		_apply_display_data()


# 只绘制已有结果，章节顺序、编号、教名及判词均由数据提供方决定。
func _apply_display_data() -> void:
	_main_art.texture = _display_data.get("main_art") as Texture2D
	_main_art.visible = _main_art.texture != null
	_religion_name.text = str(_display_data.get("religion_name", ""))
	_religion_name.visible = not _religion_name.text.is_empty()
	_judgement_text.text = str(_display_data.get("judgement_text", ""))
	_judgement_section.visible = not _judgement_text.text.is_empty()
	# 重复呈现先移除旧行，避免同一帧显示新旧两份经文。
	for child: Node in _scripture_rows.get_children():
		_scripture_rows.remove_child(child)
		child.queue_free()
	var scripture: Dictionary = _display_data.get("scripture", {})
	var rows: Array = scripture.get("rows", [])
	# 全空圣典沿用 EN-07 空态并继续绘制缺章，其余结局内容照常呈现。
	_empty_scripture.visible = bool(scripture.get("is_empty", true))
	for row: Dictionary in rows:
		var row_view: EndingScriptureRow = SCRIPTURE_ROW.instantiate() as EndingScriptureRow
		_scripture_rows.add_child(row_view)
		row_view.show_row(row)
	# 空配置收起内容后容器会重新布局，延后归零避免布局沿用旧滚动位置。
	_scroll.set_deferred("scroll_vertical", 0)

# 鸣谢放在通关动画之后；圣典与判词仍保留在同页下方，不重新结算周目。
func _build_credits() -> void:
	var content: VBoxContainer = $Margin/PageScroll/Content
	_scripture_heading = content.get_node("Title")
	(_scripture_heading as Label).text = "本次圣典"
	content.get_node("MusicCredit").hide()
	var margin := MarginContainer.new()
	margin.name = "Credits"
	margin.custom_minimum_size.y = 1000
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_"+side, 96)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_"+side, 32)
	content.add_child(margin)
	content.move_child(margin,0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	_credit_label(column,"鸣谢",48)
	_credit_label(column,"感谢游玩",24,Color("#b7c4c9"))
	_credit_label(column,"制作组",24,Color("#d5bc7e"))
	_credit_label(column,"昂昂小火车番茄牛腩akai",36)
	_credit_label(column,"策划　·　程序　·　场景美术\n角色美术　·　UI　·　音乐音效",23)
	column.add_child(HSeparator.new())
	_credit_label(column,"特别鸣谢",30,Color("#d5bc7e"))
	_credit_label(column,"音乐　煉獄庭園 ／ 作曲・編曲：煉獄小僧",24)
	_credit_label(column,"街 ／ Cafe de Fineday ／ Pop Sky ／ Pure Soul ／ 夢灯 -YumeAkari-\n天導 -Tendoh- ／ Teek Teek Teek ／ 美哀 -Blai- ／ 草原ダンスィング♪-RemakeVer- ／ FELT LOVE\nhttps://note.com/rengokuteien",18,Color("#bdc8ce"))
	_credit_label(column,"音效　Kenney ／ ObsydianX ／ Cassie-OrbitGames ／ JaggedStone",24)
	_credit_label(column,"Kenney：Interface Sounds · Impact Sounds · Sci-Fi Sounds · RPG Audio（CC0）\nhttps://kenney.nl/assets\nObsydianX：Interface SFX Pack 1（CC0）\nhttps://obsydianx.itch.io/interface-sfx-pack-1\nCassie-OrbitGames：Typewriter sounds（CC0）\nhttps://opengameart.org/content/typewriter-sounds\nJaggedStone：Magic Spell SFX（CC0）\nhttps://opengameart.org/content/magic-spell-sfx",18,Color("#bdc8ce"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",24)
	column.add_child(row)
	var scripture := Button.new()
	scripture.text = "查看本次圣典"
	scripture.custom_minimum_size = Vector2(260,64)
	row.add_child(scripture)
	AudioManager.bind_ui_button(scripture)
	scripture.pressed.connect(func(): _scroll.scroll_vertical = int(_scripture_heading.position.y))
	var menu := Button.new()
	menu.name = "CreditsMainMenu"
	menu.text = "返回主菜单"
	menu.custom_minimum_size = Vector2(260,64)
	row.add_child(menu)
	AudioManager.bind_ui_button(menu)
	menu.pressed.connect(func():
		var error := SceneRouter.goto_main_menu()
		if error != OK: push_error("EndingPage: 返回主菜单失败：%s" % error_string(error)))

# 长曲目和来源自动换行，避免低分辨率与窗口缩放时裁切署名。
func _credit_label(parent: Control, text: String, font_size: int, tint: Color = Color("#eee9dc")) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)
