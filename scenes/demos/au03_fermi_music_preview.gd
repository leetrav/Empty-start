extends Control

## AU-03可独立试听：复用正式音乐消费者，仅人工输入Tier，不伪装为真实PK战斗。
const BOSS_IDS: Array[StringName] = [&"alien", &"kiwi", &"frog", &"fox"]
const MUSIC_INFO: Array[Array] = [
	["费米 · Teek Teek Teek", "n9de199487005"],
	["奥格尔 · 美哀 -Blai-", "ne4cf9e4749fe"],
	["咕拉 · 草原ダンスィング♪-RemakeVer-", "n6bce9b739300"],
	["列巴 · FELT LOVE", "n92c313450308"],
]
var _title: Label
var _credit: Label
var _music: TierMusicPresenter
var _status: Label
var _tier: int = 0
var _paused: bool = false
var _normal_pk: bool = true
var _phase: String = "普通PK试听"


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#141c29")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_music = TierMusicPresenter.new()
	add_child(_music)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 42)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 20)
	margin.add_child(rows)
	_title = _label(rows, "费米 · Teek Teek Teek", 38)
	var bosses := OptionButton.new()
	for info: Array in MUSIC_INFO:
		bosses.add_item(info[0])
	rows.add_child(bosses)
	bosses.item_selected.connect(_select_boss)
	_label(rows, "音乐试听场景：手动选择Tier；不运行或修改PK、感染规则。", 24)
	_label(rows, "T0静音 · T1开屏起引子并保持 · T2/T3中段 · T4/T5高段；直接选T1可试听降档低段", 24)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for tier in range(6):
		_button(buttons, "T%d" % tier, _set_tier.bind(tier))
	var opening := HBoxContainer.new()
	rows.add_child(opening)
	_button(opening, "开始连线/开场对白", _begin_connection)
	_button(opening, "开场对白结束", _finish_connection)
	_button(opening, "对白开始（列巴柔化）", _music.begin_connection_dialogue)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	_button(actions, "暂停 / 继续", _toggle_pause)
	_button(actions, "重开", _restart)
	_button(actions, "PK满 → 矛盾", _finish.bind(&"enter_contradiction"))
	_button(actions, "击破静音", _silence)
	_button(actions, "失败淡出", _finish.bind(&"failed"))
	_button(actions, "命中音效", AudioManager.play_event.bind(&"hit_normal"))
	_status = _label(rows, "", 26)
	_label(rows, "正式升档随箭头淡出换段；此页点Tier模拟放行。降档稳定2秒后等小节，同组不重播。", 22)
	_credit = _label(rows, "音乐：《Teek Teek Teek》
煉獄庭園 · 作曲/編曲：煉獄小僧
https://note.com/rengokuteien/n/n9de199487005", 21)
	_music.start_battle()


# 下拉试听切Boss时重置为T0，不改变正式游戏关卡或存档。
func _select_boss(index: int) -> void:
	_music.profile = BossMusicCatalog.find_profile(BOSS_IDS[index])
	_title.text = MUSIC_INFO[index][0]
	_credit.text = "音乐：%s\n煉獄庭園 · 作曲/編曲：煉獄小僧\nhttps://note.com/rengokuteien/n/%s" % [MUSIC_INFO[index][0], MUSIC_INFO[index][1]]
	_restart()


# 显示实际音乐组及阶段，避免把矛盾/结束状态误认为Tier请求已生效。
func _process(_delta: float) -> void:
	if _status != null:
		var names: Array[String] = ["柔和引子", "低段", "中段", "高段"]
		var current: String = names[clampi(_music.get_current_group(), 0, 3)]
		var target: String = names[clampi(_music.get_target_group(), 0, 3)]
		if AudioManager.get_music_event_id() == &"":
			current = "静音"
		if _music.is_waiting_for_connection():
			_phase = "黑屏等待：BGM静音"
			target = "等待连线"
		elif _music.is_opening_dialogue_active():
			_phase = "开场引子：持续到第二次升档，结束对白不换段"
			if _music.profile.entrance_event_id != &"" and AudioManager.get_music_event_id() == _music.profile.entrance_event_id:
				_phase = "连线出场：原曲开头；对白开始后再柔化"
				current = "原色出场"
		var selection: String = "当前选择 T%d" % _tier if _normal_pk else "点任一Tier可重新试听"
		_status.text = "%s  |  %s%s\n正在播放：%s → 目标：%s  |  音乐位置 %.2fs" % [
			selection, _phase, "（已暂停）" if _paused else "", current, target,
			AudioManager.get_music_position()]


# 矛盾、失败或静音后点Tier启动新一轮试听；正式战斗仍不接受结束后的Tier事件。
func _set_tier(tier: int) -> void:
	_tier = tier
	if not _normal_pk or not _music.owns_music():
		_normal_pk = true
		_phase = "普通PK试听"
		_paused = false
		_music.start_battle(tier)
	else:
		_music.request_tier(tier)
		# 独立试听没有玩法箭头，手动选档等价于该档箭头淡出；正式场景用真实信号。
		_music.release_tier_visual(tier)


# 试听专用剧情事件，生产场景由实际连线与对白完成信号驱动。
func _begin_connection() -> void:
	if not _normal_pk:
		_restart()
	_tier = 1
	_phase = "开场对白"
	_music.begin_connection()
	_music.request_tier(1)


func _finish_connection() -> void:
	_phase = "普通PK试听"
	_music.finish_connection_dialogue()


func _toggle_pause() -> void:
	_paused = not _paused
	_music.set_paused(_paused)


func _restart() -> void:
	_tier = 0
	_paused = false
	_normal_pk = true
	_phase = "普通PK试听"
	_music.start_battle()


func _finish(result: StringName) -> void:
	var was_normal: bool = _normal_pk
	if not was_normal and result == &"enter_contradiction":
		_music.start_battle(5)
	_normal_pk = false
	_paused = false
	_phase = "矛盾阶段：沿用高段" if result == &"enter_contradiction" else "失败：淡出音乐"
	_music.finish_battle(result)
	if not was_normal and result != &"enter_contradiction":
		_music.set_paused(false)
		AudioManager.fade_out_music()


func _silence() -> void:
	_normal_pk = false
	_paused = false
	_phase = "击破：静音"
	_music.set_paused(false)
	AudioManager.fade_to_silence()


func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(135, 64)
	button.pressed.connect(callback)
	AudioManager.bind_ui_button(button)
	parent.add_child(button)


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#e6edf3"))
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label
