# Sandbox 联调 INT-13 任务日志

日期：2026-10-15  
分支：`codex/int-13-pa12-sandbox-integration-20261015`  
基线：`3fadd5e`  
状态：实现完成；等待总控 Review

## 本次任务

将已验收的 `ParadoxComicTransition` 接入真实 Sandbox：PK 满值后先播放转场，转场完成后才启动矛盾六句和原十秒窗口；矛盾结果锁定后播放一次结果漫画，再开放神谕或 Rest 页面。

## 改动文件

- `core/combat/battle_attempt_flow.gd`：保留普通战斗结束、粉丝和普通复读历史提交；新增 `begin_contradiction_after_transition(level, hit_resolution, repeat_stats)`，只在有效满值交接尚未消费且命中对象仍属于当前尝试时启动矛盾流程。
- `core/contradiction_oracle/contradiction_oracle_flow.gd`：新增结果漫画门控。真击破的原静音 Timer 可先结束，神谕页面和十秒选择计时等 Sandbox 释放门控后再启动；停止流程清除门控待处理状态。
- `scenes/sandbox/sandbox.gd`：实例化既有 `ParadoxComicTransition` 场景，连接普通完成、矛盾结果及两个动画完成信号；管理当前转场对象、结果漫画和暂存的神谕 / Rest 展示。重开、失败和离树时清理待处理交接与动画。
- `tests/integration/int_01_playable_battle_sandbox_test.gd`：验证满值到转场、暂停时阶段未开放、转场结束才进入矛盾流程，并保存 GUI 实际预览图到任务指定的 `D:\tmp` 目录。
- `tests/integration/int_04_full_run.gd`：跟随新转场顺序等待矛盾阶段，增加结果漫画期间 Rest 尚未显示的断言。
- `docs/Integration/README.md`：记录 INT-13 实际 API、普通满值和结果分支时序及 INT-09/08 的接入更新。
- 本任务卡：`docs/Integration/tasks/INT-13_pa12_paradox_comic_sandbox_integration.md`，由用户在本分支提供。

## 场景和实际能力

Sandbox 在运行时新增 `ParadoxComicTransition` 子节点实例，复用 `systems/presentation/paradox_comic_transition.tscn`；没有新增持久场景节点、Autoload、生产表资源或 SaveData 规则。

实际顺序：普通命中达到 PK 满值 → `BattleAttemptFlow` 停止普通攻击和生成并提交原粉丝 / 复读历史 → `normal_combat_completed` → `play_transition()` → `transition_finished` → `begin_contradiction_after_transition()` → 原矛盾流程创建六句、启动十秒计时并开放矛盾攻击。转场期间普通和矛盾攻击均关闭。

结果顺序：原 `outcome_resolved(outcome)` → Sandbox 映射 `BREAKTHROUGH` 或未击破并播放一次结果漫画 → 成功分支通过 `hold_oracle_for_result_feedback()` 等待漫画完成，同时继续满足既有复读和静音条件 → 动画完成后释放神谕门控并由原流程打开神谕 / 启动选择计时；未击破的同一 `RestSession` 等漫画完成后再显示。业务结果仍由各原流程和数据所有者提交。

## Godot 验证

使用 `D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`，版本 `4.7.2.stable.steam.ed1daf0bf`。Godot-MCP-Native 当前未提供给本会话，场景验证使用本机 Godot CLI；画面使用 D3D12 / Forward+ 图形模式运行后从 Godot Viewport 保存预览。

