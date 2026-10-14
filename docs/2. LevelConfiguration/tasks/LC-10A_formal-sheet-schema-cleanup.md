# LC-10A 正式策划表字段精简与拆分06导表兼容

## 开始前先阅读以下文档
- `AGENTS.md`
- `tools/README.md`
- `docs/2. LevelConfiguration/README.md`
- `docs/1. Identify/README.md`
- `tools/export_game_data.py`

## 已经实现的功能
- 身份系统正式使用12张卡，卡片资料由稳定 `identity_id`、显示名称、描述、倾向与可选图标构成。
- Google策划表已将06战斗数值、生命周期、基础参数拆成三张独立工作表。
- 旧导表器仍要求一张06工作表里嵌入三个区块；旧TEST_ONLY夹具采用该格式。

## 本次任务
- 让导表器同时支持当前Google的三张独立06工作表与已有TEST_ONLY单页06夹具。
- 移除过时05.`normal_screen_cap`数值校验；按08表的 `foreground_screen_cap` 配置正式普通前景容量。
- 将仓库01身份CSV同步为六列，保留 `icon_asset_id`、12个身份ID、名称、描述、倾向、备注。
- 保持导出原子性、固定ID校验及既有导表路径。正式全量导入仍在LC-10统一完成。

## 验收条件
- 使用旧TEST_ONLY工作簿导出结果保持相同业务表与资源结构。
- 使用新版独立06工作表时，分别读取06三表并输出相应CSV。
- 06只提供部分拆分工作表时报告数据结构错误；01六列能通过正式身份CSV映射校验。
- 不修改Godot正式运行Resource及现有策划对白。

## Godot开发环境
- Godot 4.7.2 / GDScript；工具脚本Python 3.10+
- PC / Android；项目根目录为仓库根目录

## 执行要求
- 核对main实际文件和旧导表测试，复用既有解析/类型/跨表校验。
- 只处理本任务的表结构兼容，不扩展未完成的新业务导表。
- 用仓库现有TEST_ONLY测试入口和当前Google导出工作簿验收，记录无法执行的项目。
- 完成日志写入 `docs/2. LevelConfiguration/`。
