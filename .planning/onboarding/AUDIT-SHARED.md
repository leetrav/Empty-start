# Onboarding Audit: Shared / Integration / Original / Delivery

日期：2026-10-08。

本次核查为静态、只读工程审计。未运行测试、未启动 Godot、未修改代码。文中“已验证”“通过”若来自任务日志，均为历史验证记录，不能当作本次运行结果。本文件为唯一写入的文档成果。

## PROJECT 可用事实

- 项目目标为 2026 TapTap 聚光灯 GameJam；优先可运行核心玩法和一局从开始走到结束的完整流程，再增加内容与表现。依据：[AGENTS.md](D:/Godot/Empty-start/AGENTS.md:11)。
- 完整流程意图：玩家填写主播名、选择正统／异端／荒谬身份；直播 PK 中蓄力发射言弹、命中话语并引发复读；PK 满后寻找真矛盾。成功击破后选择神谕、取得经文与击败成果，未击破仍推进；休息后继续关卡，全部结束进入神降临，最终展示教派、圣典与身份判词。依据：[程序需求汇总.md](D:/Godot/Empty-start/docs/Original/程序需求汇总.md)。
- 当前入口为 `project.godot → Boot → SceneRouter.goto_main_menu() → 开始游戏/new_game() → 身份设置 → goto_game() → Sandbox`。依据：[project.godot](D:/Godot/Empty-start/project.godot:13)、[boot.gd](D:/Godot/Empty-start/core/boot/boot.gd)、[scene_router.gd](D:/Godot/Empty-start/core/autoload/scene_router.gd)、[main_menu.gd](D:/Godot/Empty-start/ui/main_menu/main_menu.gd:17)、[identity_setup.gd](D:/Godot/Empty-start/ui/identity_setup/identity_setup.gd:167)。
- Godot 工程特性配置为 4.7；完成日志记录实际使用 4.7.2，语言 GDScript；任务卡目标平台 Windows／Android。默认画布 1920×1080，Windows 驱动配置 D3D12。
- 没有正式游戏名称或截止日期证据；主菜单标题仍为 `Empty-start`。任务日志日期不等于项目截止日期。
- Original 有三份实质性需求：系统案文本导出、程序需求汇总、美术需求汇总。系统案文本导出实际覆盖系统 1～14，程序与美术汇总覆盖至20。任务卡模板只作为工作方式参考。来源：[Original 系统案](D:/Godot/Empty-start/docs/Original/系统案_协作交付版_文本导出.md)、[程序需求汇总](D:/Godot/Empty-start/docs/Original/程序需求汇总.md)、[美术需求汇总](D:/Godot/Empty-start/docs/Original/美术需求汇总.md)、[任务卡模板](D:/Godot/Empty-start/docs/Original/任务卡模板.md)。

## 已完成任务与证据

| 任务卡 | 完成范围与历史验证 | 证据 |
| --- | --- | --- |
| INT-01 | 普通战斗组合、鼠标蓄力、PK/Tier、回拉、复读、评论、倾向、暂停、失败重开；历史84/84场景回归通过 | [INT-01日志](D:/Godot/Empty-start/docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md) |
| INT-02 | Scene 保存实际布局，HUD整体缩放；布局规格与 Scene 同步；首轮84/84回归记录通过。日志最后的纯绘制顺序补正曾未重新运行，后续PA-03另有当前HUD运行与画面检查记录 | [INT-02日志](D:/Godot/Empty-start/docs/Integration/Sandbox布局_INT-02_2026-10-06_log.md)、[Shared README](D:/Godot/Empty-start/docs/Shared/README.md:17) |
| INT-03 | 左右共用四项富文本HUD，玩家绑定真实数据，敌方显式四项0；Windows两种尺寸检查和84/84回归记录通过 | [INT-03日志](D:/Godot/Empty-start/docs/Integration/直播数据富文本_INT-03_2026-10-06_log.md) |
| PA-01 | 共享表现Resource、Theme引用与系统专属资源归属约定；历史资源加载验证通过 | [PA-01日志](D:/Godot/Empty-start/docs/Shared/PresentationAssets/表现资产_PA-01_2026-10-05_log.md) |
| PA-02 | 玩家素材入库、共享Resource引用，关卡提供对手外观字段；历史资源加载探针通过 | [PA-02日志](D:/Godot/Empty-start/docs/Shared/PresentationAssets/表现资产_PA-02_2026-10-07_log.md) |
| PA-03 | 玩家仓鼠立绘、直播背景、粉丝牌实际接入Sandbox；历史600帧smoke及画面检查通过 | [PA-03日志](D:/Godot/Empty-start/docs/Shared/PresentationAssets/表现资产_PA-03_2026-10-07_log.md) |
| AU-01 | 11个稳定音频事件、Music/SFX/UI路由、播放器池和Bus；使用占位音效；历史解析及实际播放探针通过 | [AU-01日志](D:/Godot/Empty-start/docs/Shared/Audio/Audio_AU-01_2026-10-06_log.md)、[audio_manager.gd](D:/Godot/Empty-start/core/autoload/audio_manager.gd) |
| DBG-01 | F3面板读取真实拥有者，通过公开入口调整PK、弹幕、直播和本场倾向；合并后Native运行验收记录通过 | [DBG-01日志](D:/Godot/Empty-start/docs/Shared/Debug/DBG-01_2026-10-07_log.md) |

