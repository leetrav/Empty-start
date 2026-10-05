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
- LD-02 通过 `set_opening_viewers(multiplier)` 以本次开播单次抽取的倍率计算并保存 `viewer_count`；计算将结果截为非负整数。倍率范围待策划提供；此入口接收抽取后的倍率，不负责随机抽取。
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
