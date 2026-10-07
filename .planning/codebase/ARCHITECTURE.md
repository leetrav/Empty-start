---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
<!-- refreshed: 2026-10-08 -->

# Architecture

**Analysis Date:** 2026-10-08

## System Overview

```text
┌────────────────────────────────────────────────────────────────┐
│                         Godot UI / Scenes                       │
│  Boot: `core/boot/boot.tscn`   Main menu: `ui/main_menu/`       │
│  Identity: `ui/identity_setup/`   Playable flow: `scenes/sandbox/`│
└───────────────────────────────┬────────────────────────────────┘
                                │ composes nodes, invokes APIs
                                ▼
┌────────────────────────────────────────────────────────────────┐
│                 Runtime rules and reusable systems               │
│ `core/combat/`, `core/save/`, `core/identity/`,                  │
│ `systems/barrage_generation/`, `systems/combat_attack/`, ...     │
└──────────────────────┬───────────────────────┬─────────────────┘
                       │ reads                  │ persists via
                       ▼                        ▼
┌────────────────────────────┐      ┌─────────────────────────────┐
│ Static config / authored   │      │ Global services (Autoload) │
│ Resources in `data/`       │      │ `core/autoload/`            │
└────────────────────────────┘      └──────────────┬──────────────┘
                                                   │
                                                   ▼
                                      user save `user://savegame.res`
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Boot | Defers initial navigation until Autoloads initialize | `core/boot/boot.gd` |
| SceneRouter | Owns top-level scene loading and switching | `core/autoload/scene_router.gd` |
| Global services | Hold shared settings, audio, and current save state | `core/autoload/settings_manager.gd`, `core/autoload/audio_manager.gd`, `core/autoload/save_manager.gd` |
| Run coordinator | Creates per-attempt systems, wires signals and transitions, refreshes composed scene UI | `scenes/sandbox/sandbox.gd` |
| Runtime rules | Encapsulate combat, identity, repeat, scripture, and run state | `core/` |
| Gameplay components | Reusable input, barrage, and contradiction-break behavior | `systems/` |
| Authored configuration | Static typed Resources for levels, identities, timing, presentation, and catalogs | `data/` |
| UI | Displays state and submits user actions to owning systems | `ui/`, `scenes/sandbox/sandbox_battle_hud.gd` |

## Pattern Overview

**Overall:** Scene-composed, resource-configured Godot game with explicit runtime state owners.

**Key Characteristics:**
- `project.godot` registers `SceneRouter`, `SettingsManager`, `AudioManager`, `SaveManager`, and an editor/runtime probe as Autoloads; do not register another global scene-switch path.
- The scene coordinator creates transient rule objects and connects signals; domain objects own the facts they mutate. For example, `scenes/sandbox/sandbox.gd` composes `HitResolution`, `CombatStage`, and `RepeatDelayQueue` while those classes keep their respective state.
- Typed `.tres` Resources provide authored configuration and catalogs; per-run mutable facts live in `SaveData` and runtime state objects.
- Logic-heavy objects commonly extend `RefCounted` or `Resource`, keeping core calculations testable without a scene tree; node-facing behaviors extend Godot nodes in `systems/`.

## Layers

**Presentation and scene composition:**
- Purpose: Build screens, connect controls to gameplay, and orchestrate the current run.
- Location: `ui/`, `scenes/`, `core/boot/`
- Contains: `.tscn` scenes, attached scripts, HUDs, stage transitions.
- Depends on: Runtime rules, authored data Resources, and global services.
- Used by: Godot main scene and scene instancing.

**Gameplay components:**
- Purpose: Encapsulate input, barrage lifecycle/generation, and contradiction mechanics used by a scene.
- Location: `systems/barrage_generation/`, `systems/barrage_traits/`, `systems/combat_attack/`, `systems/contradiction_break/`
- Contains: Reusable Node components and focused rule/config classes.
- Depends on: Core domain types and configured data.
- Used by: `scenes/sandbox/sandbox.tscn` and its coordinator.

**Core runtime/domain:**
- Purpose: Own gameplay calculations and explicit run state independent of screen layout.
- Location: `core/`
- Contains: Combat resolution, level state, identity rules, save models, session models, tendency and scripture rules.
- Depends on: Godot base types and typed config/data objects; select orchestrators receive services through bind/configure methods.
- Used by: Scene coordinators, components, and UI-facing adapters.

**Authored data:**
- Purpose: Supply static game parameters and content.
- Location: `data/`
- Contains: `.tres` catalogs/configuration and scripts defining custom Resource schemas.
- Depends on: Resource schema scripts.
- Used by: Core runtime and scenes, commonly via `preload()`.

**Global services:**
- Purpose: Keep cross-scene services alive and provide stable top-level APIs.
- Location: `core/autoload/`
- Contains: Scene navigation, settings, audio dispatch, save lifecycle.
- Depends on: SceneTree, Godot storage/audio APIs and domain Resource types.
- Used by: Scenes via registered singleton names in `project.godot`.

## Data Flow

### Startup and playable run

