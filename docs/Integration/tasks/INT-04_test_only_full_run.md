# INT-04 使用 TEST_ONLY 配置完成整局主流程联调

## 授权与目的
项目负责人 2026-10-08 决策：正式策划内容、配图、文案、数值若尚未交付，统一用已标明来源的 `TEST_ONLY` 注入进行程序联调，不阻塞基础系统闭环。今天优先完成基础系统；次日集中整合联调和表现打磨。本卡在关键上游代码合并后执行。

**Owner**：Lane A / Sandbox 集成。B 持有 Rest UI，C 持有 DivineDescent 核心，D 持有 Ending，E 持有继承特性；由各 Owner 修复其模块，A 最小化接线，不在 A 内重写其它系统。

## 已有可用资源
- `data/test_only/generated/level_configuration/test_only_level_catalog.tres`：两个 TEST_ONLY 主播关卡及普通词库/矛盾配置。
- `tests/fixtures/data_export/test_only_sandbox.tscn`：通过覆写 `level_catalog` 启动真实 Sandbox，而非修改生产关卡目录。
- `tests/data_export/test_test_only_live_smoke.gd`：已覆盖首关真实生成、蓄力命中、PK 满值、矛盾未击破、Rest Continue 到第二关。
- `tests/fixtures/fo11/`：真实击破后败者卡及吞并奖励的 TEST_ONLY 资料。
- 正式 `data/ending/*.tres` 与 `data/loser_card/loser_card_catalog.tres` 若仍为空，测试环境可以显式提供 TEST_ONLY Resource / 内存配置，不将虚构数据回填为正式策划内容。

## 本卡要做什么
1. 基于**最新 main** 阅读本卡、`AGENTS.md`、`known_traps.md` 和系统日志。确认 ID-08、RS-11、CS-11、DD-10～17、EN-09、BT-13 等真正已合并和所暴露的接口；若未合并，列明阻塞并等待对应 Owner，不抢写。
2. 从身份选择与 SaveData 确认开始，实际运行**两次普通关**：正常弹幕生成、蓄力攻击、命中、Tier 与 PK、矛盾分支、神谕选择、真正击败奖励、Rest 展示、继续与下一主播。身份 12 卡的已批准真实文字来自 CSV，不以 TEST_ONLY 擅自替换。
3. 验证未击破通关、真正击破成功、失败重开、重复确认/重复打开、历史经文和败者卡、吞并词库/特性、粉丝数与倾向只取已提交值；无正式数据时显式注入稳定的 TEST_ONLY ID、材质/颜色和文案。
4. 两个普通关全部完成后进入 DivineDescent，真实验证冻结快照、新话衰减、扩散、锁句、90% 收束和 DD-17 触发，随后收到 **EndingSession** 的固定事实、显示 EndingPage；验证没有圣典/卡片/吞并的全空路线也可结束。
5. PC Windows Godot 4.7.2 真正运行 `SceneTree` smoke，至少覆盖主成功路线和一次未击破路线（可以用 TEST_ONLY 注入而不人工点击每一条弹幕）；有 UI 的路径补实际 D3D12 窗口验证，记录判定点、退出码、Output 错误和真实数据的来源。Android 触控 / 分辨率 / 打包交后续 CA-12 与平台验收，不把 PC 结果冒充 Android 已过。
6. 发现一个跨系统问题先定位真实 Owner：A 只修 Sandbox / 路由边界；其它问题形成最小复现与明确文件/接口交接。没有问题不额外新建 Manager、索引/哈希门禁或重复实现已有测试。
7. 更新 `docs/Integration/README.md`（存在时）和 `INT-04_YYYY-MM-DD_log.md`；写清正式缺口与 TEST_ONLY 代替项、尚未覆盖内容、PC/Android 验收边界。依当前协作规则独立 PR。

## 验收标准
- 至少一条真实的身份 → 普通关 1 → Rest → 普通关 2 → DivineDescent → Ending 主流程完成，期间未复制一套 PK、终局倾向或奖励事实。
- 未击破、真正击破、重开及重复输入不错误登记奖励、倾向、收藏、关卡或终局快照。
- 缺正式结局图、判词、教名、败者卡、第二关配表不阻塞 TEST_ONLY 的程序逻辑验收；所有临时内容明确可识别、可替换，不污染正式 `.tres`。
- 提供真实 Godot 4.7.2 运行证据和对应日志；正式美术/平衡/Android 继续明确为待验收。

## 开始条件
**这是一张次日整合卡，不是当前五条 Lane 的追加并行任务。** 只有相关 P0 上游合并后再派给空闲 A，不打断正在执行的 CS-11，也不抢改各 Lane 未提交文件。
