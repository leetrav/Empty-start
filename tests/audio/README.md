# AU-03 费米局部运行验收

使用Godot 4.7.2。先导入工程，OGG导入侧车必须保留loop=true。无Godot MCP时使用CLI；Windows图形exe用Start-Process -Wait -PassThru -WindowStyle Hidden，核对ExitCode、PASS与stderr。验证进程APPDATA设为独立临时目录，避免覆盖玩家存档。

- `au03_runtime_smoke.tscn`：约30秒，真实AudioManager播放器和真实费米主控生命周期，检查同组保持、跨档最新目标、短暂下降取消、暂停恢复、持续下降、失败/离场取消、重开、满PK及击破、玩家Music音量/静音。成功输出AU03_RUNTIME_PASS。
- `au03_loop_smoke.tscn`：约58秒，同时以极低音量播放三个实际OGG，检查19.2秒长度、循环标记及每份三次真实回绕。成功输出AU03_LOOPS_PASS [3, 3, 3]。这是解码/循环检查，不是人耳接缝验收。
- `au03_pack_check.gd`：Windows Desktop导出PCK后，在工程外用--main-pack <pack.pck> --script <本脚本绝对路径>启动，核对包内三个循环、17表映射和结尾署名。成功输出AU03_PACK_PASS。

独立试听：打开scenes/demos/au03_fermi_music_preview.tscn，F6运行。先逐一播放低/中/高至少三次循环，再手动测试所有Tier变化及暂停/失败/满PK。该场景不会改变游戏PK或原型规则。

完整正式Plan B四关、矛盾击破演出与结局需后续实际联调；未包含在这些局部PASS中。当前F5正式入口仍保留上游原状。

- `au03_first_boss_check.gd`：工程内用--script启动，实例化真实Sandbox，经公开调试PK接口验证当前正式首关的开局/升档/暂停/重开/失败/满值与退出音乐；APPDATA必须隔离。成功输出AU03_FIRST_BOSS_PASS。
