# 37 hits/punches：所选原音

- 作者：Independent.nu；OpenGameArt提交者qubodup。
- 用户指定来源：https://opengameart.org/content/37-hitspunches
- 原包：https://opengameart.org/sites/default/files/independent_nu_ljudbank-hits_and_punches.7z
- 页面2026-10-20标注CC0。许可：https://creativecommons.org/publicdomain/zero/1.0/
- 选择原包hits/hit10.mp3.flac；此目录同名文件未修改。原包共37条，下载包保留D盘测试目录，不将整包放进游戏。
- 原包SHA256：641c65d2e1a00002171c23e2c6fa14e925ae4c12db09d3f79d130a4538916032
- 原音SHA256：1a1f4bec8fed5a1b785b9d43b335fa1cf99efcb85cf37507482f32e75a052265
- 此目录.gdignore排除原始素材导入；派生OGG在上级目录，由正式AudioEvent强引用。

加工：tools/audio/build_independent_punch.py（numpy+FFmpeg），60Hz高通/9kHz低通，按2%峰值定位、保留前2ms，裁去约46.4ms前空白，末尾25ms淡出；干声约0.284秒。确定性衰减反射卷积延展为3秒立体声尾音，未循环拳击起音；Godot使用实际标题透明度控制尾声包络，默认演出在约3.6秒收掉声音。未调用生成式音频模型。CC0不要求强制署名，但本地来源和修改记录保留。
