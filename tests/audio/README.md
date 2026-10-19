# AU-03 四Boss局部运行验收

结尾音乐：au03_ending_music_check.gd用隔离APPDATA的--script运行，RAM准备末关进度/真实词库命中历史，公开Rest继续后由实际神降临衰减/锁句/强调完成；验证最终进度满起曲一次、暂停、跨页不重播、保存回看和空历史兜底，成功AU03_ENDING_MUSIC_PASS。不是人工通关/奖励E2E。SceneTree测试避免在解析期用EndingPage类型，改为运行期场景路径检查，避免提前编译Autoload依赖。包检查含Tendoh资源/循环/CSV/说明/署名。

休息音乐：au03_rest_music_check.gd以--script运行并使用隔离APPDATA。覆盖真实开局房间→Sandbox、两类公开结果夹具/重复/历史阅读/暂停、原生循环末尾回绕与旧页不误停新曲、战后回房间同曲续播及暂停中回菜单清理。成功AU03_REST_MUSIC_PASS；不代表真实提交奖励整局E2E。包检查另外验证Pure Soul资源、原生循环、17表、说明与署名。

使用Godot 4.7.2。先导入工程，OGG导入侧车必须保留loop=true。无Godot MCP时使用CLI；Windows图形exe用Start-Process -Wait -PassThru -WindowStyle Hidden，核对ExitCode、PASS与stderr。验证进程APPDATA设为独立临时目录，避免覆盖玩家存档。

- `au03_runtime_smoke.tscn`：约40秒，真实AudioManager播放器和真实费米主控生命周期，检查同组保持、跨档最新目标、短暂下降取消、暂停恢复、持续下降、失败/离场取消、重开、满PK及击破、玩家Music音量/静音。成功输出AU03_RUNTIME_PASS。
- `au03_loop_smoke.tscn`：最多100秒，同时以极低音量播放17份采用OGG（四Boss各四段加列巴原色出场），检查循环标记及每份至少三次真实回绕。成功输出AU03_LOOPS_PASS与17项回绕计数。这是解码/循环检查，不是人耳接缝验收。
- `au03_pack_check.gd`：Windows Desktop导出PCK后，在工程外用--main-pack <pack.pck> --script <本脚本绝对路径>启动，核对包内17份循环、90行17表中的四Boss事件映射、结尾署名和随游戏音乐说明。成功输出AU03_PACK_PASS。

独立试听：打开scenes/demos/au03_boss_music_preview.tscn（兼容原fermi试听入口），F6运行并下拉选Boss；列巴点“开始连线”听原色开头，再点“对白开始”听同位置柔化。先逐一播放低/中/高至少三次循环，再手动测试所有Tier变化及暂停/失败/满PK。该场景不会改变游戏PK或原型规则。

完整正式Plan B四关、矛盾击破演出与结局需后续实际联调；未包含在这些局部PASS中。当前F5正式入口仍保留上游原状。

- `au03_first_boss_check.gd`：工程内用--script启动，实例化真实Sandbox，经公开调试PK接口验证当前正式首关的开局/升档/暂停/重开/失败/满值与退出音乐；APPDATA必须隔离。成功输出AU03_FIRST_BOSS_PASS。

最新开局：T0静音；连线/开场对白为music_alien_intro，真实对白完成后T1为low，T2/T3为mid，T4/T5为high。首关脚本通过公开PK接口和突破流程进入真实对白队列，检查对白期间保持引子、实际完成后才切低段（45秒完成等待上限仅用于测试超时，不参与生产切曲）。

引子→低段额外逐帧检查Music总线上有声播放器最多一个，过渡后引子播放器已停止，避免只检查事件ID而漏掉实际叠音。

首关检查分别覆盖正式连线/真实对白队列和F3调PK入口：F3从T0到58%直接低段，再到92%高段；100%矛盾转场实际输出增益压至25%，真实转场结束进入操作窗口后恢复。正常对白路径仍通过公开突破流程放行，不以F3效果替代真实对白验收。

## 四关场景回归
`au03_four_boss_check.gd`：工程内--script运行。按正式存档结构在隔离APPDATA的RAM数据中准备四关，每关实例化真实Sandbox，通过公开命中到达/结算信号和PK事实完成清场突破动画，再观察真实气泡开始/完成。检查低中高、同组、稳定下降、F3、暂停、重开、失败、击破25%降音/操作窗口恢复、场景释放。成功输出AU03_FOUR_BOSS_PASS。-- --fox-only仅用于定向复现列巴，不等于全四关通过。

测试分别重建各关场景验证退出后下一Boss选择，不代替用户从首关到第四关逐一完成矛盾答案/结算/房间的整局人工验收。程序源与PCK验证不代表完整PlanB交付。临时userdata/日志在任务outputs/au03-validation，不覆盖真实玩家存档。

同一四关检查脚本可用-- --terminal-only运行结果淡出专项，通过公开ContradictionBreakSystem.register_launched_shot/resolve_shot_hit_ids提交真矛盾结果，成功输出AU03_TERMINAL_PASS；不以直接发信号伪造结果。


## 列巴开头只播一次
`au03_khleb_intro_check.gd`用--script运行，约35秒（70秒超时）：真实等待出场回绕一次、对白伴奏回绕两次，确认首次0秒、回绕只到约7.432秒，出场转对白不重播，暂停续播、长等待完成切低、失败和重开清理。成功AU03_KHLEB_INTRO_PASS。复现问题需要超过原14.868秒长度，不能只检查ID或播放前3秒；SceneTree脚本在deferred阶段加载依赖Autoload的Presenter。
包验证新增检查列巴entrance/intro的loop_offset，不把本地导入设置误当导出包已带同一设置。


开场回放集成：au03_opening_check.gd，经--script运行、使用隔离APPDATA，覆盖真实菜单三入口、音乐进度/暂停/退出、Boot首次与已观看行为。成功标记OPENING_STREET_INTEGRATION_PASS。

四Boss第二次箭头统一检查：au03_four_boss_check.gd默认四关均用真实清场/箭头进入T1、T2，逐关记录mid请求与第二次箭头淡出同帧；超时260秒。au03_khleb_intro_check.gd对白完成后预期仍为intro，只有第二次箭头放行才切mid。au03_pack_check.gd另断言四份Profile均开启保持首档。
