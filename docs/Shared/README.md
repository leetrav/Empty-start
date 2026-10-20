# Shared 共用任务

这里保存多个系统共同使用、又不属于某一个玩法系统的横向任务。

当前分为：

- `PresentationAssets/`：美术与表现资产引用。
- `Audio/`：音乐、音效和 UI 音频接入。
- `Debug/`：开发期间读取真实玩法状态并经系统公开入口执行调试操作。

这些任务不占用 1～20 的玩法系统编号。

执行某个玩法系统任务时，只有在它实际需要对应共用能力时才读取这里的任务结果。

## Sandbox 布局事实

当前Sandbox的共享设计规格保存在`StageLayoutProfile`，实际设计Rect保存在`scenes/sandbox/sandbox.tscn`。基准 `1920×1080` 下，左右为 `448×1080`：信息区 `448×128`、立绘区 `448×432`、直播数据区 `448×520`。中央由顶部状态 `1024×72`、BarrageArea `(448,72,1024,760)` 和底部交互 `1024×248` 接续填满。运行时HUD仅整体缩放；尺寸变更时同步更新资源规格与SceneRect。

比较实际屏幕尺寸时，将 HUD 缩放与 Viewport 最终变换合成；Godot 的逻辑视口尺寸可能与窗口物理像素不同，单看节点 `scale` 无法代表最终屏幕比例。

## 游戏内 Debug 面板

DBG-01 通过 F3 显示共用 DEBUG 面板。面板只读取当前 Sandbox 与系统状态；PK 更新、弹幕生成、直播数据和本场倾向调试都调用各自的正式拥有者入口。面板开启时不暂停游戏，后续共用调试项记录在 `Debug/`。

2026-10-09 补齐独立预览的未绑定提示、业务按钮禁用及视口高度适配；调试层改为 21。当前 Sandbox 接线已存在。真实 TEST_ONLY 场景 90 项检查通过，环境权限错误及人工验收范围见 `Debug/DBG-01_2026-10-09_log.md`。

2026-10-20 DBG-02 恢复正式 Plan B Sandbox 的面板绑定与 Host 所有权调试入口；具体按钮与状态范围见 `Debug/README.md` 及本卡完成日志。

## 全局加载与 SceneRouter（2026-10-20，LOAD-01）

所有顶层 `goto_*()` 与 `reload_current_scene()` 统一走常驻加载层：约 0.20 秒淡出、至少 0.12 秒完整遮罩、目标 ready 后约 0.25 秒淡入。较慢的后台加载显示转动圆点与“正在加载”；场景实例化仍由 Godot 主线程执行，遮罩期间不展示空树。漫画切格、身份设置场景内分页、战斗内阶段演出保持原有职责。

`Error == OK` 表示请求已接受，不表示新页面已可操作。业务逻辑可订阅 `transition_finished(scene_path)`；若仅需读取新节点，可等待 `SceneTree.scene_changed`。加载中再次请求返回 `ERR_BUSY`，无效路径同步返回错误；异步错误发出 `transition_failed(scene_path, error)`，保留原页面与原暂停状态，并提供返回主菜单入口。新场景在淡入结束前暂停，避免对白与自动计时在黑幕下提前消耗。

图形版使用 `ResourceLoader.load_threaded_request/get_status/get`；headless 因本机 dummy renderer 对战斗资源后台读取停在 `IN_PROGRESS`，沿用同步读取。实际视觉验收使用 GUI，不能用 headless 代替。
