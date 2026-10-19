# 房间与战后休息音乐
音乐：Pure Soul／煉獄庭園（作曲・編曲：煉獄小僧）。
来源：https://note.com/rengokuteien/n/nb7a4c4460931
作者许可：https://note.com/rengokuteien/n/n0f6dc2ab7bab
用户交付：E:/BGM/Godot背景音乐/休息/Pure_Soul.mp3，原文件不修改；完整转Vorbis quality 5，不变速、不变调，原生OGG循环。
与既有曲目使用同一作者自定义素材许可与游戏/说明署名要求，详见上层README。
事件music_rest_room，音量-12dB、进入0.6秒淡入，首次从2.35秒（约首个音符前50ms）播放，原生循环也从2.35秒起，跳过原曲近2.4秒的空白。OGG本体不改，离开按AudioManager配置淡出。仅首次开播前房间使用，历史圣典/败者卡阅读不重播，暂停续播。

## 战后休息：夢灯 -YumeAkari-
作曲・編曲：煉獄小僧／煉獄庭園。用户本地E:/BGM/Godot背景音乐/结尾/夢灯-YumeAkari-.mp3完整转Vorbis quality5，不变速/变调，不覆盖原文件。来源沿用用户资产表：https://note.com/rengokuteien/n/nf1d13615d3b1 ，作者许可/署名同上。
首次开播前房间保留Pure Soul（-12dB、0.6秒淡入，从2.35秒起播/循环跳过空白）；每场PK后休息改为夢灯 -YumeAkari-（music_rest_after_pk，-12dB、0.6秒淡入、0秒播放/原生循环）。后续开播房间以已提交next_normal_level_order>1选择夢灯并续播；重复结果、历史往返不重播，暂停续播，离开/下场T0淡出。复用RoomMusicPresenter和AudioManager，不改变奖励、关卡流程或结尾天導2.5秒淡入。 原曲开头即有声音，无需跳过空白。
