# Integration

> **统一派工入口**：[2026-10-09 任务卡整合与依赖顺序](../开发计划_2026-10-09_任务卡依赖整合.md)。开发前核对该表、本卡现行版、main 实际实现及最新完成日志。

## INT-05（2026-10-09）

Windows UI、全屏与分辨率验收已在 `359bebc7` 基线上启动。R01～R04 有窗口人工检查，R01～R09 有精确尺寸图形 `TEST_ONLY` 路线截图和日志；R01 自动输入偶发偏离、R04 小窗口 HUD 可读性，以及未测的人工缩放／鼠标边界使整卡暂不能签收。详见 [INT-05 验收记录](./INT-05_2026-10-09_log.md) 与 [`evidence/INT-05_2026-10-09/`](./evidence/INT-05_2026-10-09/)。

Lane A 持有 Sandbox 与顶层路由接线。系统规则、倾向、历史、奖励及结局显示继续归各系统所有者。

## INT-07 神降临流程抽取（2026-10-10）

`Sandbox` 组合运行时子节点 `DivineDescentFlow`。流程统一持有本次冻结 `DivineDescentSession`、`DivineDescentCombatMode`、子节点 `DivineDescentSpread` 及已接收的 `EndingSession`。原 DD / Ending 规则和生产配置沿用当前实现；没有新增 Autoload 或修改场景资源。

- `start(run_data, catalog, current_level, tier_catalog, hit_resolution, combat_stage, contradiction_break, area, opponent_pk_bar, attack_input, battle_config, decay_config, presentation) -> bool`：入树后调用一次，注入同场组件与完整目录。返回 true 表示已进入终局；正式演出配置缺失仍停留在已进入状态并输出提示，保持 INT-04 行为。
- `presentation` 消费 Sandbox 已有的 `repeat_interval_seconds`、`fade_seconds`、`hold_seconds`、`input_scale`、`input_return_seconds`、`trait_colors`，默认值与 TEST_ONLY 注入来源保持原值。
- `entered(session)`：冻结及普通规则关闭后同步通知 Sandbox 收起普通、神谕和 Rest 阶段；Sandbox 继续转发原 `divine_descent_entered(session)`。原始空历史延迟接收 Ending；非空历史沿用扩散、衰减归零、锁句、90% 可见占比及真实 Tween 完成顺序。
- `advance(delta)`、`handle_input(event) -> bool`：由 Sandbox 每帧及输入入口调用；暂停、停止或完成后不推进。只有实际接受的左键 / 非重复空格表现输入返回 true，Sandbox 此时消费事件。
- `completed(result: EndingSession)`：同一冻结 Session 接收成功后通知一次。`get_result()` 返回同一已接收对象，Sandbox 只调用真实 SaveManager 存盘和 `SceneRouter.goto_ending(result)`。
- `stop()`：显式停止新话生成及普通攻击，扩散子树离树并销毁，取消 Timer / Tween；中断不形成完成事实。场景离树执行最终清理。
- `Sandbox.get_divine_descent_flow()` 与流程的 `get_session()`、`get_combat_mode()`、`get_spread()` 是联调读取入口。冻结快照和可变扩散池仍通过各原组件公开 getter 读取。

Windows Godot 4.7.2 D3D12 / Forward+ 的 INT-04 两条真实 GUI 路线通过（68 checks、10 routes、DD_completed=1、退出 0），含成果存读、一次接收和节点销毁。8 个既有 DD 脚本、RS-10、EN-09 及新增流程完成 / 中断定向测试均 headless 退出 0；正式 Sandbox 直接 GUI 启动退出 0。具体过程、命令和单文件检查限制见 [INT-07 日志](Sandbox重构_INT-07_2026-10-10_log.md)。Android 实机、正式演出参数及人工操作体验仍未验收。INT-08 接手时使用上述流程接口；本卡未执行 INT-08/09/10。

## INT-04（2026-10-09）

已接通真实 MainMenu → ID-09 三页 → RS-12 开局房间 → 主动开播 → 普通关 1 → Rest → 普通关 2 → DivineDescent → Ending。

- Sandbox 在末关继续后使用同一 `DivineDescentSession`、`DivineDescentCombatMode`、`BarrageArea`。DD-15 原始历史为空时直接接收 Ending；非空时组合 Spread、新话衰减、锁句、90% 收束、DD-17 全屏强调及完成事件。
- DD-14 左键 / 空格只调用表现接口；普通攻击、PK、Tier 与矛盾规则关闭。DD-16 只消费冻结继承表现，切页销毁所属终局节点与区域。
- 完成事件只创建一次 `EndingSession.receive_final_state(session, full_catalog)`；`SceneRouter.goto_ending(ending_session)` 保留接收结果，经真实顶层切换后调用 `EndingPage.show_ending()`。终局结束调用真实 SaveManager 存盘，不追加奖励。
- `SceneRouter.game_scene_override` 默认 null，仅为显式夹具入口。生产场景与 `.tres` 引用保持原值。

