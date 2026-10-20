# SYNC-02 · 新工作区图标导入阻断修复

**合流规则：以最新 main 上的三张正式石头／剪刀／布 PNG 为权威版本。**

- 原始损坏图仅保留在 `assets/ui/plan_b/battle_type/original_corrupt/`，并由同目录 `.gdignore` 排除导入。
- 整合旧分支时，不得用临时替代图覆盖 main 的 `ui_PK_bu.png`、`ui_PK_jiandao.png`、`ui_PK_shitou.png`。
- 使用 Godot 4.7.2 在最新整合工程完成冷导入和正式 Plan B 场景加载检查；保留隔离 APPDATA，不触及玩家存档。
- 原始损坏图归档只用于追溯，正式运行路径只引用主线正式图标。