1. `project.godot` launches `core/boot/boot.tscn` and registers Autoload services.
2. `core/boot/boot.gd` defers to `SceneRouter.goto_main_menu()` after tree initialization.
3. `ui/main_menu/main_menu.gd` starts a run through `SaveManager.new_game()` and routes to identity setup.
4. `ui/identity_setup/identity_setup.gd` validates and stores identity in the active `SaveData`, initializes tendency state, persists the Resource, then requests `SceneRouter.goto_game()`.
5. `core/autoload/scene_router.gd` loads the configured scene path and calls `change_scene_to_packed`; the current game path resolves to `scenes/sandbox/sandbox.tscn`.
6. `scenes/sandbox/sandbox.gd` binds HUDs to current save data, constructs per-attempt systems from `data/sandbox/playable_battle_config.tres` and other catalogs, and wires signals between components.
7. Input and generated barrage events flow through `systems/combat_attack/` and `systems/barrage_generation/`; hit resolution updates combat state, which emits changes consumed by stage and HUD logic.

### Stage progression

1. `scenes/sandbox/sandbox.gd` detects a successful contradiction-break outcome and delays transition with a pausable `Timer`.
2. The coordinator emits typed `final_oracle_opened(FinalOracleSession)` or `rest_opened(RestSession)` signals for the corresponding in-scene UI flow.
3. Confirmation callbacks commit session results into the active `SaveData` and its domain Resources; state remains with its owning system.

**State Management:**
- Cross-scene run/save state is the `SaveManager.data` `SaveData` Resource (`core/save/save_data.gd`); `core/autoload/save_manager.gd` owns load/save and replacement.
- Per-attempt combat objects are created/replaced by `scenes/sandbox/sandbox.gd`; durable run facts are written through their owning Resources such as `LiveSessionData`, `ScriptureData`, and `TendencyState`.
- UI reads snapshots or receives explicit binding methods, and user actions call owner APIs. Keep static shared `.tres` content immutable during play.

## Key Abstractions

**Typed configuration Resources:**
- Purpose: Separate designer-authored parameters/content from runtime algorithms.
- Examples: `data/level_configuration/level_catalog.tres`, `data/combat_stage/tier_catalog.tres`, `data/sandbox/playable_battle_config.tres`.
- Pattern: Define schema as `Resource` with exported fields, then author `.tres`; inject or preload into the consumer.

**Runtime state owners:**
- Purpose: Keep mutable facts and state transitions with the system responsible for them.
- Examples: `core/combat/hit_resolution.gd`, `core/tendencies/tendency_state.gd`, `core/scripture/scripture_data.gd`.
- Pattern: Expose focused methods and signals; consumers request changes through methods and observe completed facts through signals.

**Snapshot and session objects:**
- Purpose: Freeze facts at interaction boundaries and pass context across staged flows.
- Examples: `systems/combat_attack/attack_target_snapshot.gd`, `core/final_oracle/final_oracle_session.gd`, `core/rest/rest_session.gd`.
- Pattern: Construct once when the stage opens or a shot is committed, then pass typed objects through APIs/signals.

## Entry Points

**Godot application entry:**
- Location: `project.godot`, `core/boot/boot.tscn`
- Triggers: Project launch.
- Responsibilities: Configure main scene, input/display settings, global Autoload services; Boot forwards navigation to the menu.

**Top-level navigation:**
- Location: `core/autoload/scene_router.gd`
- Triggers: Main menu, identity setup, pause menu, or other top-level flow.
- Responsibilities: Load and switch top-level PackedScenes. Add new top-level destinations here.

**Current gameplay entry:**
- Location: `scenes/sandbox/sandbox.tscn`, `scenes/sandbox/sandbox.gd`
- Triggers: `SceneRouter.goto_game()`.
- Responsibilities: Own the playable run scene and coordinate runtime components.

## Architectural Constraints

- **Threading:** Gameplay runs on Godot's main scene-tree thread; no worker-thread subsystem was detected.
- **Global state:** Autoload singletons are registered in `project.godot`; `SaveManager.data` is the cross-scene active-run state and audio/settings/router are shared services.
- **Circular imports:** No explicit circular dependency mechanism was observed. GDScript global `class_name` references and PackedScene references form compile-time/resource dependencies.
- **Scene navigation:** Top-level navigation goes through `SceneRouter`; sub-scenes/components are instantiated by their owning scene.
- **State ownership:** Follow the project rules in `known_traps.md`: UI does not write another system's state, static Resources remain authored config, and signals report facts while explicit methods carry commands.
- **Initialization:** A node's `@onready` references require tree entry; setup paths must respect the order in `core/boot/boot.gd` and `scenes/sandbox/sandbox.gd`.

## Anti-Patterns

### UI-owned business state

**What happens:** A Control or HUD directly maintains or changes gameplay facts owned by a runtime system.
**Why it's wrong:** UI and simulation can diverge, and other consumers miss the canonical transition.
**Do this instead:** Bind UI to an owner or pass a request to its public API, as `ui/live_data/live_data_hud.gd` does through `bind_live_session()`.

### Top-level scene changes scattered through screens

**What happens:** A screen loads arbitrary top-level scene paths or calls SceneTree scene-change APIs itself.
**Why it's wrong:** Scene path policy and transition failures become distributed.
**Do this instead:** Add a named route to `core/autoload/scene_router.gd`; leave ordinary child scene instancing to its parent scene.

---

*Architecture analysis: 2026-10-08*
