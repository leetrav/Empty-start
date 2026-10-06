# 9. LiveDataPresentation 直播数据表现系统任务拆分

## 系统目标

直播数据表现系统只负责把直播间表现做得像“真的在涨热度”。

它保存并显示四项数据：

- 观看人数；
- 点赞数；
- 评论数；
- 粉丝数。

这些数据由战斗事件驱动，但不参与 PK、三项倾向和关卡解锁。

## 当前数据底座

- `LiveSessionData` 是直播数据系统唯一持有的四项数据 Resource，字段为 `viewer_count`、`like_count`、`comment_count` 和 `fan_count`。
- 当前周目通过 `SaveData.live_session` 持有该 Resource；跨场景和存档读写沿用现有 `SaveManager`。
- `LiveSessionData.initialize_session(initial_fan_count)` 清空本场观看、点赞、评论，并设置本周目当前粉丝数；新周目默认粉丝数为 0，正式起始粉丝值待策划配置。
- `LiveSessionData.record_generated_comments(actual_generated_count)` 只累计弹幕系统确认成功生成的实例数量。INT-01 Sandbox 统一监听 `BarrageArea.barrage_generated(view)`，普通与复读每个成功实例传 1；队列返回数量不再重复计评论。
- LD-02 通过 `set_opening_viewers(multiplier)` 以本次开播单次抽取的倍率计算并保存 `viewer_count`；计算将结果截为非负整数。倍率范围待策划提供；此入口接收抽取后的倍率，不负责随机抽取。
- LD-09 / INT-03 的 `LiveDataHud` 用四个独立 RichTextLabel 显示四项数值；LiveSessionData 计数属性变化时发出 `Resource.changed`，HUD 随信号刷新。
- `LiveDataHud.bind_live_session(session)` 为场景组合方提供显式绑定入口：初始化或替换 SaveData 后传入当前 `LiveSessionData`，HUD 断开旧 Resource 的订阅、连接当前 Resource 并立即刷新四项数值；传入 `null` 时显示 0。Sandbox 在创建运行时 SaveData 后调用此入口，避免直接运行场景时 Autoload 初始化顺序使 HUD 留在早期空数据上。
- 当前 `SceneRouter.goto_game()` 指向可玩 Sandbox，左主播区复用 `ui/live_data/live_data_hud.tscn`。开局及原地重开通过 `initialize_session()` 清空本场数据并保留入关粉丝数；Viewer / Like 的事件增量仍等待策划规则。
- INT-03 复用同一 HUD 场景，占用 INT-02 已保存的左右 `448×296` 区域：左边 ICON→数字左对齐，右边数字→ICON右对齐。旧 Panel / CardPanel、2×2排版和字段标题已移除；四个控件为 `Metrics/ViewerMetric`、`LikeMetric`、`CommentMetric`、`FanMetric`。
- `display_side` 仅控制图标顺序与对齐；独立的 `auto_bind_player_session` 决定运行时是否默认绑定玩家数据。Sandbox右实例关闭自动绑定，通过 `set_values(0,0,0,0)` 提供明确的零值占位；未来可显式 `bind_live_session()` 注入真实敌方数据源。
- `set_values(viewer_count,like_count,comment_count,fan_count)` 直接格式化四项富文本，HUD不保存另一份业务数值。当前ICON为可配置的👤/👍/🔊/👥字符串，可换成BBCode图像；单项视觉更新集中在 `_render_metric()`，尚未加入数值动画。
- 未绑定数据源时，运行期改方向或ICON从标签当前显示内容提取整数再排版，保留调用方传入的显示值；显式 `bind_live_session(null)` 仍清成四项0。
- HUD的 `@tool` 分支只渲染编辑器预览和对齐，跳过SaveManager访问。四项支持BBCode、单行、禁滚动、忽略鼠标，保留实际战斗输入。
- 这些值只供表现和展示读取，不作为 PK、倾向或关卡解锁输入。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| LD-01 | 本场直播四项数据状态 | 无 |
| LD-02 | 开播观看人数计算 | 2 个关键单元测试 |
| LD-03 | 命中事件改变观看与点赞 | 无 |
| LD-04 | 档位变化影响直播热度 | 无 |
| LD-05 | 弹幕 / 复读生成增加评论 | 无 |
| LD-06 | 矛盾击破 / 神谕触发短时上涨 | 无 |
| LD-07 | PK 胜利只结算一次新增粉丝 | 2 个关键单元测试 |
| LD-08 | 本关重开重置本场数据 | 2 个关键单元测试 |
| LD-09 | 直播数据 UI 显示 | 无 |
| LD-10 | 休息时刻展示本场结果 | 无新增自动化测试 |

## 测试预算

只保留 6 个纯逻辑 case：

- 开播人数按粉丝数与倍率计算；
- 开播人数不会小于 0；
- 同一场 PK 胜利第一次可以结算粉丝；
- 同一场重复提交不会再次增加粉丝；
- 重开后观看 / 点赞 / 评论回到本场初始状态；
- 重开后开局粉丝数保持不变。

事件增量、UI、动画、数字跳动和跨系统广播全部用最小运行联调。

## 依赖顺序

LD-01～02 可以先完成。
LD-03 等 6. HitResolution。
LD-04 等 8. CombatStage。
LD-05 等 3. BarrageGeneration 与 10. Repeat。
LD-06 等 12. ContradictionBreak 与 13. FinalOracle。
LD-07 等本场胜利结果存在。
LD-08 等 7. OpponentPKBar 重开流程。
LD-10 等 18. Rest。
