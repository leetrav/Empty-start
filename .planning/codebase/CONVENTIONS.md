---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# Coding Conventions

**Analysis Date:** 2026-10-08

## Naming Patterns

**Files:**
- Use lowercase `snake_case.gd` and matching resource/scene names, usually named for their class or responsibility; examples include `systems/combat_attack/attack_charge_progress.gd` and `ui/identity_setup/identity_setup.gd`.
- Unit test filenames use `test_<subject>.gd` or a legacy `<subject>_test.gd`; task-specific suites may include a stable ID such as `tests/hit_resolution/test_hr_01_pk_state_and_clamp.gd`.

**Functions:**
- Use `snake_case` for public and private functions. Godot callbacks keep their underscore prefix (`_ready`, `_process`, `_input`); internal helpers commonly use a leading underscore, e.g. `_get_top_tendency_ids()` in `core/tendencies/tendency_state.gd`.
- Name boolean queries with `is_`, `has_`, or `can_`, and state changes with verbs such as `initialize_`, `record_`, `commit_`, and `rollback_`.

**Variables:**
- Use `snake_case`; instance-private fields commonly begin with `_`, such as `_elapsed_seconds` in `systems/combat_attack/attack_charge_progress.gd`.
- Type important values explicitly, especially collections and cross-system state (`Array[String]`, `Dictionary`, concrete domain classes). Keep exported content fields as `@export` properties, as in `core/tendencies/tendency_state.gd`.

**Types:**
- Use `PascalCase` for `class_name` and custom types (`AttackChargeProgress`, `TendencyState`). Enum members and constants are uppercase snake case; local constants vary between uppercase and domain-style names, so follow the closest file.
- Prefer typed domain objects and explicit constructors over loosely typed data. Dictionaries remain appropriate at result/submission boundaries, as in `tests/integration/int_01_playable_battle_sandbox_test.gd`.

## Code Style

**Formatting:**
- Use GDScript indentation with tabs as produced by the project files; separate top-level methods with a blank line.
- No repository-level formatter configuration was detected. Match nearby scripts, including explicit type annotations and multiline formatting for long calls.
- Add concise Chinese comments for changed functions, core logic, key rules, and special cases, per `AGENTS.md`. Comments in `core/tendencies/tendency_state.gd` explain ownership and commit/rollback rules.

**Linting:**
- No GDScript linter or lint configuration was detected.
- Use Godot's `--check-only --script` for parsing modified scripts and inspect runtime output; this is a syntax check, not a full static analysis pass.

## Import Organization

**Order:**
1. `extends` and optional `class_name` declarations.
2. `const` resource/script preloads.
3. Fields and signals.
4. Lifecycle methods, public methods, then private helpers.

This organization appears in `systems/combat_attack/attack_charge_progress.gd` and `tests/unit/combat_attack/test_charge_progress.gd`.

**Path Aliases:**
- No custom script path aliases were detected. Use `res://` paths with `preload()` for stable compile-time dependencies; unit examples include `tests/unit/combat_attack/test_charge_progress.gd` and `tests/unit/loser_card/test_loser_card_data.gd`.
- Global `class_name` types and Autoload singletons are referenced directly in project scripts. Autoload registrations live in `project.godot`.

## Error Handling

**Patterns:**
- Use boolean/nullable return values for expected invalid operations, guard conditions before mutation, and early returns. For example, `TendencyState.record_normal_speech_tendency()` rejects nonpositive deltas and unknown IDs in `core/tendencies/tendency_state.gd`.
- Use Godot diagnostics such as `push_error()` for failed test assertions or unexpected conditions. Keep business state changes behind the owning system's public API, consistent with `known_traps.md` KT-06–KT-10.
- Avoid treating node destruction as the only business cleanup mechanism; use explicit lifecycle methods, per `known_traps.md` KT-03.

## Logging

**Framework:** Godot built-in `print()`, `printerr()`, and `push_error()`.

**Patterns:**
- Runtime scripts do not show a uniform structured logging layer. Tests print a concise success summary and emit failure details; see `tests/unit/combat_attack/test_charge_progress.gd` and `tests/integration/int_01_playable_battle_sandbox_test.gd`.
- Keep routine successful gameplay quiet unless a diagnostic or debug UI explicitly owns the output.

## Comments

**When to Comment:**
- Use Chinese comments for non-obvious rules, ownership boundaries, and special lifecycle/input handling. Existing examples appear before methods in `core/tendencies/tendency_state.gd` and `tests/integration/int_01_playable_battle_sandbox_test.gd`.
- Comments should explain intent or constraints; simple assignments need no narration.

**JSDoc/TSDoc:**
- Not applicable. GDScript uses short `#` comments; no uniform docstring format was detected.

## Function Design

**Size:** Keep pure rules and state transitions cohesive; longer scene-level flows are decomposed into named verification helpers, as in `tests/integration/int_01_playable_battle_sandbox_test.gd`.

**Parameters:** Pass required configuration/state explicitly to small logic objects (e.g. `AttackChargeProgress.new(duration_seconds)`) and prefer typed arguments. Avoid adding a second source of derived state, per `known_traps.md` KT-10.

**Return Values:** Use concrete typed return values (`bool`, `float`, domain types) for reusable logic. Test helpers commonly return bool or record assertions through a shared helper.

## Module Design

**Exports:** Use `class_name` for reusable domain scripts where the codebase needs global type references; use `preload()` for direct script/resource dependencies. Tests often preload implementation scripts so a focused script can exercise them directly.

**Barrel Files:** No barrel-file pattern detected. Keep scripts under the owning `core/`, `systems/`, `data/`, `ui/`, or `scenes/` subtree.

---

*Convention analysis: 2026-10-08*