| 验证 | 命令 / 场景 | 结果 |
| --- | --- | --- |
| 资源导入 | `--headless --path . --import` | exit 0；初次导入前的运行因缺少字体导入缓存报错，导入后相关场景正常加载。Godot 生成的 `.import` 变化已还原。 |
| 生产 Sandbox 冒烟 | `--headless --scene res://scenes/sandbox/sandbox.tscn --quit-after 90` | exit 0；日志只有引擎版本行，无脚本或资源错误。 |
| INT-01 headless | `--headless --scene res://tests/integration/int_01_playable_battle_sandbox_test.tscn` | **exit 0，93 checks 通过**；含真实输入链、PK 满值转场、漫画暂停、延迟开放矛盾窗口、神谕候选和超时暂停。输出：`D:\tmp\int13-int01-final2.log`。 |
| INT-04 TEST_ONLY 全流程 | `--headless --scene res://tests/integration/int_04_full_run.tscn` | **exit 0，100 checks、10 个顶层路由、1 次神降临完成**；含击破神谕、未击破 Rest、两关继续、Ending 和存档读回。运行时临时使用 `INT13 Isolated Verification` Godot 用户目录；`project.godot` 已恢复，活动项目存档未触碰。输出：`D:\tmp\int13-int04-final2.log`。 |
| INT-01 D3D12 GUI | `--scene res://tests/integration/int_01_playable_battle_sandbox_test.tscn` | **exit 1，96 checks 中 95 项通过**。PA-12 转场、暂停和结果漫画检查均通过；剩余失败为既有断言“恢复补偿弹幕暂停寿命”，在两次图形帧时序运行中出现，headless INT-01 通过。完整输出：`D:\tmp\int13-int01-gui-final2.log`。 |

GUI 实际截图保存在 `D:\tmp\int13-pa12-preview-20261015\transition.png` 和 `result.png`，没有加入 Git。`transition.png` 捕获到实际斜切；`result.png` 捕获成功结果字样。两图已人工查看。

此前 INT-01 的同步开窗假设和 INT-04 的立即读取六句假设均随新时序更新；初轮失败用于定位并已修正，不作为最终结果。正式四关数据 / Android 实机 / 触屏输入 / 设备视觉与性能仍未验收。

## 交接

下一步由总控检查本分支差异和 Godot 证据；确认后推送并开 PR 等待 Review。不得把本地 D3D12 的单项弹幕暂停寿命断言失败表述为 PA-12 测试通过。

系统文档及 `known_traps.md`：更新 Integration README；未发现需新增长期陷阱。

## PR #228 评审返工：暂停寿命补偿计时（2026-10-15）

`expires_at_msec - expiry_before` 测量暂停后绝对到期时间的延长量。`BarrageView` 以 `PROCESS_MODE_ALWAYS` 在暂停时记录单调时钟起点，恢复后将经过毫秒数补到到期时间；到期差值应覆盖实际暂停区间，弹幕移动和蓄力仍由原断言验证暂停冻结。原测试以固定 `180ms` 对照名义 `220ms` 等待，未记录 pause/resume 实际时钟，无法区分计时器和图形帧调度造成的时间差。

本次测试记录 pause 请求、resume 请求、测量时点、到期前后值和补偿差，并以 `max(180ms, 实测暂停时长 - 50ms)` 核对补偿，保留原下限及 50ms 单帧调度容差。直接测量表明运行时补偿符合暂停寿命规则，没有发现 `BarrageView` 生命周期缺陷；历史两次失败没有保存当时计时数据，因此无法追溯其单次实际误差。当前验证记录：

| 验证 | 到期前 → 到期后 | 实际暂停 / 补偿 | 结果 |
| --- | --- | --- | --- |
| Godot 4.7.2 D3D12 GUI INT-01 | `18634 → 18867` | `229ms / 233ms`（差 `+4ms`） | exit 0；96/96 PASS |
| Godot 4.7.2 headless INT-01 | `16936 → 17173` | `235ms / 237ms`（差 `+2ms`） | exit 0；93/93 PASS |
| Godot 4.7.2 headless INT-04 | — | — | exit 0；100 checks、10 个顶层路由、1 次神降临完成 |

复验日志位于 `D:\tmp\int13-int01-gui-final2.log`、`D:\tmp\int13-int01-headless-final2.log`、`D:\tmp\int13-int04-headless-final.log`。使用隔离 APPDATA `D:\tmp\int13-pa12-review-userdata`，没有触碰项目存档；GUI 预览仍只保存在仓库外。改动仅限 INT-01 暂停计时断言和本日志；没有修改运行时代码或系统文档。
