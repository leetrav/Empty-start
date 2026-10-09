# 美术资产目录与交付台账

> 资源整理：2026-10-10。本表对应仓库当前已收到的 PNG；正式角色关卡绑定仍以关卡配置和策划确定的出场顺序为准。

## 目录
```text
assets/
├── characters/
│   ├── player/hamster_idle.png                      # 主角仓鼠，1 张
│   └── opponents/
│       ├── alien/                                   # 外星人：待机、Tier 01~03、击败过渡、击败（6 张）
│       ├── kiwi/                                    # Kiwi：待机、Tier 01~03、击败（5 张）
│       └── fox/                                     # 狐狸：待机、Tier 01~03、击败（5 张）
│           └── effects/                             # 四张独立玫瑰/花瓣部件（4 张）
├── environment/
│   ├── rooms/player_room_01.png                     # 主角房间
│   ├── rooms/kiwi_room.png                          # Kiwi 房间
│   └── live/player_live_temp.png                    # 临时玩家直播背景；原名 temporal
├── ui/
│   └── combat/
│       ├── pk_bar/                                  # 10 张分段 + 2 张指示器
│       ├── fan_badges/                              # 玩家粉丝牌 2 张
│       └── feedback/player_hit_comic_01.png          # 玩家受击漫画效果 1 张
├── fonts/                                           # 待交付
└── audio/                                           # 现有音频，目录保持原样
```

## 已接收清单

| 类别 | 内容 | PNG 数量 |
| --- | --- | ---: |
| 主角 | 仓鼠待机 | 1 |
| 对手 | 外星人：idle、tier_01~03、defeat_transition、defeat | 6 |
| 对手 | Kiwi：idle、tier_01~03、defeat | 5 |
| 对手 | 狐狸：idle、tier_01~03、defeat；独立玫瑰部件 01~04 | 9 |
| 背景 | 主角房间、Kiwi 房间、临时玩家直播背景 | 3 |
| PK 条 | neg_01~04、pos_01~06、pk_indicator_01~02 | 12 |
| 玩家粉丝牌 | player_fan_badge_01、02 | 2 |
| 受击漫画 | player_hit_comic_01 | 1 |
| **合计** | | **39** |

## 接入说明
- 主角固定立绘、临时直播背景、主角房间、粉丝牌 01 已映射至 `data/shared/presentation_asset_config.tres` 的现有字段。主角房间 `ui/rest/rest_room_environment.tscn` 同步更新路径。
- 对手待机及 Tier / 击败帧目前只有已导入图片。关卡模板仍是示例主播时，先保留资产清单，待策划确认出场关系后配置 `LevelProfile` 与状态贴图。
- 狐狸玫瑰 4 张位于 `assets/characters/opponents/fox/effects/`，是角色独立装饰部件。
- 外星人原 `defeat1` 与 `defeat2` 暂分别归为 `defeat_transition`、`defeat`；以美术最终标注为准。
- PK 条的原 -1~-4 和 1~6 数字原样保留为 `neg_01~04`、`pos_01~06`，方便按素材表建立各阶段对应关系；现阶段不推断它们与 Tier 的对应值。
- 两张玩家粉丝牌均保存。当前共享配置先引用 01，是否在正式弹幕和直播中显示，由后续策划 / UI 整合确认。
- 现有历史 `.png.import` 的 UID 随搬移保留并更新 source / dest 路径；其余 PNG 交由 Godot 下次导入时生成元数据。
- 日期日志中的旧资源路径属于历史交付记录，新任务使用本表和仓库最新 Resource 路径。

## 尚需美术交付（已提出）
- 房间背景：外星人、狐狸、蛙蛙。
- 角色：蛙蛙完整立绘组。
- UI：开始菜单、暂停菜单、身份卡片、败者卡片、圣典。
- 开场：封面、配合文案的漫画分镜。
- 字体：正式可商用字体文件及许可信息。

后续补充时按用途放入对应已有目录，新系统专属 UI 可在 `assets/ui/` 中增加对应模块目录。
