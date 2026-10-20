# INT-21 · 当前 main 资产映射核验与独立页面补接线

状态：P0，待执行；唯一 Owner：资源接入 Agent（C）。来源：`D:\GameJam\asset-audit-20261020.json`。**从最新 main 建独立 D 盘工作树，PR 目标 main。**

## 开始前先阅读以下文档
- `AGENTS.md`、`known_traps.md`、`project.godot`、`docs/Original/任务卡模板.md`。
- `docs/Shared/PresentationAssets/tasks/PA-21_new-art-assets-import-and-audit.md`、`docs/Shared/PresentationAssets/Art_Intake_Rename_2026-10-20.md`。
- `D:\GameJam\asset-audit-20261020.json` 与本分支 `docs/Integration/资产映射审计复核_2026-10-20.md`。

## 已经实现的功能
- 美术已入库；上一版审计统计 215 个媒体文件，70 个未发现完整的字面引用。但其生成于 01:44，早于 PR #317、#319、#322 等合并，**不是最新 main 的缺失清单**。
- #322 已修主菜单 2 条失效路径；`ui/plan_b/plan_b_streamer_panel.gd` 已经预加载多张粉丝徽章和横牌；`data/shared/formal_sheet_runtime_consumer.gd` 可按主播 ID 动态构造房间背景路径。`data/comics/*.tres`、`data/shared/*.tres` 和音效 CSV 的引用也有效。
- `assets/ui/identity/identity_selection_background.png`、`assets/ui/pause/pause_background.png` 已存在，但在当前已检查的 UI GDScript/TScn 中未找到直接消费；相关现有页面位于 `ui/identity_setup/identity_selection.*`、`ui/pause_menu/pause_menu.*`。

## 本次任务
1. 从**当前最新 main** 复查审计：核验“真实不存在的静态资源路径、可正确按表/Resource/动态路径加载的资源、仍没有运行消费入口的资源”。按关键路径优先级记录到完成 log，明确每个实际缺口对应的运行节点/消费函数，不把 `refs=0` 自动视为 BUG。
2. **独立页面素材接线：** 对身份选择页与暂停页，判断对应 1920×1080 背景能否在不覆盖原有按钮、面板和文本的前提下接入；合理则在页面的**最底层**使用已存在的 `identity_selection_background.png`、`pause_background.png`，保持等比、可见、适配 1280×720。没有对应页面的正式运行入口则记录阻断，不额外造新页面。
3. 检查 `assets/ui/buttons/button_primary.png`、`button_secondary.png` 和其他直接影响该两页的资源是否已有正式消费；只修真实、独立、可证实的漏接，确保鼠标交互与文本层不被贴图遮挡。
4. 输出新的“main 资产接线状态”短表，逐条标出已接线、数据/动态接线、候选未接线、暂时备用与负责人。对用户优先关注的 **8 个 `assets/ui/live/stats/*`** 标记为后续 `INT-22`，不要直接改 `ui/live_data/live_data_hud.gd`。
5. `assets/ui/combat/paradox_bar_background.png` 与 `assets/ui/live/livestream_layout_background.png` 涉及现有 Plan B 战斗 UI 与主播面板，先做路径/视觉层级评估，等 PB-25、PB-20 和 PA-23-FIX 的文件 Owner 释放后再接线。

## 当前禁止争用的文件所有权
- E 正做 PA-22 青蛙分件，`assets/characters/opponents/frog/slices/**` 与 `systems/presentation/opponent_tier_portrait.gd` 交其 Owner。
- D 正做 PB-20 气泡、B 正做 PB-25 教学，A 正做 PB-27 验证；勿抢改各自正在编辑的模拟、`sandbox.gd`、`plan_b_battle_ui.gd`、`plan_b_unit_field.gd`、气泡脚本。
- LD-17-FIX 与 PA-23-FIX 已交其他 Agent/人工验收，不改 `ui/live_data/live_data_hud.gd` 或 fox 房间/立绘锚点；以审计表明确交接。

## 本卡验收标准
- 两个独立页面若存在正式入口，资源显示于 UI 最底层、控件仍能操作，背景不遮挡文字；若没有可安全绑定的布局，记录具体原因而不强行拼贴。
- 新审计区分 **真实缺失、使用中的动态映射、素材待接线、可选/未使用**；留有 PR 文件与对应 Owner。
- 仅做 Godot 4.7.2 场景加载与一组相关关键截图或最短运行检查；不要做复杂全局回归。
- 按可独立子任务 commit，写 `docs/Integration/` 下的 INT-21 完成 log，开 PR 指向最新 main。

## 最小执行流程
1. 用最新 main 建 D 盘独立 worktree；核对文件、导入状态与所需字段。
2. 先接两张页面底图、保持原功能；再更新资产状态清单。
3. 验证场景加载、最简单画面检查；写 log，创建 Draft/正式 PR（无真实画面时 Draft）。

## Godot 环境与交付
Godot 4.7.2、GDScript、PC 1920×1080（兼容 1280×720）、Godot-MCP-Native、godot_mcp。**所有工程、Git 工作树、导入缓存、截图、日志和临时文件只放 D 盘，不向 C 盘写任何项目数据。** 以最短开发周期优先，繁杂测试不做。
