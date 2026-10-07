---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# Technology Stack

**Analysis Date:** 2026-10-08

## Languages

**Primary:**
- GDScript (Godot 4.x) - Runtime, editor integration, application logic, and the native Godot MCP plugin; project scripts are primarily under `core/`, `systems/`, and `ui/`.

**Secondary:**
- Godot text resource formats (`.tscn`, `.tres`, `.godot`) - Scenes, data resources, and project configuration, including `project.godot` and `data/`.
- JSON - Structured configuration and MCP protocol payloads; MCP transport and CLI handler code lives under `addons/godot_mcp/native_mcp/`.
- C# - Not detected in game code or project support files.

## Runtime

**Environment:**
- Godot Engine 4.7, declared by `config/features` in `project.godot`.
- Godot's built-in GDScript runtime; project scripts use typed GDScript and native engine APIs.

**Package Manager:**
- None for the game project; no root `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, or `pyproject.toml` was detected.
- Lockfile: Not applicable. The project uses Godot's resource/import system rather than a language package manager.

## Frameworks

**Core:**
- Godot Engine 4.7 - Game runtime, scene tree, UI, resources, audio, physics, and editor.
- Jolt Physics - Godot project 3D physics engine configured in `project.godot`; use of 3D game code was not detected in the scanned core gameplay paths.

**Testing:**
- Godot `SceneTree` scripts - Standalone test scripts under `tests/` use the engine runtime directly; no third-party test runner dependency was detected.

**Build/Dev:**
- Godot Editor and command-line runtime - Project import, script checks, test execution, and export are provided by the engine; no separate build tool configuration was detected.
- Godot MCP Native 1.0.8 - Optional editor and runtime automation plugin installed in `addons/godot_mcp/` and enabled in `project.godot`.

## Key Dependencies

**Critical:**
- Godot Engine 4.7 - Required to open, import, run, test, and export the project; version feature is declared in `project.godot`.

**Infrastructure:**
- Godot built-in `Resource`, `ResourceLoader`, and `ResourceSaver` - Typed game data and persistence, including `core/save/save_data.gd` and `core/autoload/save_manager.gd`.
- Godot built-in audio and input systems - Audio buses are defined in `default_bus_layout.tres`; input actions are configured in `project.godot`.
- Godot MCP Native plugin - Its source and editor integration are contained under `addons/godot_mcp/`; no external runtime SDK dependency is declared.

## Configuration

**Environment:**
- Main project settings, startup scene, autoloads, feature version, input actions, display, physics, rendering, and plugin enablement are in `project.godot`.
- Persistent player settings are stored at `user://settings.cfg` by `core/autoload/settings_manager.gd`.
- Player save data is stored at `user://savegame.res` by `core/autoload/save_manager.gd`.
- No `.env`-based game configuration was detected; `.gitignore` excludes `.env` files and generated `.godot/` data.

**Build:**
- Godot project metadata: `project.godot`.
- Audio bus layout: `default_bus_layout.tres`.
- Editor plugin metadata: `addons/godot_mcp/plugin.cfg`.
- Export preset configuration: Not detected (`export_presets.cfg` absent).

## Platform Requirements

**Development:**
- Godot Engine 4.7-compatible editor/runtime; `.godot/` import and editor cache is generated locally and ignored by `.gitignore`.
- A separate Node.js installation is not required by the installed native MCP plugin, per `addons/godot_mcp/plugin.cfg` and `addons/godot_mcp/README.md`.

**Production:**
- Deployment target and export platforms: Not detected; no export presets or CI/deployment configuration are present in the repository root.

---

*Stack analysis: 2026-10-08*
