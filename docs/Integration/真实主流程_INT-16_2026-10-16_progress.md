# INT-16 真实玩家流程 · 第一批开发记录（2026-10-16）

> 后续接线与实际验证继续记录于 [INT-18A 日志](INT-18A_2026-10-16_log.md)。本文件保留原中断工作事实；本批内容已提交为 `3b50312`。

## 本批已经实现
- 游戏跨场景的关卡进度进入 SaveData：next_normal_level_order、completed_normal_level_ids。新游戏默认第一关，场景重建从存档读取，已完成关卡不能再次以同一会话提交。
- LevelRunState.restore_progress 验证并恢复关卡号和已完成关卡集合。
- Rest 结果确认后：关卡正常推进时，提交进度和 SaveManager.save_game，再经 SceneRouter.goto_opening_room 回到独立房间，不再直接 restart_current_attempt。
- 玩家在房间点击 StartLiveButton 才继续下一关，准备文案显示第几场直播。
- 第四关后保持原有 _enter_divine_descent/Ending 流程，不修改战斗结果结算。

## 已验证
- Godot 4.7.2 worktree editor import 完成；headless 启动 --quit-after 220 退出 0。
- tests/integration/int16_campaign_progress_test.gd 退出 0，打印 INT-16 PASS；反复重新建 LevelRunState 后可继续第二、三、四关，已过关不重复结算，第四关返回全部完成状态。
- git diff --check 退出 0。

## 尚未通过，属于后续出包硬阻断
- 首次观看完整 P1-P6 开场漫画的实际视觉验收（当前 Boot 路由按 SettingsManager 的 opening_comic_seen 条件触发，intro 拼接 OPENING 与 ENDING 两份资源，但这两份文件是 P1-P4/P5-P6 分镜而非可据名称推定的游戏终局）。
- 开场角色命名→身份十二卡→粉丝团→独立房间全过程的真人可视验收。
- 24 表 tutorial_level_001 的瞄准/蓄力/发射三步，还没有运行消费者。
- 四场自然玩家操作直至神降临、结局的真实 E2E；目前只验证了关卡进度逻辑，不能称全流程通过。
- 原27张表的其它缺失业务消费者、仍然不完整的 Fox 背景和音频资源。

## 结论
本批仅修复“Sandbox 结算直接打下一关”及“返回独立房间丢失关卡进度”两个结构性问题。这是首个主循环 PR，不能作为正式可玩版本，也不能合并后宣称完成 INT-16。等待教学、漫画、视觉与整个用户路线的独立验证。
