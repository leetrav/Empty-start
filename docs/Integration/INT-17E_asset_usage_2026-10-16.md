# INT-17E · 实际资产使用对照（2026-10-16）

## 已绑定的四关素材

来源02按level_order进入LevelCatalog；来源23按portrait_set_id绑定LevelProfile。下列已绑定项已通过Godot4.7.2真实Texture加载与1920×1080渲染；正式HUD组合/动画触发仍由D和INT-16验收。

| 源ID / 关卡 | 字段 | 实际文件 | Resource目标 | 状态 |
|---|---|---|---|---|
| portrait_alien / level_001 | idle_asset_path | `assets/characters/opponents/alien/alien_idle.png` | LevelProfile.streamer_portrait | 已绑定，实际渲染可见 |
| portrait_alien / level_001 | tier_01_asset_path | `assets/characters/opponents/alien/alien_tier_01.png` | LevelProfile.opponent_tier_01_portrait | 已绑定，实际渲染可见 |
| portrait_alien / level_001 | tier_02_asset_path | `assets/characters/opponents/alien/alien_tier_02.png` | LevelProfile.opponent_tier_02_portrait | 已绑定，实际渲染可见 |
| portrait_alien / level_001 | tier_03_asset_path | `assets/characters/opponents/alien/alien_tier_03.png` | LevelProfile.opponent_tier_03_portrait | 已绑定，实际渲染可见 |
| portrait_alien / level_001 | defeat_asset_path | `assets/characters/opponents/alien/alien_defeat.png` | LevelProfile.opponent_defeat_portrait | 已绑定，实际渲染可见 |
| portrait_alien / level_001 | defeat_transition_asset_path | `assets/characters/opponents/alien/alien_defeat_transition.png` | LevelProfile.opponent_defeat_transition_portrait | 已绑定，实际渲染可见 |
| level_001 / alien | 02.background_asset_id空；按既有同名目录回退 | `assets/environment/live/alien/background.png` | LevelProfile.streamer_live_background | 已绑定 |
| portrait_alien | defeat_effect_id | `alien_melt` | LevelProfile.opponent_defeat_effect_id | 稳定ID已交付，动画由表现Owner消费 |
| portrait_kiwi / level_002 | idle_asset_path | `assets/characters/opponents/kiwi/kiwi_idle.png` | LevelProfile.streamer_portrait | 已绑定，实际渲染可见 |
| portrait_kiwi / level_002 | tier_01_asset_path | `assets/characters/opponents/kiwi/kiwi_tier_01.png` | LevelProfile.opponent_tier_01_portrait | 已绑定，实际渲染可见 |
| portrait_kiwi / level_002 | tier_02_asset_path | `assets/characters/opponents/kiwi/kiwi_tier_02.png` | LevelProfile.opponent_tier_02_portrait | 已绑定，实际渲染可见 |
| portrait_kiwi / level_002 | tier_03_asset_path | `assets/characters/opponents/kiwi/kiwi_tier_03.png` | LevelProfile.opponent_tier_03_portrait | 已绑定，实际渲染可见 |
| portrait_kiwi / level_002 | defeat_asset_path | `assets/characters/opponents/kiwi/kiwi_defeat.png` | LevelProfile.opponent_defeat_portrait | 已绑定，实际渲染可见 |
| portrait_kiwi / level_002 | defeat_transition_asset_path | `空` | LevelProfile.opponent_defeat_transition_portrait | 源字段为空（未补造过渡帧） |
| level_002 / kiwi | 02.background_asset_id空；按既有同名目录回退 | `assets/environment/live/kiwi/background.png` | LevelProfile.streamer_live_background | 已绑定 |
| portrait_kiwi | defeat_effect_id | `kiwi_wobble` | LevelProfile.opponent_defeat_effect_id | 稳定ID已交付，动画由表现Owner消费 |
| portrait_frog / level_003 | idle_asset_path | `assets/characters/opponents/frog/frog_idle.png` | LevelProfile.streamer_portrait | 已绑定，实际渲染可见 |
| portrait_frog / level_003 | tier_01_asset_path | `assets/characters/opponents/frog/frog_tier_01.png` | LevelProfile.opponent_tier_01_portrait | 已绑定，实际渲染可见 |
| portrait_frog / level_003 | tier_02_asset_path | `assets/characters/opponents/frog/frog_tier_02.png` | LevelProfile.opponent_tier_02_portrait | 已绑定，实际渲染可见 |
| portrait_frog / level_003 | tier_03_asset_path | `assets/characters/opponents/frog/frog_tier_03.png` | LevelProfile.opponent_tier_03_portrait | 已绑定，实际渲染可见 |
| portrait_frog / level_003 | defeat_asset_path | `assets/characters/opponents/frog/frog_defeat.png` | LevelProfile.opponent_defeat_portrait | 已绑定，实际渲染可见 |
| portrait_frog / level_003 | defeat_transition_asset_path | `空` | LevelProfile.opponent_defeat_transition_portrait | 源字段为空（未补造过渡帧） |
| level_003 / frog | 02.background_asset_id空；按既有同名目录回退 | `assets/environment/live/frog/background.png` | LevelProfile.streamer_live_background | 已绑定 |
| portrait_frog | defeat_effect_id | `空` | LevelProfile.opponent_defeat_effect_id | 策划/美术缺口：源表明确尚未验收 |
| portrait_fox / level_004 | idle_asset_path | `assets/characters/opponents/fox/fox_idle.png` | LevelProfile.streamer_portrait | 已绑定，实际渲染可见 |
| portrait_fox / level_004 | tier_01_asset_path | `assets/characters/opponents/fox/fox_tier_01.png` | LevelProfile.opponent_tier_01_portrait | 已绑定，实际渲染可见 |
| portrait_fox / level_004 | tier_02_asset_path | `assets/characters/opponents/fox/fox_tier_02.png` | LevelProfile.opponent_tier_02_portrait | 已绑定，实际渲染可见 |
| portrait_fox / level_004 | tier_03_asset_path | `assets/characters/opponents/fox/fox_tier_03.png` | LevelProfile.opponent_tier_03_portrait | 已绑定，实际渲染可见 |
| portrait_fox / level_004 | defeat_asset_path | `assets/characters/opponents/fox/fox_defeat.png` | LevelProfile.opponent_defeat_portrait | 已绑定，实际渲染可见 |
| portrait_fox / level_004 | defeat_transition_asset_path | `空` | LevelProfile.opponent_defeat_transition_portrait | 源字段为空（未补造过渡帧） |
| level_004 / fox | 02.background_asset_id空；按既有同名目录回退 | `assets/environment/live/fox/background.png` | LevelProfile.streamer_live_background | 文件缺失，保持null |
| portrait_fox | defeat_effect_id | `fox_petal_rain` | LevelProfile.opponent_defeat_effect_id | 稳定ID已交付，动画由表现Owner消费 |

