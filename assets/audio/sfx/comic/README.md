# 剧情漫画音效

- typewriter.wav：历史保留，AU-07后不再用于正式comic_write事件。Cassie-OrbitGames，Typewriter sounds，CC0。原文件 typewriter1.wav，未修改。https://opengameart.org/content/typewriter-sounds
- text_tick.ogg：当前逐字音。Kenney Interface Sounds的click_002.ogg保留清脆起音，150Hz高通、10000Hz低通、-0.5dB，补静音至60ms、末15ms淡出，单声道44100Hz；事件-5dB、音高0.98～1.04，播放器共用80ms节流。替换上一版削高频且事件-20dB的过轻版本。
- break_sweep.ogg：Kenney Interface Sounds的maximize_008.ogg降采样速率后重采样至44100Hz，180Hz高通/6500Hz低通、尾部淡出，约0.30秒。矛盾横幅真实斜切首帧播放一次。
- break_impact.ogg：历史AU-07的Kenney重击混音，AU-09后正式击破事件停用，保留原文件追溯。
- punch_hit.ogg：当前击破成功干声，用户指定Independent.nu的37 hits/punches，第10条hit10.mp3.flac裁切加工，约0.284秒，事件-2dB。
- punch_tail.ogg：同一第10条延展3秒立体声反射尾音，横幅事件-3dB；文字出现时播放，退场按标题实际透明度同帧淡出，完全消失时停止。暂停、重开、中断和复播共用原表现时钟。所选原音、来源、哈希及CC0许可见sources/README.md，构建脚本tools/audio/build_independent_punch.py。
- book_flip.ogg：Kenney，RPG Audio，CC0。原文件 Audio/bookFlip1.ogg，未修改。https://kenney.nl/assets/rpg-audio
- Kenney 原许可见 Kenney-License.txt；CC0 https://creativecommons.org/publicdomain/zero/1.0/

新增三个音效都是现有CC0音源的裁剪、滤波、混音，不是生成模型合成音频，不需要强制署名。未改源素材文件。源码与运行时17表同时更新，避免CSV启动时覆盖Resource。作者许可：https://kenney.nl/assets/interface-sounds ，https://kenney.nl/assets/impact-sounds 。

翻书声在幕切换时播放；打字声随逐字显示播放。正式台词未提供时仅随画面显现短暂播放打字声，不编造文字。
