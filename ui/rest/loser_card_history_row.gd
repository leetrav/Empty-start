class_name LoserCardHistoryRow
extends PanelContainer

@onready var _streamer_name: Label = %StreamerName
@onready var _missing_profile: Label = %MissingProfile
@onready var _card_art: TextureRect = %CardArt
@onready var _missing_art: Label = %MissingArt
@onready var _card_text: Label = %CardText


# 入树后展示 16 返回的快照；档案缺失仍保留已获 ID，不合成卡面或文案。
func show_card(card: Dictionary) -> void:
	var profile: LoserCardProfile = card["profile"] as LoserCardProfile
	_missing_profile.visible = profile == null
	_card_art.texture = profile.card_art if profile != null else null
	_card_art.visible = _card_art.texture != null
	_missing_art.visible = profile != null and profile.card_art == null
	_card_text.visible = profile != null
	if profile == null:
		_streamer_name.text = "已获卡片 · 档案暂缺"
		_missing_profile.text = "已获主播：%s\n当前目录未提供这张卡片的档案。" % String(card["streamer_id"])
		_card_text.text = ""
	else:
		_streamer_name.text = profile.streamer_name if not profile.streamer_name.is_empty() else "主播名称暂缺"
		_card_text.text = profile.card_text if not profile.card_text.is_empty() else "卡片文案暂缺。"
