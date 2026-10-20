# END-02 实际运行证据

代码133850e，Godot4.7.2 Steam / Windows D3D12 Forward+ / RTX3050 Laptop。真实运行截图，非设计图或截图动画；窗口被调整为2371×1334，逻辑画布1920×1080。原始尺寸保存，未替代运行时UI。

- oracle_exit_black.png：文字退场仍为黑底，无PK露出。
- production_title_only.png / roster_mid_fade.png / production_hold.png：标题独立、名单同步渐显、删除连写人名后的最终分工。
- special_hold.png：纯黑底、完整音频作者/出处，实际停留12秒。
- title_mid_fade.png：原界面整体渐显中，尚未允许交互或提交解锁。
- end02-black-gui.log：最终片尾GUI及Music总线采样通过；没有Thank you阶段。
- end02-restart.log：独立进程读取完成解锁通过。
- end02-pending-final.log：中断档恢复进入结尾、未提前解锁通过。
- end02-zero-collections.log：零收藏单测通过。

重启与中断日志来自同轮各独立进程，最后纯黑/音乐改动的主链由black-gui日志验证。验证限制见同级END-02完成日志。后续剧情回放子菜单验收另留证据。
