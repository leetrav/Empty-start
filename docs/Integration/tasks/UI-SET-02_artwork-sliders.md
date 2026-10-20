# UI-SET-02 单页美术滑块设置

用户补充：不要再出现旧灰色设置页；按新版底图风格使用现有美术，保留滑块。随后要求删除滑块说明文字，收紧全屏显示与音量区的间距。本卡替代UI-SET-01中加减音量/更多设置二级页面的实现。

在现有main集成工作树独立分支fix/artwork-slider-settings-20261020完成：标题选项与暂停设置直接共用唯一SettingsPanel，美术复用pause_background.png/ZCOOL字体；移除中间AudioPage、更多设置按钮和重复音量代码。保留四条原生HSlider，加入金色轨道与同步百分比；全屏使用原生CheckButton并用开启/关闭文字展示；保留重置/返回/保存、480×270低光效。用户project.godot不纳入提交，用户自行推送和开PR。

验证正式GUI真实拖动四滑块、返回保存、标题BGM连续、Esc分层、全屏退出、重置；回归PK触屏、结算历史与标题音乐。真实截图与日志记录在previews/UI-SET-02。
