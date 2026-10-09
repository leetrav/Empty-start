# CA-10 Sandbox 假命中复读展示补做 · Lane A

## 任务与基线

- 本次只修复 [PR #92 审查阻塞](https://github.com/w7775p/Empty-start/pull/92#issuecomment-6071669467)，属于原 CA-10 补做。
- 工作树 `lane-a-ca10-sandbox-1009/Empty-start`；分支 `codex/lane-a-ca10-sandbox-1009`；基线 `c03bd17da17c82ed6f2dcadce103f12b3675a516`，目标 main，开工干净。
- 已读取 AGENTS、known_traps、开发计划、System_Collaboration、原始程序需求、CA-10、CA-09 卡/日志、CA-11 最新日志及 5/10/12 README；通过 GitHub connector 读取 #92 的完整 diff 和审查评论。首次 review threads 请求失败，随后 fetch_pr 成功。
- 原缺口：假命中入队 120 条 → NOT_BROKEN 同步锁定 → Rest 同步清空队列；0.5～3 秒延迟尚未结束，实际生成 0 条。

## 实际修改

1. `scenes/sandbox/sandbox.gd`：NOT_BROKEN 后保持矛盾阶段的现有逐帧调度，Rest 入口检查矛盾队列为 0 且场上可见矛盾复读全部结束；空命中和超时队列为空时仍即时进入 Rest。
2. 同场结果处理增加一次性标记，重复结果通知不会清除正在展示的复读，也不会重复启动成功表现。重开清理旧队列并重置标记；Rest 入口检查阶段/已打开 Session，防止重复提交和打开。
3. `docs/System_Collaboration.md`、本系统 README：同步未击破展示的结束条件与协作边界。
4. 本日志：独立记录 A 补做，避免覆盖 #92 中 E 的原 CA-10 日志。

结果仍在原有释放或超时时点不可逆固定；立即锁住下一发并停止真假矛盾生成。所有者仍为 12 判结果、10 持队列/统计、3 生成和结束弹幕、Sandbox 接线、18 展示 Rest。没有新 Manager、Autoload、公开接口、Scene、Node 或生产 Resource 改动；中文函数注释已补齐。

结束策略复用成功分支的两个公开查询。等待集合只包含本发有限复读；现有正寿命和非零屏幕容量让实例释放位置后继续消费剩余条目，最终队列与画面都为空。未新增演出时长或更改正式参数。当前 120 条/命中、6 秒寿命、24 容量在 TEST_ONLY 关卡布局下约 50～52 秒完成，体验调参仍交策划。

## Godot 4.7.2 实际验证

引擎：`4.7.2.stable.steam.ed1daf0bf`，路径 `D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`。使用 CLI 实际启动临时 SceneTree 场景，实例化既有 `tests/fixtures/data_export/test_only_sandbox.tscn`；没有长期新测试或额外单元测试。

测试资源：既有 TEST_ONLY 两关目录及 `test_contra_true_01` / `test_contra_false_01`；内存深拷贝 battle_config 后仅注入既有 CA-07 短计时。假命中完整展示保留现有 120 条、6 秒寿命、24 同屏上限和 0.5～3 秒延迟；其余重复场景仅用内存 TEST_ONLY 0.35 秒寿命缩短验证。目标测试实例静止以稳定蓄力瞄准，未写回任何 Resource。身份数据及已批准的 12 身份均未修改。

真实输入使用 `Input.parse_input_event()` / `Input.flush_buffered_events()`，窗口坐标通过 Viewport 变换转换，蓄力由游戏帧推进、飞行/硬直由原 Timer 驱动。通过已有 PK debug API 进入矛盾阶段；矛盾命中和结果没有直接调用系统判定来冒充发射。真命中场景先用真实普通攻击产生原句历史，才能验证实际神谕候选入口。

通过项：

- 未满蓄释放没有快照，机会仍为 1；真/假正式释放各只有一发，释放返回时已固定 BREAKTHROUGH/NOT_BROKEN，剩余机会 0。
- 假命中锁定后 pending=120、Rest=0；全部 120 条实际生成可见正文后自然离场，pending=0 且无可见复读时进入 Rest；展示期间和 Rest 后输入均没有第二发。
- 重复 outcome 回调保留可见复读；再次调用 Rest 入口仍只发出一次 `rest_opened`。
- 假命中无普通结算提交，PK 保持 1.0；没有圣典、败者卡或真正击败/吞并奖励。
- 真命中同样生成全部 120 条，队列和可见实例结束后沿用静音 Timer，实际打开一次 FinalOracle，未进入 Rest。
- 空命中：一发、零复读、一次 Rest；10 秒窗口真实超时：零发射、零复读、一次 Rest。
- 假复读排队期间重开：旧队列与展示撤销，等待超过最长延迟仍无旧 Rest；新尝试正常进入矛盾并可落空进入一次 Rest，通知标记已重置。
- 普通鼠标满蓄攻击仍产生一次正常提交、真实 PK 增长和普通命中历史。

运行结果（完整日志在本工作树 `.godot/ca10_smoke/`，该目录由 Git 忽略）：

```text
headless_final.stdout:
CA10 display success=false generated=120 elapsed_ms=49779
CA10 display success=true generated=120 elapsed_ms=5484
CA10 empty/timeout timeout=false shots=1 rests=1
CA10 empty/timeout timeout=true shots=0 rests=1
CA10 PASS checks=539 display=headless TEST_ONLY

windows.stdout:
CA10 display success=false generated=120 elapsed_ms=52387
CA10 display success=true generated=120 elapsed_ms=6133
CA10 empty/timeout timeout=false shots=1 rests=1
CA10 empty/timeout timeout=true shots=0 rests=1
CA10 PASS checks=539 display=Windows TEST_ONLY

exit_verified.stdout（所有展示使用内存短寿命副本）:
CA10 PASS checks=539 display=headless TEST_ONLY
Godot process ExitCode=0
```

Windows 使用 `--rendering-method gl_compatibility --resolution 1152x648`，AMD Radeon OpenGL 3.3。已读取实际 Viewport 截图 `fake.png` / `true.png`，确认假复读正文和“未击破矛盾 · 等待复读展示”状态确实出现在主舞台，PK 显示 100%。短寿命补跑使用 .NET Process 明确捕获 Godot 子进程退出码 0；前两次 Start-Process 的外层命令退出 0，但返回的 ExitCode 属性为空，未将该属性误报为引擎退出码。

环境/验收准备情况：首次启动 smoke 早于资源导入结束，出现缺少导入贴图及临时脚本参数错误；等待导入结束并修正临时脚本后重跑。初版真命中验收缺少普通历史，已改为真实普通输入产生历史后进入阶段；保留最终通过的日志。系统设置 `user://settings.cfg`、Steam 编辑器设置、证书读取与图形 shader 缓存仍受沙箱权限限制，stderr 有对应错误；最终运行无 `CA10 FAIL`、GDScript 错误或 Sandbox 业务错误，不能声称整份日志无报错。

## 交接、限制与发布

- 运行接线已完成，无本卡未满足的上游程序依赖。正式关卡内容、Android、D3D12、音效听感及完整开局到结局 E2E 未在本卡验收，保持 UNVERIFIED。
- 已更新 5 README 与 System_Collaboration；known_traps 未修改，环境/导入/输入事项沿用 KT-27/30/34/36。12 README 的旧“未击破清空尚未展示队列”描述由其 Owner 后续同步，本补丁以 Sandbox 与公共协作文档中的实际结束规则交接。
- 按用户要求没有 commit、push、建 PR 或合并。发布者只提交本次四个文件，基于发布时最新 main 检查冲突与 smoke；若独立发布 Sandbox 修复，再交 E 在 #92 回归并更新其原日志。合并 README 时保留 E 的原接线证据，将“假命中仍阻塞”叙述更新为本补做已验证的行为。
- 临时 smoke 脚本/场景归档至忽略目录供本地复现，入口目录 `.tmp_ca10` 已清理；导入生成的旁路 `.uid` / `.import` 已撤销。本次未访问其他 Lane 工作树，未修改 B 的 Rest/身份 UI 或 C 的 DivineDescent。
- 接手从 Sandbox `_on_contradiction_outcome_locked()`、`_open_rest_after_unbroken()` 与 `_process()` 开始；复现时将忽略目录中保存的 `smoke.gd` / `smoke.tscn` 复制回 `.tmp_ca10/`，使用现有 TEST_ONLY 场景运行。到此停止，不接新卡。
