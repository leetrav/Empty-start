# 剧情漫画音效

- typewriter.wav：历史保留，AU-07后不再用于正式comic_write事件。Cassie-OrbitGames，Typewriter sounds，CC0。原文件 typewriter1.wav，未修改。https://opengameart.org/content/typewriter-sounds
- text_tick.ogg：当前逐字音。Kenney Interface Sounds的click_002.ogg保留清脆起音，150Hz高通、10000Hz低通、-0.5dB，补静音至60ms、末15ms淡出，单声道44100Hz；事件-5dB、音高0.98～1.04，播放器共用80ms节流。替换上一版削高频且事件-20dB的过轻版本。
- break_sweep.ogg：Kenney Interface Sounds的maximize_008.ogg降采样速率后重采样至44100Hz，180Hz高通/6500Hz低通、尾部淡出，约0.30秒。矛盾横幅真实斜切首帧播放一次。
- break_impact.ogg：Kenney Impact Sounds的impactPunch_heavy_003.ogg（0.8倍）叠Interface Sounds的glass_003.ogg（0.18倍，延后25ms），0.89限幅、尾部淡出，0.52秒。文字落定与真正击破成功分别消费独立事件。
- book_flip.ogg：Kenney，RPG Audio，CC0。原文件 Audio/bookFlip1.ogg，未修改。https://kenney.nl/assets/rpg-audio
- Kenney 原许可见 Kenney-License.txt；CC0 https://creativecommons.org/publicdomain/zero/1.0/

新增三个音效都是现有CC0音源的裁剪、滤波、混音，不是生成模型合成音频，不需要强制署名。未改源素材文件。源码与运行时17表同时更新，避免CSV启动时覆盖Resource。作者许可：https://kenney.nl/assets/interface-sounds ，https://kenney.nl/assets/impact-sounds 。

翻书声在幕切换时播放；打字声随逐字显示播放。正式台词未提供时仅随画面显现短暂播放打字声，不编造文字。
