# PA-16 PK 条阶段贴图：短闪调色后换底板

> 状态：需求已确认，待实施
> 类型：程序美术 / PresentationAssets
> 依赖：现有 PK HUD / `refresh_pk()`、CombatStage 最终阶段通知；PA-13 仓鼠球指示器

## 开始前阅读
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`、`assets/README.md`、最新相关完成日志
- `scenes/sandbox/sandbox.tscn`、`scenes/sandbox/sandbox_battle_hud.gd`

- `docs/Shared/PresentationAssets/tasks/PA-13_pk-hamster-ball-indicator-animation.md`

## 当前素材
- `res://assets/ui/combat/pk_bar/pk_bar_pos_01.png`～`pk_bar_pos_06.png` 分别对应 T1～T5、Paradox。
- T0 对应的 0 号图片已向美术提出补交，收到后接入 `pk_bar_pos_00.png`；接入前保持可替换的现有底板。
- 玩家 PK 落在 0～10%、10～20%、20～30%、30～40% 时，分别使用 `pk_bar_neg_04.png`、`neg_03.png`、`neg_02.png`、`neg_01.png` 作为额外的玩家失势表现；具体边界统一处理，例如 [0,10)、[10,20)、[20,30)、[30,40)，40% 不属于负向覆盖。
- 正式阶段图与负向变体要有可配置的叠加 / 优先覆盖入口，负向区间生效时画面可直接看到对应的四张变体。

## 本卡程序美术
- **每次阶段底图发生变化**，先在 PK 条上播放短促明暗闪烁、颜色偏移 / 色相变化，再将原图替换为目标阶段底图，最后迅速恢复正常明度与配色。
- 闪烁、换图只作用于 PK 条背景层；上方 PA-13 的仓鼠球继续根据真实玩家 PK 位置移动、滚动或蹦跳，显示位置和表情独立于底板。
- 当玩家 PK 穿过 10%、20%、30%、40% 的负向区间边界时，按新的对应图切换；避免正常持续回拉每帧都重开闪烁，按**实际显示底板变化**触发一次短动画。
- 保持 `refresh_pk()` 的唯一数值驱动、原 PK 进度条实际占比以及对手 PK 百分比计算。Tween / CanvasItem.modulate / 轻量 Shader 调参：闪烁次数、强度、色相偏移、换图点、动画时间、透明度。

## 验收
- T1～T5、Paradox 根据实际阶段显示对应 1～6 图；T0 兼容正式 0 号图未来补交。
- 玩家处于 0～40% 时，按 -4、-3、-2、-1 四档看到实际对应负向贴图；进入或离开负向区间后画面正确恢复。
- 每次切换有明显但短促的“闪烁 → 调色 → 换图 → 稳定”反馈；PA-13 仓鼠球仍清楚可见且随 PK 实时滚动。
- Windows / Android 运行画面中，两侧主播、顶部 PK 和战斗场能正常显示。

## 完成记录
新增 `docs/Shared/PresentationAssets/表现资产_PA-16_YYYY-MM-DD_log.md`，记录贴图映射、切换参数、效果和实测。
