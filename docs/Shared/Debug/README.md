# Shared Debug

这里记录仅供开发和验收使用的游戏内调试能力，不占用玩法系统编号。

## DBG-01 游戏内面板

Sandbox 中按 F3 打开或关闭 DEBUG 面板。面板置于普通 HUD 和 PauseMenu 上层，打开时不暂停游戏。

面板设计尺寸为 `900×760`；运行高度限制为逻辑视口高度减 32，内容超过可视高度时在面板内部滚动。调试层为 21，高于 PauseMenu 的 20。

面板状态由场景组合方即时读取 `LevelRunState`、`HitResolution`、`CombatStage`、`AttackChargeInput`、`BarrageArea`、`LiveSessionData` 和 `TendencyState`。UI 不保存第二份可写玩法状态。

调试操作通过拥有者公开方法执行：PK 仍经 HitResolution 的最终 PK 信号联动 Tier/HUD；直播计数写入当前 `LiveSessionData`；倾向只设置本关暂存；弹幕操作复用 BarrageArea 与 RepeatDelayQueue 的现有生成和清理状态。正式玩法不依赖 DEBUG 面板。

独立运行 `ui/debug/debug_panel.tscn` 只用于预览。尚未绑定战斗或快照未就绪时，面板显示中文状态并禁用业务按钮；F3 和关闭入口仍可用。当前 Sandbox 已实例化面板并调用 `bind_sandbox(self)`，无需追加接线。

2026-10-09 在隔离 worktree 使用 Godot 4.7.2、已有 TEST_ONLY 继承 Sandbox 完成 90 项真实状态与输入检查，图形进程退出 0；正式 Sandbox 另做直接启动检查。按钮通过真实 `pressed` 信号验证，实体鼠标逐按钮点击留人工验收。环境存在证书和设置文件权限错误，不能据此宣称无错误，详见当日 DBG-01 日志。
