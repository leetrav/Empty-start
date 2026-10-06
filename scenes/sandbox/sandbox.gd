extends Control

const SAMPLE_LEVEL_CATALOG: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")
const SAMPLE_TIER_CATALOG: CombatStageTierCatalog = preload("res://data/combat_stage/tier_catalog.tres")
# Sandbox 技术验证暂用原始系统案的 PK 初始值；共享数值表接入后替换此来源。
const SANDBOX_INITIAL_PLAYER_PK: float = 0.5
const SANDBOX_MINIMUM_PLAYER_PK: float = 0.0
const SANDBOX_MAXIMUM_PLAYER_PK: float = 1.0

@onready var _barrage_area: BarrageArea = %BarrageArea
@onready var _aim_reticle: AimReticle = %AimReticle
@onready var _attack_charge_input: AttackChargeInput = %AttackChargeInput

var _hit_resolution: HitResolution
var _combat_stage: CombatStage


func _ready() -> void:
	# Sandbox 只组合本场所有者；PK 值和 Tier 状态分别留在各自系统对象中。
	%ReloadButton.pressed.connect(_on_reload_button_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	_hit_resolution = HitResolution.new(
		SANDBOX_INITIAL_PLAYER_PK,
		SANDBOX_MINIMUM_PLAYER_PK,
		SANDBOX_MAXIMUM_PLAYER_PK
	)
	_combat_stage = CombatStage.new(SAMPLE_TIER_CATALOG)
	_combat_stage.bind_hit_resolution(_hit_resolution)
	_combat_stage.begin_combat()
	_attack_charge_input.configure_target_query(_aim_reticle, _barrage_area)
	if not _attack_charge_input.configure_hit_resolution(_hit_resolution):
		push_error("Sandbox: 无法将本场 HitResolution 接入 CombatAttack。")
	_start_sample_barrage_generation()


func _start_sample_barrage_generation() -> void:
	# Sandbox 是当前游戏入口；用当前关配置启动普通生成演示。
	var run_state: LevelRunState = LevelRunState.new(SAMPLE_LEVEL_CATALOG)
	var current_level: LevelProfile = run_state.get_current_level_profile()
	if current_level == null:
		push_error("Sandbox: 当前没有普通关卡配置。")
		return
	if not _barrage_area.start_normal_generation(current_level):
		push_error("Sandbox: 无法启动普通弹幕生成。")


func _on_reload_button_pressed() -> void:
	# 通过 SceneRouter 重新加载当前 Sandbox 场景。
	var error: Error = SceneRouter.reload_current_scene()
	if error != OK:
		push_error("Sandbox: 当前场景重新加载失败，Error: %s" % error_string(error))


func _on_main_menu_button_pressed() -> void:
	# 通过 SceneRouter 返回主菜单。
	var error: Error = SceneRouter.goto_main_menu()
	if error != OK:
		push_error("Sandbox: 无法返回 MainMenu，Error: %s" % error_string(error))