当前源码已超出 INT-01 完成时的历史状态：Sandbox 在 PK 满时进入矛盾阶段；成功后创建 `FinalOracleSession`，未击破创建 `RestSession`；普通历史与倾向已有提交入口。来源：[sandbox.gd](D:/Godot/Empty-start/scenes/sandbox/sandbox.gd:234)。

## REQUIREMENTS / ROADMAP 剩余事实

### 完整可玩流程与真实内容

- 在生产 `core/ui/scenes/systems` 搜索，`final_oracle_opened`／`rest_opened` 仅见声明与 emit；Sandbox 没有神谕或休息 UI 消费者，没有关卡推进、神降临、结局实例。完整流程仍需后续系统任务接线；当前静态接线事实应结合各系统审计确认，不能仅凭已有纯逻辑类宣布一局已完成。
- 第一关仍为示例主播、三句示例词、真假矛盾和示例线索；第二关仅元数据，缺词库、矛盾和生成配置。来源：[level_001.tres](D:/Godot/Empty-start/data/level_configuration/level_001.tres)、[level_002.tres](D:/Godot/Empty-start/data/level_configuration/level_002.tres)、[level_catalog.tres](D:/Godot/Empty-start/data/level_configuration/level_catalog.tres)。
- 敌方直播数据没有正式拥有者或增长规则，Sandbox显示四项0。需后续任务或策划确定，不能从占位显示推导数值公式。来源：[sandbox.gd](D:/Godot/Empty-start/scenes/sandbox/sandbox.gd:40)、[INT-03日志](D:/Godot/Empty-start/docs/Integration/直播数据富文本_INT-03_2026-10-06_log.md)。

### 共用音频与美术

- AU-02 有任务卡、无完成日志；AudioManager 没有淡入淡出、交叉切换、压低恢复接口。`assets/audio/music/` 只有 `.gitkeep`；11个配置事件均为SFX/UI。可见实际玩法绑定为 CombatStage 的事件信号，Sandbox神谕过渡直接调用 `stop_music()`。来源：[AU-02任务卡](D:/Godot/Empty-start/docs/Shared/Audio/tasks/AU-02_music-state-transitions.md)、[Audio README](D:/Godot/Empty-start/docs/Shared/Audio/README.md)、[audio_event_config.tres](D:/Godot/Empty-start/data/shared/audio_event_config.tres)、[combat_stage.gd](D:/Godot/Empty-start/core/combat/combat_stage.gd:65)。
- 尚缺独立玩家头像、三身份图标、正式字体、各关对手立绘／头像／背景／粉丝牌、四指标ICON、PK/Tier/准心/蓄力资产。玩家头像当前复用立绘；对手关卡外观字段为空。PA-03 已完成现有素材接线，后续素材到位后继续替换。来源：[PresentationAssets README](D:/Godot/Empty-start/docs/Shared/PresentationAssets/README.md)、[PA-02日志](D:/Godot/Empty-start/docs/Shared/PresentationAssets/表现资产_PA-02_2026-10-07_log.md)、[PA-03日志](D:/Godot/Empty-start/docs/Shared/PresentationAssets/表现资产_PA-03_2026-10-07_log.md)。
- Original 美术案还有神谕、圣典、卡片、休息、终局和结局表现需求。当前四张PNG仅为玩家立绘、直播背景、房间背景、粉丝牌；房间背景本次PA-03未使用。后续美术缺口应随对应玩法／表现任务接入，不能把已有素材入口当成正式素材已交付。
- DBG-01日志记载曾要求三张DBG卡，但只找到DBG-01；另外两卡的路径与内容待补，不能自造任务ID。

### Windows / Android 交付

