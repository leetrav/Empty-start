# INT-16 正式玩家全流程接线

## 开始前先阅读
- AGENTS.md、known_traps.md、project.godot、docs/Original/任务卡模板.md
- docs/2. LevelConfiguration/、docs/Integration/README.md、24 表新手教学设计和CSV
- core/boot/、ui/comic/、ui/main_menu/、ui/identity_setup/、ui/rest/、scenes/sandbox/sandbox.gd、core/save/、data/level_configuration/

## 已实现的功能
Boot 漫画入口、正式身份名字及粉丝团、第一次进入房间、四关 LevelCatalog、Sandbox 战斗、结算、神降临和 Ending 接口存在。旧 Rest 点击继续直接在 Sandbox 重启下一关，不回真实房间；LevelRunState 每次新建从第一关开始；24表教程仅配置ID没有消费系统。

## 本次任务
1. 首次打开实际播开场漫画、进主菜单、主角取名、身份、粉丝团、房间。
2. 玩家第一次主动开播为第一关，教学配置 tutorial_level_001 的 aim/charge/fire 3 步根据真实事件运行。
3. 战斗完成后先结算，然后回独立房间，玩家再次点击开播才进入第二、第三、第四关。
4. SaveData 可靠保存当前下一关序号与过关历史，换场景、重开或加载仍能继续；失败重开不会推进。
5. 第四关结算后进入神降临，完成进入结局。核实六幕开场漫画资产和事件时序，不把 intro 名称混同于游戏结局。
6. 用隔离 user:// 从首次打开一直实测到结局，不使用 Debug 跳关或 TEST_ONLY 替身场景。为所有关卡的房间往返、首次教程、最终阶段提供截图和日志。

## Godot 环境
Godot 4.7.2 GDScript，PC/Android 1920x1080，Godot-MCP-Native、godot_mcp。

## 执行要求
遵循标准14项、一任务卡、子任务分别提交、完成写 docs/Integration/正式玩家流程_INT-16_2026-10-16_log.md，真人视觉验收后 PR。出包门禁必须包含真实路线覆盖。

## 验收标准
自然玩家从第一次启动到最终结局能一次完整走通，每次战斗后真实回房间再开播；24表三步教学出现在首场战斗；不能只以场景加载或静态数据存在宣布联调通过。
