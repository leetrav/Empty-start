# AU-05 · 四Boss出场前Pop Sky

用户2026-10-20确认：在当前工作区加入已选定的Pop Sky原曲01:56之后片段；每位Boss出场前均以1.5秒淡入。

- Owner：当前工作区音频任务；分支fix/preboss-pop-sky-20261020，从5e5ad08承接本地全局加载改动。
- 修改：TierMusicPresenter、17音频事件表、AudioEventConfig、preboss资源与必要说明；保留工作区已有导入及project.godot改动。
- 验收：正式Plan B四Boss均播放正确资源、1.5秒淡入、循环、暂停续播、重复T0不重播、Boss出场接管、离场清理。
- 本次仅本地接入；不改Boss专曲切片、PK规则、资源画面或发布包。