Tier映射继续沿用既有HUD：T1/2使用idle及汗滴，T3～5对应tier_01～03；本次仅交付贴图和稳定ID。Kiwi/Fox/Frog未配置专用过渡帧不等同于必须新增贴图；现有程序动效由表现Owner决定。

## 主角与前景

| 实际文件 | 已绑定公开字段 | 状态 |
|---|---|---|
| `assets/characters/player/hamster_idle.png` | `PresentationAssetConfig.player_streamer_portrait/player_streamer_avatar` | 已存在并绑定 |
| `assets/environment/live/hamster/background.png` | `PresentationAssetConfig.player_live_background` | 已存在并绑定 |
| `assets/environment/live/hamster/foreground_desk.png` | `PresentationAssetConfig.player_live_foreground` | 已存在并绑定 |
| `assets/environment/player_room/background.png` | `PresentationAssetConfig.player_room_background` | 已存在并绑定 |
| `assets/ui/combat/fan_badges/player_fan_badge_01.png` | `PresentationAssetConfig.player_fan_badge` | 已存在并绑定 |
| `assets/environment/live/frog/foreground_cutout.png` | `level_003.streamer_live_foreground` | 已存在并绑定 |

## 18 台账逐ID核实

仅提取备注中明确出现且实际存在的路径，以及源码/Resource中的字面ID引用。字面引用只证明存在消费候选，真实画面不得据此标PASS。target_folder/status绝不作为资源路径。

