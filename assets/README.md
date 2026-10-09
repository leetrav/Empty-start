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
- 对手待机及多档变化/击败帧目前已经入库。文件名中的 `tier_01~03` 表示**美术提供的三个变化版本**，不是实际战斗 T1/T2/T3，实际阶段映射以如下表格为准。当前关卡模板仍是示例主播，不据此猜测外星人、Kiwi、狐狸的关卡出场顺序。
- 狐狸玫瑰 4 张位于 `assets/characters/opponents/fox/effects/`，是角色独立装饰部件。
- 外星人原 `defeat1` 与 `defeat2` 暂分别归为 `defeat_transition`、`defeat`；以美术最终标注为准。
- PK 条来源编号 1~6 保留为 `pos_01~06`，来源编号 -1~-4 保留为 `neg_01~04`；0 号素材当前**未收到**，具体见下表。
- 两张玩家粉丝牌均保存。当前共享配置先引用 01，是否在正式弹幕和直播中显示，由后续策划 / UI 整合确认。
- 现有历史 `.png.import` 的 UID 随搬移保留并更新 source / dest 路径；其余 PNG 交由 Godot 下次导入时生成元数据。
- 日期日志中的旧资源路径属于历史交付记录，新任务使用本表和仓库最新 Resource 路径。

## 已确认：对手立绘与战斗阶段（2026-10-10）

以下三名对手（alien、kiwi、fox）共用同一套**运行阶段到美术版本**的映射：

| 运行阶段 | 立绘版本 | 对应现有文件 |
| --- | --- | --- |
| T0 | 对手未接入，不展示立绘 | 无 |
| T1 | 待机 | `{alien/kiwi/fox}_idle.png` |
| T2 | 美术变化版本 1 | `{alien/kiwi/fox}_tier_01.png` |
| T3 | 同 T2，继续使用变化版本 1 | `{alien/kiwi/fox}_tier_01.png` |
| T4 | 美术变化版本 2 | `{alien/kiwi/fox}_tier_02.png` |
| T5 | 美术变化版本 3 | `{alien/kiwi/fox}_tier_03.png` |
| 矛盾击破（Paradox） | 击败状态 | `{alien/kiwi/fox}_defeat.png` |

外星人另有 `alien_defeat_transition.png`（击败过渡帧），可接在击败正式立绘之前；具体使用时序以正式演出确认结果为准。

## 已确认：PK 条素材来源编号与阶段（2026-10-10）

| 来源编号 | 运行意义 | 当前文件 |
| --- | --- | --- |
| 0 | T0 | **0 号图尚未交付**，由现有 UI / 底板暂时代替，待美术确认 |
| 1 | T1 | `assets/ui/combat/pk_bar/pk_bar_pos_01.png` |
| 2 | T2 | `assets/ui/combat/pk_bar/pk_bar_pos_02.png` |
| 3 | T3 | `assets/ui/combat/pk_bar/pk_bar_pos_03.png` |
| 4 | T4 | `assets/ui/combat/pk_bar/pk_bar_pos_04.png` |
| 5 | T5 | `assets/ui/combat/pk_bar/pk_bar_pos_05.png` |
| 6 | Paradox / T6 | `assets/ui/combat/pk_bar/pk_bar_pos_06.png` |
| -4 | 玩家 PK 0%～10% | `pk_bar_neg_04.png` |
| -3 | 玩家 PK 10%～20% | `pk_bar_neg_03.png` |
| -2 | 玩家 PK 20%～30% | `pk_bar_neg_02.png` |
| -1 | 玩家 PK 30%～40% | `pk_bar_neg_01.png` |

- 负向素材 -4～-1 与玩家 PK **0%～10%、10%～20%、20%～30%、30%～40%** 的四段对应关系已由策划确认。边界具体包含方式由 PK 显示代码统一处理，保证数值变化时只显示一张正确档位图。
- `pk_indicator_01.png` 为 PK 条**默认笑脸仓鼠球**，`pk_indicator_02.png` 为**仅降档时短暂出现的惊慌仓鼠球**。二者使用同一个指示器位置：按玩家 PK 比例沿轨道移动，移动时伴随自身滚动；升档时笑脸蹦跳，降档时惊慌脸抖动蹦跳、结束恢复笑脸。接入详见 [PA-13](../docs/Shared/PresentationAssets/tasks/PA-13_pk-hamster-ball-indicator-animation.md)。

## 可由程序美术交付

- 双主播对话气泡：可用 Godot `Control._draw()` 绘制底板、描边和可左右调整的尖尾，使用 `RichTextLabel` 加载对白、Tween 上浮与淡出。复用 SD-02 现有显示组件及 SD-03 的队列时序；正式字体后接 Theme，可保留气泡贴图替换入口。

## 尚需美术交付（已提出）
- 房间背景：外星人、狐狸、蛙蛙。
- 角色：蛙蛙完整立绘组。
- UI：开始菜单、暂停菜单、身份卡片、败者卡片、圣典。
- 开场：封面、配合文案的漫画分镜。
- 字体：正式可商用字体文件及许可信息。

后续补充时按用途放入对应已有目录，新系统专属 UI 可在 `assets/ui/` 中增加对应模块目录。