- Windows 历史编辑器与GUI运行验收已有；当前没有 `export_presets.cfg`，`build/`只有 `.gitkeep`，未发现仓库CI配置或EXE/APK/AAB成果。正式导出、安装及交付运行为 **UNVERIFIED**。此结论限定于仓库中可见配置与产物，不推断仓库外的本地构建成果。
- 当前准心和蓄力代码仅直接处理 `InputEventMouseMotion`／`InputEventMouseButton`，未见直接触摸事件处理。Android实际操作、触摸判定尺寸、性能、Emoji字体回退和导出为待验证内容；不推断引擎默认鼠标模拟在设备上的效果。来源：[aim_reticle.gd](D:/Godot/Empty-start/systems/combat_attack/aim_reticle.gd:21)、[attack_charge_input.gd](D:/Godot/Empty-start/systems/combat_attack/attack_charge_input.gd:102)、[INT-01日志](D:/Godot/Empty-start/docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md:127)、[INT-03日志](D:/Godot/Empty-start/docs/Integration/直播数据富文本_INT-03_2026-10-06_log.md)。
- 现存交付缺口没有对应的正式平台导出任务卡ID证据；ROADMAP可以记录待办范围，不能声称这些任务卡已经存在。

## Original 与当前正式事实差异

AGENTS规定优先级：当前代码及实际运行结果 → 配置/Scene/Resource → 系统正式文档 → Original。保留原稿用于追溯；当前任务按当前任务卡执行。

| Original / 历史说明 | 当前工程或正式说明 | 接入文档处理 |
| --- | --- | --- |
| 特殊道具框448×224、直播数据448×296 | INT-02 2026-10-07评审移除道具框，直播数据520高；两侧128/432/520，中央72/760/248 | 使用当前Scene、StageLayoutProfile与Shared正式规格；原稿保留历史。来源：Original系统案数值表、[INT-02日志](D:/Godot/Empty-start/docs/Integration/Sandbox布局_INT-02_2026-10-06_log.md:109)、[StageLayoutProfile](D:/Godot/Empty-start/data/stage_layout/stage_layout_profile.tres:10) |
| 准心视觉96、PC判定144、手机180 | INT-01 Review与CombatAttack README采用32设计像素圆，绘制与命中共用直径 | 记录当前32规则及原稿来源；Android尺寸仍待适配。来源：[CombatAttack README](<D:/Godot/Empty-start/docs/5. CombatAttack/README.md:21>)、[INT-01日志](D:/Godot/Empty-start/docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md:140)、[aim_reticle.gd](D:/Godot/Empty-start/systems/combat_attack/aim_reticle.gd:4) |
| 神谕共用1秒静音过渡 | CB README和Sandbox实际使用0.5秒可暂停Timer | 使用当前0.5秒规则。来源：Original系统案13音乐需求、[ContradictionBreak README](<D:/Godot/Empty-start/docs/12. ContradictionBreak/README.md:60>)、[sandbox.gd](D:/Godot/Empty-start/scenes/sandbox/sandbox.gd:242) |
| 蓄力0.8、飞行0.15～0.25、回拉基数0.005、按强度配置寿命 | INT-01任务临时试玩配置为0.2、0.1、0.001、普通10／复读6秒 | 明确为临时试玩值、待策划调参；这些参数属于当前任务覆盖，不能包装为最终平衡。来源：[INT-01日志](D:/Godot/Empty-start/docs/Integration/普通战斗Sandbox_INT-01_2026-10-06_log.md:75)、[playable_battle_config.tres](D:/Godot/Empty-start/data/sandbox/playable_battle_config.tres)、[attack_timing.tres](D:/Godot/Empty-start/data/sandbox/attack_timing.tres) |
| INT-01历史日志称尚无CB、满值停在入口 | 当前Sandbox已有真实CB接入与神谕／休息会话 | 项目现状按当前代码，旧日志作为历史证据；不能据旧日志把CB现有代码判为未实现 |

没有发现需要本次新增长期设计决定或期限的证据。上述规则差异均已有当前代码／正式说明／任务修订依据；真实内容、数值、平台适配缺口仍按已知状态保留。

## 已知陷阱与后续验证入口

已阅读 [known_traps.md](D:/Godot/Empty-start/known_traps.md)。与此范围直接相关的记录包括：KT-25 Autoload脚本运行方式、KT-27首次worktree导入、KT-28 Native端口与项目连接核对、KT-29直接运行Sandbox时SaveData初始化、KT-30输入坐标缩放、KT-31生成Timer周期、KT-32嵌套PackedScene缓存。后续实际集成验证优先复用现有INT-01场景runner与runtime smoke，画面、音效、操作和Android目标设备仍需要实际验收。本次没有执行这些验证。
