# PB-05 Plan B 试算与复现入口

## 当前状态

`experiment_model.py` 是脚本侧的 V0 参数试算模型。它按固定随机种子模拟发表、棋子移动与接触、感染/改口、自然离场/中立补充和按真实人数差更新 PK。**这些统计属于模型输出，不代表真人验收或最终数值批准。**Godot 4.7.2 已在隔离的 PB-01～04 合流验证副本中运行；E 的主分支仍保持 Lane 文件边界。

## 重放与验证

```powershell
python tests/plan_b/test_experiment_model.py -v
python tests/plan_b/experiment_model.py --seed-count 10
python tests/plan_b/experiment_model.py --postprocess-only
python tests/plan_b/experiment_model.py --config-id base --strategy tactical --seed 20261017
python tests/plan_b/experiment_model.py --candidate-sweep --seed-count 10
python tests/plan_b/experiment_model.py --candidate-sweep --candidate-id candidate_moderate --seed-count 10
```

默认固定种子为 `20261017`～`20261026`。相同配置、策略和 seed 会生成相同单场事件趋势。实验 CSV 写到 `tests/plan_b/results/`：

- `experiment_runs.csv`：每场的参数、固定 seed、模型时长、PK 极值、PK 中点交叉次数、最长中立短缺、最高单边占比、30 秒最大 PK 波动、单个 30 秒窗内最多发表句数、结束 PK、阵营人数及接触/感染/改口计数。
- `experiment_summary.csv`：按参数组合与操作路线汇总胜负数、240 秒截断数、中位时长、平均 PK 极值/回穿次数、中立短缺、单边占比、PK 波动、话语发表峰值和事件数。
- `experiment_metadata.json`：记录模型标记、重放 seed、运行数、步长和命令。
- 单场命令会写 `experiment_replay.json`，包含完整配置、结果、30 秒阵营趋势和单场发表数，方便固定 seed 复核。
- `--candidate-sweep` 对组合配置的四条路线各跑固定 seed。`candidate_slow_balanced` 使用 `k=0.55`；`candidate_moderate` 使用 `k=0.70`；两者都使用感染率 `10/22/35%`、寿命均值45秒、人数上限96、冷却5/11.5秒。默认输出 `candidate_runs.csv` / `candidate_summary.csv`；其它候选会在文件名中加入 ID。这些属于综合敏感度复核，仍是模型建议。

## V0 模型假设

- 复用 Plan B 规则候选：PK 初值 50，`k=0.85` 百分点/秒；按 `(我方人数 - 对手人数) / 当前总人数 × k × elapsed` 更新，范围夹在 0～100。
- 费米开局 2 棋子、76 中立；人数上限 96，空位每 0.75 秒补中立；自然寿命按 `65±12` 秒正态抽样并限制最短 25 秒。
- 两名初始费米棋子共用 `fermi_initial`；模型在第一个 0.2 秒步立即允许 AI 再发表，之后遵守发言冷却。中央规则没有规定首句延迟；Lane A 当前原型字段是 3 秒，Lane C 测试表为 11.5 秒，需接入后由负责人定一个统一值。该时序差异会影响模型时长和早期雪球，当前结果应按此模型假设阅读。
- 临时类型为 `type_a > type_b > type_c > type_a`；合法感染强度概率为 20%/35%/50%；敌我同属性只弹开；同阵营新话传旧话必成且不改人数。
- 试算区域 900×490，棋子移动速度 52～78 px/s，碰撞直径 28 px，接触裁决冷却 0.7 秒。这些运动参数来自原试算参考，不是当前 Godot 画布的实测结果。
- 四条玩家路线：不操作、固定 `type_a` 强度 3、随机属性/强度/中立目标、按对手主属性选克制词并把新信徒放在己方群体附近。费米路线固定为同一套适应性出词规则。
- 参数实验使用单因素对照：PK k 0.55/0.85/1.15；人数上限 72/96/120；感染概率组 10/22/35%、20/35/50%、30/50/70%；离场均值 45/65/85 秒；双方发言冷却 3.5/8、5/11.5、7/15 秒。除所列变量外，各项保持基线。
- 240 秒只作为实验截断点。输出 `censored_240s` 不能解释成游戏正式平局或超时结局。
- 中点交叉只按每 30 秒的趋势采样计算；采样间短暂逆转可能漏掉，真人逆转仍需实机确认。
- 中立短缺定义为连续采样点中立数 `≤3`；雪球指标取双方中较大一边占当时总人数的最高比例；PK 波动与话语峰值都只看每个 30 秒窗口。它们帮助筛查参数组合，不能代替高帧率录屏和真人可读性验收。

## Godot 公共接口测试

`pb05_public_api_smoke.tscn` 启动 E 的 Node runner。runner 通过公开脚本入口组装 A Host、B Simulation、C Catalog 与费米控制器，然后验证开局播种、发表原子性、全局顺序、完整话语快照、真实接触下的传话/感染/弹开、strength 1/2/3 感染率和出生/自然离场事件。脚本只改动测试节点的公开导出参数，不访问生产模块私有字段。

C 当前 TEST_ONLY 词池为 30 条玩家话语和5条费米话语；烟测下限按这份实际数据设定。

等待 PB-01～04 实际模块合入后执行：

```powershell
godot --headless --editor --path . --import
godot --headless --path . --scene res://tests/plan_b/pb05_public_api_smoke.tscn --quit-after 7200
godot --headless --path . --scene res://systems/plan_b/battle/tests/test_pb01_battle_host.tscn --verbose --quit-after 600
```

Lane A 的 `f330f7f` 在开局通过 B `seed_unit()` 播种两名费米、占用两条词并分配两个顺序号；隔离合流验证分支 `fd3c94a` 包含该提交。此前的0/78结果来自较早的 A Host。合流日志 `results/pb05_godot_integration_smoke.log` 记录 `PASS PB-05 public A/B/C interfaces...`，strength 接触采样为0.152/0.305/0.446；E 主分支仍保持 Lane 文件边界。按 Lane A 最新交接，本次不再重跑 smoke，也不操作 GUI 或录屏。Headless 合流验收的复现命令见上方。

实机场景交付后补充两个策略的录屏与实际时长/帧耗/碰撞响应/点击和文本可读性记录。Android 清单只记录实际检查项，未在设备或模拟器上跑过的项标成 `UNVERIFIED`。

## 实机与 Android 验收清单（当前均为 UNVERIFIED）

| 验收项 | 记录方式 |
| --- | --- |
| Godot 场景 | 记录 commit、场景路径、seed、玩家策略、费米策略、平台与分辨率 |
| 单场结果 | 记录真实开始/结束时间、PK 最低/最高值、0/100 结果和双方发表句数 |
| 阵营趋势 | 记录每 30 秒 player/opponent/neutral 数量以及出生/离场/转换事件 |
| 80/96/100 棋子性能 | 每档持续运行 60 秒，记录平均/最低 FPS、物理帧时间、碰撞裁决次数/秒与峰值棋子数 |
| 点击精准度 | 对 20 个不同目标各点一次，记录正确选中数、空点数和错选数 |
| 文本可读性 | 截取 100 棋子画面；记录遮挡/重叠情况及最小可读字高，交真人确认 |
| Android 16:9、19.5:9、20:9 | 分别检查安全区、刘海/圆角、横竖屏、触控坐标映射和小字可读性 |
| Android 手势 | 实测单指点选、快速连点、长按、拖动、系统返回和失焦恢复；记录触点是否遮住选中目标 |

当前没有真人整局操作、视频或性能采样数据；表格用于补验，不表示已通过。
