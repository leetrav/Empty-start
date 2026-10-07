---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# Codebase Structure

**Analysis Date:** 2026-10-08

## Directory Layout

```text
Empty-start/
├── addons/godot_mcp/       # Godot MCP editor plugin and runtime probe
├── assets/                 # Audio, character, environment, font, and UI assets
├── build/                  # Build/export output area (currently empty)
├── core/                   # Shared runtime/domain logic, boot, and Autoload services
├── data/                   # Authored Resources and static catalogs/configuration
├── docs/                   # System specifications, originals, and task logs
├── scenes/                 # Game-level scenes; currently sandbox playable scene
├── systems/                # Reusable gameplay components and focused mechanics
├── tests/                  # Unit, system, integration, fixtures, and regression scripts
├── ui/                     # Menus, HUDs, settings, transitions, and shared UI
├── project.godot           # Main scene, Autoload, display/input and plugin config
└── known_traps.md          # Confirmed Godot/state/data regression traps
```

## Directory Purposes

**`core/`:**
- Purpose: Shared domain logic and runtime services.
- Contains: One subdirectory per concept, plus boot and Autoload nodes.
- Key files: `core/boot/boot.gd`, `core/autoload/scene_router.gd`, `core/autoload/save_manager.gd`, `core/save/save_data.gd`, `core/combat/hit_resolution.gd`.

**`systems/`:**
- Purpose: Reusable scene-facing gameplay mechanics and specialized components.
- Contains: `barrage_generation`, `barrage_traits`, `combat_attack`, and `contradiction_break` modules.
- Key files: `systems/barrage_generation/barrage_area.gd`, `systems/combat_attack/attack_charge_input.gd`, `systems/contradiction_break/contradiction_break_system.gd`.

**`data/`:**
- Purpose: Typed Resource schemas and authored content/configuration.
- Contains: Level, identity, combat tier, repeat timing, scripture, sandbox, stage layout, and shared presentation/audio resources.
- Key files: `data/level_configuration/level_catalog.tres`, `data/sandbox/playable_battle_config.tres`, `data/shared/presentation_asset_config.tres`.

**`scenes/`:**
- Purpose: Compose whole gameplay experiences from system nodes and UI.
- Contains: `sandbox/` with the current playable game scene, coordinator, and battle HUD.
- Key files: `scenes/sandbox/sandbox.tscn`, `scenes/sandbox/sandbox.gd`, `scenes/sandbox/sandbox_battle_hud.tscn`.

**`ui/`:**
- Purpose: Present menus, setup, HUD overlays, reusable controls, and theme.
- Contains: `main_menu/`, `identity_setup/`, `pause_menu/`, `settings/`, `live_data/`, `debug/`, `common/`, `transition/`, `theme/`.
- Key files: `ui/main_menu/main_menu.gd`, `ui/identity_setup/identity_setup.gd`, `ui/theme/base_theme.tres`.

**`tests/`:**
- Purpose: Validate domain rules and integrated gameplay boundaries.
- Contains: `unit/`, domain-specific directories, `integration/`, and `fixtures/`.
- Key files: `tests/unit/tendency_state_test.gd`, `tests/combat_attack/test_int01_attack_boundaries.gd`, `tests/barrage_generation/test_capacity_release_resumes_generation.gd`.

**`docs/`:**
- Purpose: Keep current system rules, original source material, and task handoff history.
- Contains: Numbered `docs/<system number. SystemName>/` folders plus `Original/`, `Shared/`, and `Integration/`.
- Key files: `docs/Original/系统案_协作交付版_文本导出.md`, `docs/System_Collaboration.md`, `docs/Shared/README.md`.

**`assets/`:**
- Purpose: Store source/usable presentation assets grouped by type.
- Contains: `audio/`, `characters/`, `environment/`, `fonts/`, and `ui/`.

**`addons/`:**
- Purpose: Third-party/editor tooling integrated into Godot.
- Contains: `godot_mcp/`; plugin is enabled from `project.godot`.

## Key File Locations

**Entry Points:**
- `project.godot`: Main scene, Autoload registration, input and rendering configuration.
- `core/boot/boot.tscn`: Engine startup scene.
- `core/boot/boot.gd`: Defers entry into the main menu.
- `scenes/sandbox/sandbox.tscn`: Current scene loaded by the game route.

**Configuration:**
- `project.godot`: Project-wide configuration and singleton registration.
- `data/**/*.tres`: Authored game parameters and content catalogs.
- `ui/theme/base_theme.tres`: Shared UI theme.

**Core Logic:**
- `core/autoload/`: Cross-scene service APIs.
- `core/<domain>/`: State owners and domain rules.
- `systems/<mechanic>/`: Reusable gameplay nodes and mechanics.
- `scenes/sandbox/sandbox.gd`: Run-level orchestration and composition root.

**Testing:**
- `tests/unit/`: Focused rule tests.
- `tests/<system>/`: Mechanic/system-specific tests.
- `tests/integration/`: Cross-component scenarios.
- `tests/fixtures/`: Shared test assets.

## Naming Conventions

**Files:**
- GDScript and scene/resource files use lowercase `snake_case`, e.g. `hit_resolution.gd`, `sandbox_battle_hud.tscn`.
- Custom resource schemas generally use the domain noun plus `_data`, `_config`, `_catalog`, or `_state`, e.g. `core/live_data/live_session_data.gd`.
- Test files use descriptive snake case and often a `test_` prefix, e.g. `tests/barrage_generation/test_barrage_lifetime_snapshot.gd`.

**Directories:**
- Runtime and mechanic directories use lowercase `snake_case` domain names.
- Documentation system directories use the preserved numbered form `docs/<number>. <SystemName>/`.

**GDScript symbols:**
- Classes use `class_name` with PascalCase; functions and variables use snake_case; constants are uppercase snake case.
- Scene scripts commonly use `%UniqueNodeName` for scene-unique nodes and explicit `bind_*` / `configure_*` methods for injected dependencies.

## Where to Add New Code

**New Feature:**
- Domain rules and owned run state: add a focused module under `core/<domain>/`.
- Reusable gameplay Node/components: add under `systems/<mechanic>/` and compose them in the owning scene.
- Authored parameters/content: define or extend typed schemas and resources under `data/<domain>/`.
- User-facing screen/HUD: place under `ui/<feature>/` or compose within `scenes/<experience>/` when it is specific to one game scene.
- System specification and task records: use the matching numbered `docs/` system directory.

**New Component/Module:**
- Implementation: choose `core/` for domain state/rules, `systems/` for reusable scene mechanics, and `ui/` for presentation.
- Scene assets: colocate `.tscn` and its attached `.gd` script under the owning `ui/` or `scenes/` folder.

**Utilities:**
- Shared domain helpers belong in the relevant `core/<domain>/` module; avoid a generic utility bucket when ownership is domain-specific.
- Shared visual controls belong in `ui/common/`.

## Special Directories

**`.godot/`:**
- Purpose: Godot editor/import/cache state.
- Generated: Yes.
- Committed: No; ignored by Git.

**`build/`:**
- Purpose: Reserved build/export output directory.
- Generated: No current contents detected.
- Committed: Directory exists; no files detected.

**`docs/Original/`:**
- Purpose: Preserved initial system/program/art requirements and task template.
- Generated: No.
- Committed: Yes; treat source materials as immutable historical references.

---

*Structure analysis: 2026-10-08*