### TEST_ONLY 入口与配置

`tests/integration/int_04_full_run.tscn` 是一个实景 smoke，依次跑主路线和空历史路线；其中按钮信号执行正式页面流程，真实鼠标 / 空格事件经 `Input.parse_input_event()` 进入游戏。PK 满值及失败使用已有 debug API；矛盾与神谕选择必须通过真正蓄力、释放和 Timer。

`int_04_test_only_sandbox.tscn/.gd` 复用现有双关目录与 FO-11 夹具，仅深拷贝到内存后适配测试主播 ID、两关继承池与卡片。注入短攻击计时、3 条矛盾复读 / 0.3 秒寿命、普通复读 0.6 秒、每关粉丝 +7、静止移动、新话衰减 1 秒、自动复读间隔 0.1 秒、淡变 0.15 秒 / 停留 0.6 秒、输入 1.35 倍 / 0.2 秒及 occlusion 青色。数值均为联调占位；正式身份仍读取批准的十二卡。

正式演出参数未交付，Sandbox 的间隔、全屏时长及输入参数默认 0。非空历史到此会输出配置待交付提示，须显式注入夹具或未来批准值；原始空历史可直接 Ending。正式第二关内容、奖励配表、教名、判词、主图及特性配色继续待所属 Owner 交付，不能据 TEST_ONLY PASS 宣称正式版本内容完整。

### 运行与边界

指定基线 `1b84c098` 的 Godot 4.7.2 Windows D3D12 / Forward+ 实际 SceneTree 完成两条路线、真实磁盘存读、重开及去重检查，退出 0。运行期间曾发现 CA-12 旧输入代码在隐藏 GUI 中的准心跳位回归；现已由 #103 修复并合并。2026-10-09 12:16 基于最新 main 5ee1eff（合并 #103）的完整隔离工程已重新导入并实测：Godot 4.7.2 Windows D3D12 两条顶层流程全部通过，实际进程 ExitCode 0，62 checks、10 routes、DD_completed=1，stdout/stderr 存在本 evidence 目录 latest_main_pass_*。旧失败记录仅留作追溯，不代表当前阻断。详见 [INT-04 日志](./INT-04_2026-10-09_log.md) 和 `evidence/INT-04_2026-10-09/`。

保护用户存档的复现方式：在忽略目录复制当前工程与这四个集成测试文件，关闭副本的编辑器 MCP 插件，仅将副本 SaveManager 的 `SAVE_PATH` 改为 `res://.godot/int04_save.res`；函数体保持原值。导入完成后运行：

```text
godot.windows.opt.tools.64.exe --path <隔离项目绝对路径> res://tests/integration/int_04_full_run.tscn --resolution 1152x648 --quit-after 9000 --log-file <可写绝对日志路径>
```

等待真实子进程，要求退出 0、两行 `INT04 ROUTE PASS`、最终 `PASS INT-04`，同时检查错误日志。最终证据包含已有根证书及用户 settings.cfg 写入权限错误；没有 GDScript / 资源加载 / INT-04 断言错误。Sandbox 单脚本 check-only 因该模式缺少 SaveManager 全局标识退出 1（KT-25），其实际编译运行已由实景验证；SceneRouter check-only 退出 0，原 DD-15 / EN-09 回归各 1/1 PASS。

早期空经文截图在布局稳定前裁切标题；补齐输入抬起并等待布局稳定后，最终两条路线标题 Y=24、scroll=0，截图完整，无 Ending 源码修改。Android 设备、打包、正式美术与平衡、音频听感及完整人工操作体验均 UNVERIFIED。

## INT-06 中央战斗区全高与操作 ICON（待开发）

[INT-06 单功能程序任务卡](tasks/INT-06_battle-area-full-height-and-input-icon-overlay.md)：中央顶部保持 1024×72，中央 `BarrageArea` 调整为 1024×1008；旧底部交互栏空间归还弹幕场；中央战斗区左下角悬浮鼠标左键、ESC 两枚竖排操作 ICON。现有攻击进度与阶段程序入口继续提供给后续正式美术蓄力反馈，场景布局及 Paradox/神谕中央目标显示随之统一。该布局更新覆盖旧 INT-02 的中央 760px 弹幕区和 248px 底部区设计基线。
