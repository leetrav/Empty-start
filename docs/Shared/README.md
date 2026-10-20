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

### 开场末幕至标题（2026-10-20，AU-06）

comic_player至main_menu采用0.45秒淡出、至少0.25秒全黑、0.60秒淡入；标题离场淡出0.30秒，其他路由保持LOAD-01时长。漫画收尾和标题离场的旧音乐先随黑幕淡出，之后再暂停全树读取/初始化新页面；否则音乐Tween会随树暂停而无法实际淡出。输入仍从请求接受开始拦截。

## 全页面Esc暂停（2026-10-20，PAUSE-01）

SceneRouter初始启动及每次scene_changed后统一检查当前页面的PauseMenu。Sandbox、房间已有实例继续复用；标题、漫画、身份设置和结局等遗漏页自动补同一现有场景，默认隐藏“重新开始当前关”。每个页面只保留一套，不增加第二种暂停UI，也不替代战斗现有重开/攻击取消回调。

Esc使用Input Map的pause Action。首次按下暂停并打开继续/设置/返回面板；再次按下恢复。暂停内设置打开时，Esc先关闭设置，仍保持暂停。全屏时也能经此入口关闭设置里的全屏选项。转场中忽略pause，避免误解除加载层的树暂停。

暂停/恢复统一通知AudioManager；独立ComicPlayer额外调用set_playback_paused冻结分镜Timer、文字和Tween，Esc不再直接退出漫画。暂停返回菜单先完整恢复并发出paused_changed(false)，避免音乐暂停标志留到新页面。

### 标题光效设置（PA-25）
SettingsManager.menu_rays_quality为0关闭、1低、2标准（默认），set_menu_rays_quality限制范围并发出menu_rays_quality_changed；SettingsPanel即时生效，返回保存display/menu_rays_quality，旧配置缺失或非法值回退标准。load_settings读取，apply_settings统一通知；reset_to_defaults恢复标准。关闭同时停止标题离屏光效绘制，仅影响标题画面。性能依据见PresentationAssets/表现资产_PA-25_2026-10-20_log.md。

### END-01 终局动画路由
SceneRouter.goto_ending(session,play_epilogue=false)默认保持直接显示已有结局结果；正式Sandbox传true，保存同一EndingSession后进入ComicPlayer内部epilogue目的，仅播P5/P6。finish_ending_epilogue只交付已保存快照到EndingPage，不重新计算结算。goto_saved_ending保持直接成果/鸣谢入口；后半回看kind=ending与首次观看记录语义保持。神谕7秒与鸣谢署名详见20.Ending/END-01日志。

### PK-01 PK单位与终点（2026-10-20）
PlanBBattleHost.get_pk/pk_changed固定0～100百分点，get_pk_fraction固定0～1；PlanBBattleUI的Host读取按百分点解释，HUD.refresh_pk仍接受旧归一化调用。权威PK更新保留所有真实小增量，满值1/零值0分别触发原矛盾与失败入口；未满不能显示100%，正数不足1%显示<1%。见Integration/PK终点_PK-01日志及正式四Boss回归。
