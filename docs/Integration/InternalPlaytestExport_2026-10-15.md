# 2026-10-15 内部试玩打包

## 目的

面向四人团队和外部小范围内测，直接在 Windows 本机使用 Godot 4.7.2 导出 Windows x64 ZIP 与 Android ARM64 调试 APK；避免依赖当前受限的 GitHub Actions CI。

## 环境

- 工程：本仓库最新已合并 `main`。
- 引擎：Godot 4.7.2 stable，Windows Steam 版 `D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`。
- Steam Godot 为 self-contained 模式，导出模板在 Godot 安装目录 `editor_data/export_templates/4.7.2.stable/`。
- Android：JDK 17 与 Android SDK 已在 Godot 编辑器 Editor Settings 配置，导出为 ARM64 调试签名 APK。正式商店签名需要独立配置。
- Android 启用了 `project.godot` 中的 `rendering/textures/vram_compression/import_etc2_astc=true`。首次启用后应完成纹理重新导入。

## 一键打包

打包前会先运行 `tests/integration/int_15_production_catalog_preflight.gd`，直接加载正式 `LevelCatalog`，核对四关 ID/顺序、每关普通词句与真假矛盾数据。检查失败时停止导出并在 `D:\tmp\INT-15_Preflight_<时间戳>\` 日志中给出缺项；不会生成该次包目录。该检查仅作为内容预检，菜单到生产 Sandbox 的自然 GUI 路径、完整实玩与 Android 真机操作仍须人工验收。

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_internal_playtest.ps1 -Platform Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_internal_playtest.ps1 -Platform Android
# 或一次导出两端
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_internal_playtest.ps1 -Platform Both
```

默认每次生成独立目录 `D:\tmp\GameJam_InternalPlaytest_YYYYMMDD-HHmmss`，不修改 Git 工作区，也不会覆盖上次包。可用 `-DestinationRoot` 指定存放位置；`-GodotEditor` 指定引擎路径。Windows 导出会在隔离的 APPDATA 目录执行一次 EXE headless 启动验收，打包为 `GameJam_InternalPlaytest_win64.zip`；包含 EXE、PCK、试玩说明和版本 SHA256。Android 输出 `GameJam_Playtest_Android_debug.apk`，包含 ARM64 so 并校验 APK 基本结构。

## 内测发布与验收

1. Windows 测试者下载 ZIP、解压所有文件，双击 EXE；PCK 必须保持在 EXE 同目录。建议分辨率 1920×1080、16:9。
2. Android 测试者下载安装 APK（仅限来自开发团队的可信调试包），确认首次启动、横屏、触屏瞄准和操作反馈。导出成功并不能替代真机验收。
3. 验收第一轮：Boot → 开场漫画（首次运行）→ 主菜单 → 身份设置 → Sandbox 普通战斗 → Paradox 漫画与十秒矛盾窗口 → 神谕或 Rest → 下一关；至少验证成功和未击破各一次。
4. 报 bug 请记录包日期、操作路径、实际与预期表现、截图或录屏以及是否复现。开发者从 `build_manifest.json` 核对提交 SHA。
5. 内测包未做公开商店发行验收；正式导出前再核对产品图标、安装包名称、Android SDK、签名、真实设备性能及正式配表。

### 2026-10-15 首份内测实测

> INT-15 复核说明：下方既有 ZIP/APK 来自 `ab3ba169`，当时使用两关示例 Resource；导出和启动记录只证明构建/启动成功，不能作为当前正式内容或生产游玩 PASS。正式包须在 A/B/C 合入后从当时 `main` 重新运行预检并重打包。

- 源代码：`ab3ba169`（PR #228 已合并）。
- Windows x64：Godot 4.7.2 `--export-release` exit 0，导出 EXE 与 PCK；独立 EXE headless 启动 exit 0，D3D12 GUI 启动 exit 0（这两项是启动冒烟，并不替代完整试玩）。
- Windows 分享文件：`D:\tmp\GameJam_InternalPlaytest_20261015_win64.zip`。
- Android ARM64：首次导出缺少 ETC2/ASTC 配置，启用后 `--export-debug` exit 0，Godot 已签名。APK：`D:\tmp\GameJam_InternalPlaytest_20261015\GameJam_Playtest_Android_debug.apk`；尚无连接的 Android 设备可以实机启动。
- Android 导出显示未配置正式项目图标、Target SDK 与本机 build-tools 版本不完全一致的提示。两者须在发布前清理。
