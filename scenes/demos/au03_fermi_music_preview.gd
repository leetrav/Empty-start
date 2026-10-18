extends Control

## AU-03可独立试听：复用正式音乐消费者，仅人工输入Tier，不伪装为真实PK战斗。
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
	_label(rows, "费米 · Teek Teek Teek", 38)
	_label(rows, "音乐试听场景：手动选择Tier；不运行或修改PK、感染规则。", 24)
	_label(rows, "T0/T1 低段   ·   T2/T3 中段   ·   T4/T5 高段", 24)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for tier in range(6):
		_button(buttons, "T%d" % tier, _set_tier.bind(tier))
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	_button(actions, "暂停 / 继续", _toggle_pause)
	_button(actions, "重开", _restart)
	_button(actions, "PK满 → 矛盾", _finish.bind(&"enter_contradiction"))
	_button(actions, "击破静音", _silence)
	_button(actions, "失败淡出", _finish.bind(&"failed"))
	_button(actions, "命中音效", AudioManager.play_event.bind(&"hit_normal"))
	_status = _label(rows, "", 26)
	_label(rows, "升档跨组等下一小节；降档稳定2秒后等下一小节；交叉淡化0.6秒。", 22)
	_label(rows, "音乐：《Teek Teek Teek》
煉獄庭園 · 作曲/編曲：煉獄小僧
https://note.com/rengokuteien/n/n9de199487005", 21)
	_music.start_battle()


# 显示实际音乐组及阶段，避免把矛盾/结束状态误认为Tier请求已生效。
func _process(_delta: float) -> void:
	if _status != null:
		var names: Array[String] = ["低段", "中段", "高段"]
		var current: String = names[clampi(_music.get_current_group(), 0, 2)]
		var target: String = names[clampi(_music.get_target_group(), 0, 2)]
		if AudioManager.get_music_event_id() == &"":
			current = "静音"
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
