# AU-09 音效与鸣谢实机证据

代码f190271，Godot4.7.2 Steam / Windows D3D12 Forward+ / RTX3050 Laptop。

- banner_demo.ogg：真实Godot SFX总线AudioEffectRecord录制的一次正常完整横幅，约3.82秒；仅从原WAV转为Vorbis以缩小附件，没有拼装声音。原WAV峰值-4.5dBFS；无背景音乐，供用户听重击／尾音节奏。
- tail_fade.png：1280×720，原横幅退场中途，声音增益与标题alpha同步，未改视觉素材；夹具背景为标题菜单，不冒充实际战斗录像。
- music_credits_only.png：实际2371×1334完整片尾，CC0音效段移除后仅显示原音乐署名与曲目链接。真实Viewport，无加工。
- audio_runtime.log：AU07_DONE failures=0 ticks=7；实际原音映射、尾音PCM、暂停／包络／停止、重播／中断与真实击破单次消费通过。
- ending_runtime.log：END02_GUI_DONE failures=0 frames=3961 title_frames=110；音乐来源保留，CC0段不在，完整神谕→后两幕→制作组→鸣谢→标题渐显／解锁链回归通过。

两份GUI日志无ERROR/WARNING；源音／许可见assets/audio/sfx/comic/sources/README.md。听感待用户验收，没有拉取或合并最新main，没有推送或创建PR。
