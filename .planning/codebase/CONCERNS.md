---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# Codebase Concerns

**Analysis Date:** 2026-10-08

## Tech Debt

**Battle orchestration concentration:**
- Issue: `Sandbox` coordinates initialization, retry/rollback, battle phases, rewards, and debug controls in one 420-line scene script; `BarrageArea` combines normal and contradiction generation, capacity, lifetime, retry queues, and cleanup in 407 lines. Cross-system behavior changes therefore require editing high-coupling files.
- Files: `scenes/sandbox/sandbox.gd`, `systems/barrage_generation/barrage_area.gd`
- Impact: State-transition regressions can span attack, barrage, PK, Scripture, and rest behavior; focused unit tests cannot cover every handoff.
- Fix approach: Keep `Sandbox` as the scene coordinator, but move independently testable phase orchestration into owning systems when a concrete change requires it. Preserve explicit state ownership and cleanup rules in `known_traps.md` (KT-03, KT-06–KT-10).

**Save schema has no migration path:**
- Issue: `SaveManager.load_game()` accepts only `SaveData.CURRENT_VERSION` and clears the active data for any other version; `CURRENT_VERSION` is currently `1`.
- Files: `core/autoload/save_manager.gd`, `core/save/save_data.gd`
- Impact: A future saved-field change that increments the version makes older player saves unloadable, with no migration or recovery path.
- Fix approach: Before changing persisted fields, add versioned migration handling and tests for supported prior versions, or explicitly define a reset policy.

## Known Bugs

No additional reproducible runtime bug was established during this static review. The confirmed recurring Godot and lifecycle pitfalls are recorded in `known_traps.md` (KT-01–KT-32), including scene signal wiring, resource typing, input scaling, and Timer period preservation.

## Security Considerations

**Editor MCP capability is enabled in project configuration:**
- Risk: The project enables the `Godot MCP Native` editor plugin and registers `MCPRuntimeProbe` as an Autoload. The plugin can expose editor/scene/script/debug tools when its server is started. Current defaults keep remote access disabled and bind clients to loopback; authentication defaults off, so this remains a development capability that should not be accidentally enabled in a distributed runtime.
- Files: `project.godot`, `addons/godot_mcp/plugin.cfg`, `addons/godot_mcp/mcp_server_native.gd`, `addons/godot_mcp/native_mcp/settings_manager.gd`, `addons/godot_mcp/native_mcp/mcp_http_server.gd`
- Current mitigation: The HTTP transport rejects non-loopback requests when `allow_remote` is false (`addons/godot_mcp/native_mcp/mcp_http_server.gd`); plugin defaults have `auto_start` and `auth_enabled` false (`addons/godot_mcp/mcp_server_native.gd`).
- Recommendations: Keep MCP configuration local to development, review exported project contents, and require explicit auth/remote policy before enabling remote access.

## Performance Bottlenecks

No measured frame-time or memory bottleneck was identified from repository inspection. `BarrageArea` creates and removes individual `BarrageView` nodes and maintains active-instance collections; monitor this path if configured barrage caps or spawn rates increase.

- Files: `systems/barrage_generation/barrage_area.gd`, `systems/barrage_generation/barrage_view.gd`
- Cause: Each generated barrage is an instantiated scene node with per-instance lifetime behavior.
- Improvement path: Profile at the intended maximum active barrage count before considering pooling or batching; no current evidence justifies that complexity.

## Fragile Areas

**Run reset and final-result handoffs:**
- Files: `scenes/sandbox/sandbox.gd`, `core/autoload/save_manager.gd`, `core/final_oracle/final_oracle_confirmation_state.gd`, `core/scripture/scripture_data.gd`, `core/tendencies/tendency_state.gd`
- Why fragile: Retrying must roll back only uncommitted per-attempt state, while confirmed Scripture, hit history, and tendency results survive at the correct boundary. Confirmation signals are also used as commit facts.
- Safe modification: Keep one owner for each mutable fact; preserve the explicit commit/rollback APIs and test both failure/retry and accepted-result branches. Follow `known_traps.md` KT-03, KT-06–KT-10, KT-17, and KT-29.
- Test coverage: Existing unit coverage exercises state systems, but only two scripts under `tests/integration/` exercise Sandbox-level flows.

