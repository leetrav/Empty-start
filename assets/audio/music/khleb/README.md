# FELT LOVE：游戏采用片段

音乐：FELT LOVE／煉獄庭園（作曲・編曲：煉獄小僧）。
来源：https://note.com/rengokuteien/n/n92c313450308
条款：https://note.com/rengokuteien/n/n0f6dc2ab7bab
用户交付源文件：E:\BGM\Godot背景音乐\列巴\FELT_LOVE.mp3；原MP3未覆盖。作者自定义素材许可（非CC0），允许收费游戏使用，须在游戏与说明署名；不作独立音乐产品分发、不用于AI训练。美哀单曲页此前工具无法加载，来源沿用用户资产表，通用许可已读取。

## 采用切点
| 制作名称 | 原曲秒数 | 时长 |
| --- | --- | --- |
| 00_dialogue_intro | 0.000～14.868 | 14.868秒 |
| 01_low_candidate | 33.331～48.199 | 14.868秒 |
| 02_mid_candidate | 48.199～77.934 | 29.735秒 |
| 03_high_candidate | 181.777～211.513 | 29.735秒 |

原文件统一衰减约-5.817dB，首尾5ms微淡变。列巴使用原曲0秒出场原色版felt_entrance，真实combat_connected气泡首次显示时切同位置felt_intro柔和版，保持进度；两者已烘焙不同音色/音量。

本目录OGG已接入当前旧版Sandbox对应Boss，按真实Tier/阶段驱动；不同旋律使用顺序淡出0.3秒再淡入0.3秒，不依赖整条试听时间轴。17表为资源权威映射，配置在data/audio，导入侧车loop=true。各曲节奏网格是已试听剪辑候选，不能据算法证明乐句和长时间接缝自然；实际游戏听感仍需确认。

制作证据：任务outputs/khleb-felt-love-preview-v2（不作为运行路径）。四关局部运行与资源包验证见AU-03日志；完整PlanB仍待上游正式交付后适配。
