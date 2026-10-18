# AU-03 费米局部运行验收

使用Godot 4.7.2。先导入工程，OGG导入侧车必须保留loop=true。无Godot MCP时使用CLI；Windows图形exe用Start-Process -Wait -PassThru -WindowStyle Hidden，核对ExitCode、PASS与stderr。验证进程APPDATA设为独立临时目录，避免覆盖玩家存档。

- `au03_runtime_smoke.tscn`：约40秒，真实AudioManager播放器和真实费米主控生命周期，检查同组保持、跨档最新目标、短暂下降取消、暂停恢复、持续下降、失败/离场取消、重开、满PK及击破、玩家Music音量/静音。成功输出AU03_RUNTIME_PASS。
- `au03_loop_smoke.tscn`：最多75秒，同时以极低音量播放四个实际OGG，检查19.2秒长度、循环标记及每份三次真实回绕。成功输出AU03_LOOPS_PASS [3, 3, 3, 3]。这是解码/循环检查，不是人耳接缝验收。
- `au03_pack_check.gd`：Windows Desktop导出PCK后，在工程外用--main-pack <pack.pck> --script <本脚本绝对路径>启动，核对包内四个循环、17表映射和结尾署名。成功输出AU03_PACK_PASS。

独立试听：打开scenes/demos/au03_fermi_music_preview.tscn，F6运行。先逐一播放低/中/高至少三次循环，再手动测试所有Tier变化及暂停/失败/满PK。该场景不会改变游戏PK或原型规则。

完整正式Plan B四关、矛盾击破演出与结局需后续实际联调；未包含在这些局部PASS中。当前F5正式入口仍保留上游原状。

- `au03_first_boss_check.gd`：工程内用--script启动，实例化真实Sandbox，经公开调试PK接口验证当前正式首关的开局/升档/暂停/重开/失败/满值与退出音乐；APPDATA必须隔离。成功输出AU03_FIRST_BOSS_PASS。

最新开局：T0静音；连线/开场对白为music_alien_intro，真实对白完成后T1为low，T2/T3为mid，T4/T5为high。首关脚本通过公开PK接口和突破流程进入真实对白队列，检查对白期间保持引子、实际完成后才切低段（45秒完成等待上限仅用于测试超时，不参与生产切曲）。

引子→低段额外逐帧检查Music总线上有声播放器最多一个，过渡后引子播放器已停止，避免只检查事件ID而漏掉实际叠音。

首关检查分别覆盖正式连线/真实对白队列和F3调PK入口：F3从T0到58%直接低段，再到92%高段；100%矛盾转场实际输出增益压至25%，真实转场结束进入操作窗口后恢复。正常对白路径仍通过公开突破流程放行，不以F3效果替代真实对白验收。
