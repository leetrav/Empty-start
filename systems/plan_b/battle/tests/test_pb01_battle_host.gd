extends Node

const DEMO_SCENE: PackedScene = preload("res://scenes/plan_b/fermi_battle_demo.tscn")

var _failures: Array[String] = []
var _battle_end_results: Array[StringName] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var demo: Control = DEMO_SCENE.instantiate()
	add_child(demo)
	var host: PlanBBattleHost = demo.get_node("BattleHost")
	var simulation: PlanBPrototypeSimulation = demo.get_node("BattleHost/Simulation")
	host.battle_ended.connect(_on_battle_ended)
	simulation.initial_neutral_count = 4
	simulation.initial_opponent_count = 0
	simulation.neutral_spawn_interval_seconds = 999.0
	host.opponent_auto_publish_enabled = false
	host.start_battle(Vector2(360.0, 220.0))

	var invalid_target: Dictionary = host.publish_word("player", "player_a_01", "missing_viewer")
	_check(not bool(invalid_target.get("ok", true)), "无效目标必须拒绝发表")
	_check(host.get_used_word_ids().is_empty(), "失败发表不能占用话语")
	var first_publish: Dictionary = host.publish_word("player", "player_a_01", "viewer_001")
	_check(bool(first_publish.get("ok", false)), "有效玩家发表应成功")
	_check(int(first_publish.get("word_order", 0)) == 1, "首个成功发表应取得全局顺序1")
	var duplicate_word: Dictionary = host.publish_word("player", "player_a_01", "viewer_002")
	_check(StringName(duplicate_word.get("reason", &"")) == &"word_already_used", "重复词应被拒绝")
	var player_cooldown: Dictionary = host.publish_word("player", "player_b_01", "viewer_002")
	_check(StringName(player_cooldown.get("reason", &"")) == &"cooldown", "发表冷却期间应拒绝新词")
	_check(not host.get_used_word_ids().has("player_b_01"), "冷却失败不能占用话语")
	var player_counts: Dictionary = host.get_faction_counts()
	_check(int(player_counts.get("player", 0)) == 1, "成功发表只播种一名玩家棋子")
	_check(int(player_counts.get("neutral", 0)) == 3, "成功发表不会创建新棋子")
	var pk_before_player_advantage: float = host.get_pk()
	host.update_pk(0.1)
	_check(host.get_pk() > pk_before_player_advantage, "玩家棋子更多时PK应向100%变化")
	host.update_battle(5.1)
	var player_retry: Dictionary = host.publish_word("player", "player_b_01", "viewer_002")
	_check(bool(player_retry.get("ok", false)), "冷却失败后的同一句话可在冷却结束后发表")
	_check(int(player_retry.get("word_order", 0)) == 2, "失败发表不占用全局顺序号")

	var second_publish: Dictionary = host.publish_word("opponent", "opponent_a_01", "viewer_003")
	_check(bool(second_publish.get("ok", false)), "对手应复用同一个发表入口")
	_check(int(second_publish.get("word_order", 0)) == 3, "双方共用递增顺序号")
	var opponent_cooldown: Dictionary = host.publish_word("opponent", "opponent_b_01", "viewer_004")
	_check(StringName(opponent_cooldown.get("reason", &"")) == &"cooldown", "对手也受发表冷却规则约束")
	host.update_battle(11.5)
	var opponent_retry: Dictionary = host.publish_word("opponent", "opponent_b_01", "viewer_004")
	_check(bool(opponent_retry.get("ok", false)), "对手冷却结束后可发表新词")
	_check(int(opponent_retry.get("word_order", 0)) == 4, "失败发表不会占用双方共用顺序号")
	var equal_pk: float = host.get_pk()
	host.update_pk(5.0)
	_check(is_equal_approx(host.get_pk(), equal_pk), "双方棋子人数相等时PK保持不变")

	host.pause_battle()
	var paused_publish: Dictionary = host.publish_word("player", "player_b_01", "viewer_003")
	_check(StringName(paused_publish.get("reason", &"")) == &"battle_not_running", "暂停期间不能发表")
	_check(host.get_used_word_ids().size() == 4, "暂停失败发表不得改变已用词集合")

	simulation.initial_neutral_count = 1
	simulation.initial_opponent_count = 0
	host.restart_battle(Vector2(360.0, 220.0))
	var winning_publish: Dictionary = host.publish_word("player", "player_c_01", "viewer_001")
	_check(int(winning_publish.get("word_order", 0)) == 1, "重开后全局顺序从1重新开始")
	host.update_pk(60.0)
	_check(is_equal_approx(host.get_pk(), 100.0), "PK应钳制在100%")
	_check(
		not _battle_end_results.is_empty() and _battle_end_results.back() == &"enter_contradiction",
		"PK到100%应发送进入矛盾阶段事实"
	)

	simulation.initial_neutral_count = 0
	simulation.initial_opponent_count = 1
	host.restart_battle(Vector2(360.0, 220.0))
	host.update_pk(60.0)
	_check(is_equal_approx(host.get_pk(), 0.0), "PK应钳制在0%")
	_check(_battle_end_results.back() == &"failed", "PK到0%应发送失败事实")

	if _failures.is_empty():
		print("PASS PB-01: publish/order/cooldown-boundaries/PK-tier-end facts")
	else:
		for failure: String in _failures:
			push_error("FAIL PB-01: %s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_battle_ended(result: StringName) -> void:
	_battle_end_results.append(result)
