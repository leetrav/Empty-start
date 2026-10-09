# Integration

Lane A 持有 Sandbox 与顶层路由接线。系统规则、倾向、历史、奖励及结局显示继续归各系统所有者。

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