**Barrage lifecycle and input coordinates:**
- Files: `systems/barrage_generation/barrage_area.gd`, `systems/barrage_generation/barrage_view.gd`, `systems/combat_attack/attack_charge_input.gd`, `systems/combat_attack/aim_reticle.gd`
- Why fragile: Capacity reservations, scene-tree lifecycle, pause-aware timers, and transformed viewport input interact. Known regressions include repeated Timer restarts delaying generation and headless window/viewport scaling moving the reticle (`known_traps.md` KT-02, KT-05, KT-19, KT-30–KT-32).
- Safe modification: Keep capacity changes and cleanup routed through `BarrageArea`; validate coordinates through the viewport transform and test timer remainder with real timers after lifecycle edits.
- Test coverage: There are targeted attack and barrage unit tests; scene-cache and real-window behavior still require runtime checks where the trap records specify them.

## Scaling Limits

**Active barrage scene count:**
- Current capacity: The active limit is configuration-driven through level data and repeat caps, rather than a fixed global budget.
- Limit: No stress-test measurements establish a safe upper bound for simultaneous `BarrageView` nodes.
- Scaling path: Record frame time and node count at the largest planned level configuration; introduce pooling only if profiling shows node churn or draw overhead is material.
- Files: `systems/barrage_generation/barrage_area.gd`, `data/level_configuration/`, `data/repeat/`

## Dependencies at Risk

**Bundled Godot MCP addon:**
- Risk: The project includes an editor integration addon with runtime probe code and an HTTP server. It is development tooling and adds maintenance/update and release-packaging considerations.
- Impact: A plugin/runtime-probe mismatch can affect editor startup or accidentally retain development capabilities in a build.
- Migration plan: Not detected; review whether the addon and its runtime Autoload belong in each release export preset.
- Files: `addons/godot_mcp/`, `project.godot`

## Missing Critical Features

**Player-facing final oracle and ending flow remain incomplete:**
- Problem: `docs/13. FinalOracle/README.md` explicitly says the oracle selection UI and FO-07–FO-12 are pending. The repository has candidate/session logic but no final-oracle UI directory. `docs/20. Ending/README.md` contains the task breakdown, while no `core/ending/` or ending UI implementation is present.
- Blocks: A player cannot complete the documented full run through oracle choice and a composed ending page using the implemented interfaces alone.
- Files: `core/final_oracle/final_oracle_session.gd`, `docs/13. FinalOracle/README.md`, `docs/20. Ending/README.md`

**Identity content remains placeholder data:**
- Problem: Identity resources carry `待配置身份` display names, and the identity README/logs say formal names and icons are outstanding.
- Blocks: Final presentation and identity selection still show temporary content until design assets and copy are supplied.
- Files: `data/identity/identity_orthodox_placeholder.tres`, `data/identity/identity_heretical_placeholder.tres`, `data/identity/identity_absurd_placeholder.tres`, `docs/1. Identify/README.md`

## Test Coverage Gaps

**End-to-end progression and UI acceptance:**
- What's not tested: The automated integration suite has two scripts (`tests/integration/int_01_playable_battle_sandbox_test.gd`, `tests/integration/tt_13_neutral_sandbox_test.gd`); there is no integrated automated coverage for final-oracle UI, rest progression, or ending completion. The system task docs also call for runtime/manual verification of timers, UI, and reward handoffs.
- Files: `tests/integration/`, `docs/13. FinalOracle/README.md`, `docs/20. Ending/README.md`
- Risk: Individually passing state tests do not establish that a complete player run can cross all scene and reward boundaries.
- Priority: High while completing the full-run objective; add a small number of flow-level checks alongside the missing interfaces and retain manual Godot runtime acceptance for presentation.

**Save compatibility:**
- What's not tested: No prior-version save fixture or migration test exists; load behavior is strict equality against version 1.
- Files: `core/autoload/save_manager.gd`, `core/save/save_data.gd`, `tests/`
- Risk: Future schema changes can invalidate existing saves without warning beyond the unsupported-version message.
- Priority: Medium; address with the first persisted schema change.

---

*Concerns audit: 2026-10-08*