| asset_id | 台账状态 | 实际路径 / 字面ID引用证据 |
|---|---|---|
| portrait_player_default | in_repo | 文件 `assets/characters/player/hamster_idle.png` |
| avatar_player_default | in_repo | 文件 `assets/characters/player/hamster_idle.png` |
| icon_identity_orthodox | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_identity_heresy | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_identity_absurd | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| ui_identity_states | implemented_code | 文件 `ui/identity_setup/identity_selection.gd` |
| ui_name_input | implemented_code | 文件 `ui/identity_setup/identity_selection.gd` |
| barrage_bubble_normal | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| barrage_tendency_marks | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| barrage_fan_badges | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| barrage_strength_styles | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| barrage_special_styles | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| trait_markers | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_blocked | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_fake_badge | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_censor | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_split | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_reflect | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| trait_stack_style | implemented_code | 文件 `systems/barrage_generation/barrage_special_surface.gd` |
| aim_reticle | implemented_code | 文件 `systems/combat_attack/aim_reticle.gd`；ID引用 `core/combat/battle_attempt_flow.gd`；ID引用 `systems/combat_attack/aim_reticle.tscn`；ID引用 `systems/combat_attack/attack_charge_input.gd`；ID引用 `scenes/demos/pa08_reticle_demo.tscn` |
| charge_indicator | implemented_code | 文件 `systems/combat_attack/aim_reticle.gd` |
| projectile_word | implemented_code | 文件 `systems/combat_attack/attack_charge_input.gd`；文件 `systems/presentation/barrage_impact_presenter.gd` |
| hit_effect | in_repo | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| combat_anomaly_effects | implemented_code | 文件 `systems/combat_attack/attack_charge_input.gd`；文件 `systems/presentation/barrage_impact_presenter.gd` |
| pk_bar | in_repo | ID引用 `core/combat/battle_attempt_flow.gd`；ID引用 `core/combat/combat_stage.gd`；ID引用 `core/contradiction_oracle/contradiction_oracle_flow.gd`；ID引用 `core/divine_descent/divine_descent_combat_mode.gd` |
| pk_endpoint_avatars | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| tier_markers | implemented_code | 文件 `systems/presentation/stage_arrow_fx.gd` |
| pk_critical_states | implemented_code | 文件 `systems/presentation/stage_arrow_fx.gd` |
| tier_high_distortion | implemented_code | 文件 `systems/presentation/stage_arrow_fx.gd` |
| battle_fail_screen | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| stream_offline_state | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| tier_ui_states | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| tier_character_states | in_repo | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| tier_background_states | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| tier_font_styles | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_viewers | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_likes | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_comments | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| icon_fans | partial | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| live_data_layout | implemented_code | 文件 `ui/live_data/live_data_hud.gd` |
| live_data_hot_effect | implemented_code | 文件 `ui/live_data/live_data_hud.gd` |
| repeat_player_badge | in_repo | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| repeat_low_style | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| repeat_high_style | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| repeat_fake_badge_diff | implemented_code | 文件 `systems/barrage_generation/barrage_view.gd` |
| contradiction_bubble | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| contradiction_stage_banner | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| contradiction_timer | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| contradiction_break_screen | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| oracle_candidate_layout | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| oracle_select_states | implemented_code | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| oracle_fullscreen_repeat | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| assimilation_gain_ui | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| assimilation_conquered_mark | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| assimilation_source_style | verify_needed | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |
| ending_art_orthodox | needs_asset | 台账无可核实文件引用；待Owner给出实际路径/消费入口 |

## 最短补齐清单及源ID

1. `02.level_004` / `23.portrait_fox`：Fox直播背景实物文件未发现；02四条background_asset_id均空，前三关复用已有目录实物，Fox保持null。
2. `23.portrait_frog.defeat_effect_id`：空；源备注写明专属动效未人工验收。其5张立绘均已绑定。
3. `16.religion_name:<primary>:<secondary>`九组合、`16.judgement:{no_behavior,tie,consistent,shifted}`四分类均是占位；生产配置保留空。`16.main_art:{orthodox,heresy,absurd}`三个asset_id无文件映射。
4. 独立通关漫画没有源表行或已入库实物。交付 `data/ending/ending_comic.tres`（ComicSequence.frames空）；不会复用 `data/comics/ending.tres`，后者仍是开场P5/P6。已有独立漫画后直接编辑本Resource，复导保留。
5. `17.music_battle_t0`～`music_battle_t5`的asset_path_or_id全空。08稳定事件ID已同步，音频Owner填真实音乐路径后按已有register_audio_events注册；请求事件本身不代表可听到正式分层音乐。
6. 17共有73事件：23条已填路径、50条空；逐字段报告保留全部ID。13五条奖励/14四张卡全部disabled，等待正式配置批准后启用；本卡保持零奖励，不把缺收藏阻断结局。
7. 01十二身份icon_asset_id、02四关fan_badge_asset_id均空，现有文字身份与通关仍可运行。可选资产由策划补配后复导，不生成假图。

## INT-16 / D 最小接线位置

- 普通关加载后：读取选中 `LevelProfile` 的已有portrait字段、`streamer_live_background`、新增 `streamer_live_foreground` / `opponent_defeat_effect_id`；通过既有HUD公开呈现入口组合，不从字段审计报告读取运行数据。
- 玩家直播区域：读取 `data/shared/presentation_asset_config.tres.player_live_foreground`（与背景分层）；E未修改HUD/根流程。
- 真正击败奖励候选只读 `LevelProfile.assimilation_rewards`，13禁用时数组空；登记/去重继续用现有FO/Assimilation/LoserCard业务入口。
- 神降临完成后沿用 `EndingSession.receive_final_state` → `SceneRouter.goto_ending(session)`；独立ComicSequence.frames为空时直接结局。未来有通关漫画时由INT-16为ComicPlayer增加显式独立序列入口；当前goto_comic("ending")仍是开场后半段，不能用于通关。

## 真实证据（本机D盘，未入Git）

- `D:\tmp\int17e-media-20261016\production-resources-1920x1080.png`：Godot4.7.2 Compatibility实机TextureRect渲染，含四关各阶段贴图、缺Fox背景、主角及前景。只证明素材加载，未验证正式战斗流程。
- 复播脚本：`D:\tmp\int17e-media-resource-preview.gd`；运行 `godot --path <本Lane工程> --rendering-method gl_compatibility --resolution 1920x1080 --script D:/tmp/int17e-media-resource-preview.gd`。
- `D:\tmp\int17e-render.out.log` / `.err.log`：退出0、`INT-17E REAL RENDER: 0`，stderr空。

完整逐字段报告：[27表审计](R26-E_01-04-13-14-18-23_importer_audit.md)。
