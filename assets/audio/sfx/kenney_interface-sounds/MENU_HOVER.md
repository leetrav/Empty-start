# 标题菜单气泡悬停音

- 素材：Kenney Interface Sounds 1.0 / Audio/drop_003.ogg，约0.19秒，原文件未加工。
- 官方来源：https://kenney.nl/assets/interface-sounds
- 许可：CC0；同目录现有License.txt保存完整原始许可。官网明确允许商业项目使用。
- 从仓库已有官方完整ZIP提取这一条，未重复下载整包。
- 事件ui_menu_hover，UI总线，-12dB，pitch 0.96–1.04；CoverMenuButton仅鼠标进入有效可见项时播放一次。
- 同次进入去重，跨按钮70ms限流；禁用项、隐藏项、转场期和暂停状态不播放。不改既有点击音。
