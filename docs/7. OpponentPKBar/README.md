# 7. OpponentPKBar 对手 PK 条系统任务拆分

## 系统目标

对手 PK 条系统负责“对手一直把玩家 PK 往回拉”和“玩家 PK 归零后的失败流程”。

它负责：
1. 按当前档位读取回拉速度；
2. 普通战斗期间持续产生回拉变化；
3. 暂停 / 阶段结束时停止；
4. PK 归零后触发本场失败；
5. 协调当前关重开；
6. 记录连败次数。

唯一 PK 值仍由【6. HitResolution】维护。

## 当前已实现接口

`core/combat/opponent_pk_bar.gd` 是场景内的回拉 Node。OP-02 可通过 `start_pullback(hit_resolution, base_speed)` 在普通战斗开始时注入 6 系统所有者和每秒基础回拉速度；`_process(delta)` 每帧将基础速度乘当前 Tier 倍率，再以负增量调用 `HitResolution.apply_player_pk_delta()`。

OP-01 的 `calculate_pullback_amount(speed, elapsed_seconds)` 返回正的 PK 扣减量，不保存或修改玩家 PK。OP-03 将 Node 设为 `PROCESS_MODE_PAUSABLE`，由 `SceneTree.paused` 自动暂停回拉；阶段结束调用 `stop_pullback()`，普通战斗恢复时调用 `resume_pullback()`。OP-04 通过 `update_pullback_multiplier(multiplier)` 更新后续帧速度。

OP-05 在当前唯一 PK 到达 0 时只发出一次 `attempt_failed`，并停止本系统的回拉。失败监听方可据此关闭攻击并显示本场失败；当前真实攻击入口尚未合并。重开状态由 OP-06 处理。

OP-09 由 OpponentPKBar 记录本关连败：`record_current_level_failure()` 加一，`complete_current_level()` 与 `start_new_run()` 均归零。连败只作为记录，不改变难度参数。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| OP-01 | 根据速度计算回拉量 | 2 个关键单元测试 |
| OP-02 | 普通战斗持续回拉 | 无 |
| OP-03 | 暂停和阶段结束时停止回拉 | 无 |
| OP-04 | 档位变化更新回拉速度 | 无 |
| OP-05 | PK 归零触发本场失败 | 1 个关键单元测试 |
| OP-06 | 当前关重开协作 | 无新增自动化测试 |
| OP-07 | 失败尝试记录回滚 | 无新增自动化测试 |
| OP-08 | 已提交历史成果继续保留 | 无新增自动化测试 |
| OP-09 | 连败记录 | 3 个关键单元测试 |

## 测试预算

只保留 6 个纯逻辑 case：

- 正时间间隔按速度计算回拉；
- 零时间间隔回拉为零；
- PK 到零触发失败；
- 本关失败连败 +1；
- 本关完成连败归零；
- 新周目连败归零。

真实计时、暂停、重开、跨系统回滚和历史保留用实际联调。

## 依赖顺序

OP-01～05、OP-09 可以先完成核心逻辑。
OP-06 等 2/3/5/6/8/10 等本场系统有真实重置接口。
OP-07 等 10/17 以及相关本场统计拥有者存在。
OP-08 等 14/15/16 已有已提交成果数据。
