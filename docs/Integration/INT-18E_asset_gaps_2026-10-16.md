# INT-18E · 真人交付最短素材缺口（2026-10-16）

核对基线：main 762b8a1；本卡只补已存在程序绘制的台账ID。没有生成图片、音乐或正式故事文案。源表空值与已有代码绘制分别列出。

## 优先交付

| 源表/ID | 缺口 | 交付后接入位置 |
|---|---|---|
| 02.level_004 / 23.portrait_fox | Fox直播背景未发现实物，background_asset_id为空 | 明确PNG路径填02，再approved-csv；LevelProfile.streamer_live_background |
| 16.main_art:orthodox / heresy / absurd | 三张结局图只有ending_art_*符号，无文件 | 16.asset_id填实际路径，复导现有EndingMainArtConfig |
| 独立通关漫画 | 没有正式序列/实物资源 | data/ending/ending_comic.tres；A负责显式路由，开场P5/P6保持原用途 |
| 23.portrait_frog.defeat_effect_id | 源表为空，专属效果未人工验收 | 由D/真人确定素材与ID；已有5张立绘保持可用 |

## 结局文字：九教名与四判词

下列源值仍是策划占位；生产配置过滤为空，页面沿用已有空态。请按同一行填写正式文本后复导，不需要改分类器。

| 16行组合 | 当前源值 |
|---|---|
| religion_name:orthodox:orthodox | 名称占位1 |
| religion_name:orthodox:heresy | 名称占位2 |
| religion_name:orthodox:absurd | 名称占位3 |
| religion_name:heresy:orthodox | 名称占位4 |
| religion_name:heresy:heresy | 名称占位5 |
| religion_name:heresy:absurd | 名称占位6 |
| religion_name:absurd:orthodox | 名称占位7 |
| religion_name:absurd:heresy | 名称占位8 |
| religion_name:absurd:absurd | 名称占位9 |
| judgement::no_behavior | 描述占位1 |
| judgement::tie | 描述占位2 |
| judgement::consistent | 描述占位3 |
| judgement::shifted | 描述占位4 |

## 17：50个缺路径事件（六档音乐列在其中）

现有23条非空路径已在Godot源工程及实际Windows PCK中加载/解码成功；这证明资源可用，生产触发与听感由D/真人验收。下列ID没有正式路径，不自动匹配相似音效。

| event_id | 类型 | 当前状态 |
|---|---|---|
| live_start_transition | sfx | 源路径空 |
| streamer_intro | sfx | 源路径空 |
| mechanic_reveal | sfx | 源路径空 |
| barrage_strength_high | sfx | 源路径空 |
| barrage_special | sfx | 源路径空 |
| trait_copy | sfx | 源路径空 |
| trait_reflect | sfx | 源路径空 |
| trait_blocked | sfx | 源路径空 |
| trait_unselectable | sfx | 源路径空 |
| aim_target | ui | 源路径空 |
| attack_miss | sfx | 源路径空 |
| attack_reflect | sfx | 源路径空 |
| pk_push | sfx | 源路径空 |
| pk_retreat | sfx | 源路径空 |
| pk_retreat_big | sfx | 源路径空 |
| pk_danger | sfx | 源路径空 |
| pk_full | sfx | 源路径空 |
| pullback_pressure | sfx | 源路径空 |
| player_near_fail | sfx | 源路径空 |
| battle_fail_transition | sfx | 源路径空 |
| tier_down | sfx | 源路径空 |
| tier_high_ambience | sfx | 源路径空 |
| live_viewer_milestone | sfx | 源路径空 |
| live_fan_gain | sfx | 源路径空 |
| live_break_burst | sfx | 源路径空 |
| repeat_crowd | sfx | 源路径空 |
| repeat_flood | sfx | 源路径空 |
| contradiction_spawn | sfx | 源路径空 |
| contradiction_false_hit | sfx | 源路径空 |
| contradiction_emphasis | sfx | 源路径空 |
| oracle_candidates | sfx | 源路径空 |
| oracle_select_move | ui | 源路径空 |
| oracle_collapse | sfx | 源路径空 |
| assimilation_complete | sfx | 源路径空 |
| assimilation_trait_unlock | sfx | 源路径空 |
| music_menu_opening | music | 源路径空 |
| music_battle_t0 | music | 六档正式音乐缺Stream |
| music_battle_t1 | music | 六档正式音乐缺Stream |
| music_battle_t2 | music | 六档正式音乐缺Stream |
| music_battle_t3 | music | 六档正式音乐缺Stream |
| music_battle_t4 | music | 六档正式音乐缺Stream |
| music_battle_t5 | music | 六档正式音乐缺Stream |
| music_failure | music | 源路径空 |
| music_restart | music | 源路径空 |
| music_contradiction | music | 源路径空 |
| music_oracle | music | 源路径空 |
| music_oracle_confirm | music | 源路径空 |
| music_assimilation | music | 源路径空 |
| music_divine_descent | music | 源路径空 |
| music_ending | music | 源路径空 |

音乐Owner按稳定music_battle_t0～t5分别交付已批准文件；A已提供音乐请求，空Stream仍不能播放。23项既有音频不等于50项缺口已补齐。

## 07：特性资产与实际消费者

| trait_id | visual_asset_id | 18台账 / 实物 | 实际现有表现入口 / 剩余 |
|---|---|---|---|
| occlusion | trait_blocked | implemented_code；无独立PNG | BarrageSpecialSurface._draw_metal；铁质遮挡为程序绘制 |
| retaliation_copy | trait_retaliation | implemented_code；无独立PNG | BarrageSpecialSurface._draw_retaliation_panel；本卡补对应18台账原ID |
| fake_card | trait_fake | implemented_code；无独立PNG | BarrageSpecialSurface._draw_fake_repeat；本卡补对应18台账原ID |
| unselectable | trait_unselectable | 精确ID台账缺失；无独立PNG | 07规则存在，18缺trait_unselectable精确行；当前普通气泡缺专用已验收不可选视觉。需C/D/真人决定后交付 |
| split | trait_split | implemented_code；无独立PNG | BarrageSpecialSurface._draw_cracked_glass；程序裂纹与实际分裂由既有组件提供 |
| reflect | trait_reflect | implemented_code；无独立PNG | BarrageSpecialSurface._draw_jelly；果冻程序绘制 |

retaliation/fake两条台账只说明已有代码可绘制；status未宣称人工美术PASS。没有把implemented_code当Texture路径，也没有新增PNG替代缺素材。

## 已存在且已绑定：无需重复制作

- 四关各idle、Tier1～3、defeat图片，Alien独立过渡图；前三关背景、Frog前景。
- 主角hamster_idle、直播背景、foreground_desk与房间背景、现有粉丝牌。
- 两套正式中文字体：NotoSansSC-VF、ZCOOLKuaiLe-Regular；Godot实际验证“神”字形。
- 13五条奖励/14四卡全disabled，保持零正式奖励；这属于策划禁用，未列为必须制作的视觉阻断。

[INT-17E完整文件对照](INT-17E_asset_usage_2026-10-16.md)保留原路径；[本轮出包日志](INT-18E_2026-10-16_log.md)记录真实包内检查与最终包阻断。
