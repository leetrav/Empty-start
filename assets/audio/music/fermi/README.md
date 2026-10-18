# 费米 BGM：Teek Teek Teek

曲名：Teek Teek Teek；作曲/编曲：煉獄小僧；来源：煉獄庭園（Mana发布）。
原曲：https://note.com/rengokuteien/n/n9de199487005
素材条款：https://note.com/rengokuteien/n/n0f6dc2ab7bab
核对日期：2026-10-18。采用作者自定义素材许可，不是CC0或CC BY。

游戏内及游戏说明须标明煉獄庭園；条款允许游戏（包括付费游戏）使用、格式转换。此处只做游戏配乐段落截取、循环与微淡变，保留原曲署名；不将片段作为独立音乐产品发行，不进行AI训练。

建议署名：音乐《Teek Teek Teek》／煉獄庭園（作曲・編曲：煉獄小僧）。游戏结尾页和试听页已有对应文字。

## 游戏内资源
| 文件 | 原曲位置 | 长度 | Tier |
| --- | --- | --- | --- |
| teek_intro.ogg | 0～19.2秒，3500Hz低通、总衰减约10.1dB | 19.2秒 | T0黑屏铺垫 |
| teek_low.ogg | 28.8～38.4秒重复两遍 | 19.2秒 | T1 |
| teek_mid.ogg | 48.0～67.2秒 | 19.2秒 | T2/T3 |
| teek_high.ogg | 76.8～96.0秒 | 19.2秒 | T4/T5 |

沿用用户接受的预览编码：44.1kHz立体声Vorbis，约5ms首尾微淡变，三段统一衰减约4.1dB。四个19.2秒循环为暂按100BPM四拍估计的8小节；真实乐句/接缝仍需人工连续试听确认。

事件ID为music_alien_intro/low/mid/high，由17音频表提供权威映射，audio_event_config.tres为同ID兼容引用；OGG导入侧车随Git保存loop=true。旧music_battle_t0～t5未绑定费米素材，防止其他Boss误播。
原始MP3继续由用户保管，仓库仅收游戏实际使用的三个加工片段。

最新开局：T0铺垫相对战斗基准再轻约6dB，AudioManager首播淡入2.4秒；不会每次循环都做2.4秒淡入。T1连线后切入原低段。原低/中/高三个音频未改变；intro采用原曲开头19.2秒，而非从高段直接截入。
