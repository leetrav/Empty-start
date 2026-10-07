---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# Testing Patterns

**Analysis Date:** 2026-10-08

## Test Framework

**Runner:**
- Godot Engine 4.7 project-native GDScript test scripts extending `SceneTree` (unit) or `Node` (integration). No GUT, gdUnit, or third-party test runner configuration was detected.
- Config: project settings and Autoloads in `project.godot`; no dedicated test-runner config file was detected.

**Assertion Library:**
- Godot built-ins (`push_error`, `print`, `is_equal_approx`) plus local assertion helpers. There is no separate assertion library.

**Run Commands:**

```bash
godot --headless --path . --script tests/unit/combat_attack/test_charge_progress.gd # Run one SceneTree unit suite
godot --headless --path . tests/integration/int_01_playable_battle_sandbox_test.tscn # Run one scene-based integration suite
godot --headless --path . --editor --quit # Import and scan project resources/classes
```

No repository-wide test command, watch mode, or coverage command was detected. Integration scenes can also be started with `--path . <scene-path>`; use a matching test script when it is designed to run as a `SceneTree` script.

## Test File Organization

**Location:**
- Tests live under `tests/`, grouped by concern: `tests/unit/`, `tests/integration/`, and system-oriented directories such as `tests/combat_attack/`, `tests/hit_resolution/`, `tests/barrage_generation/`, and `tests/level_configuration/`.
- Reusable deterministic test data lives in `tests/fixtures/`, e.g. `tests/fixtures/combat_attack/ca07_short_attack_timing.tres`.

**Naming:**
- New focused suites should prefer `test_<behavior>.gd`; preserve descriptive subject names and stable task IDs where used. Legacy suites such as `tests/unit/tendency_state_test.gd` remain present.
- Integration scene/script pairs use matching names, e.g. `tests/integration/int_01_playable_battle_sandbox_test.tscn` and `.gd`.

**Structure:**

```
tests/
├── unit/<system-or-feature>/       # focused pure logic and Resource tests
├── integration/                    # real scene and gameplay flow tests
├── <system>/                       # existing system-specific contract suites
└── fixtures/<feature>/             # deterministic Resource fixtures
```

There are 55 GDScript test files across the repository at analysis time; `tests/unit/` is the largest group.

## Test Structure

**Suite Organization:**

```gdscript
extends SceneTree

const SUBJECT = preload("res://path/to/subject.gd")

func _init() -> void:
	if not _test_expected_rule():
		quit(1)
		return
	print("PASS: expected rule")
	quit(0)
```

This pattern appears in `tests/unit/loser_card/test_loser_card_data.gd`; another style accumulates case counts and failures through `_expect()` in `tests/unit/combat_attack/test_charge_progress.gd`.

**Patterns:**
- Each test script owns its execution and exit code; no central discovery/aggregation runner is present.
- Build small domain objects or deterministic fixture resources, then assert externally visible state and results.
- For real node lifecycle and input behavior, mount the actual scene, wait for frames, send Godot input events, and check visible/system outcomes, as in `tests/integration/int_01_playable_battle_sandbox_test.gd`.

## Mocking

**Framework:** No mocking framework detected.

**Patterns:**

```gdscript
const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")

func _test_pk_below_minimum_clamps_to_minimum() -> bool:
	var hit_resolution = HitResolutionScript.new(0.5, 0.0, 1.0)
	return is_equal_approx(hit_resolution.apply_player_pk_delta(-0.75), 0.0)
```

See `tests/hit_resolution/test_hr_01_pk_state_and_clamp.gd`.

**What to Mock:**
- For pure rules, construct the actual Resource/RefCounted subject with explicit inputs; use deterministic temporary content data when practical, as in `tests/unit/loser_card/test_loser_card_data.gd`.

**What NOT to Mock:**
- Tests intended to verify gameplay integration should use the actual scene, Autoload lifecycle, timers, and input path rather than replacing the behavior under test. Avoid assertions against private internals except where no public observable exists; current integration suites sometimes inspect `_pending_items` or private stage state, so this remains a pattern to tighten selectively.

## Fixtures and Factories

**Test Data:**

```gdscript
func _make_catalog():
	var profile = CARD_PROFILE.new()
	profile.streamer_id = &"streamer_a"
	var catalog = CARD_CATALOG.new()
	catalog.profiles.append(profile)
	return catalog
```

See `tests/unit/loser_card/test_loser_card_data.gd`. Resource fixtures are stored beneath `tests/fixtures/` when a reusable serialized configuration is useful.

**Location:**
- Put new fixtures in `tests/fixtures/<feature>/`; keep one-off factories next to the tests that own their meaning.

## Coverage

**Requirements:** No coverage percentage or coverage gate was detected.

**View Coverage:**

```bash

# Not detected: no coverage instrumentation or report command is configured.

```

Coverage is represented by explicit scenario assertions rather than measured line/branch coverage. Test inventory is broad across current systems, though it does not prove every edge case is covered.

## Test Types

**Unit Tests:**
- Exercise small rules, state objects, selectors, config Resources, and transaction behavior with direct preloads. Examples: `tests/unit/combat_attack/test_charge_progress.gd`, `tests/unit/scripture/test_uncommitted_rollback.gd`, and `tests/unit/final_oracle/test_candidate_pool.gd`.

**Integration Tests:**
- Start actual scenes and verify cross-system outcomes, lifecycle, timers, and input. Examples: `tests/integration/int_01_playable_battle_sandbox_test.gd` and `tests/integration/tt_13_neutral_sandbox_test.gd`.
- Related system acceptance scripts also exist outside those two folders, such as `tests/hit_resolution/test_hr_15_win_commit.gd` and `tests/barrage_generation/test_capacity_release_resumes_generation.gd`.

**E2E Tests:**
- No separate browser/UI automation framework detected. `tests/integration/int_01_playable_battle_sandbox_test.gd` is the closest end-to-end coverage, exercising a playable Sandbox flow through attack, result, and restart paths.

## Common Patterns

**Async Testing:**

```gdscript
func _ready() -> void:
	add_child(SANDBOX_SCENE.instantiate())
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_check(condition, "observed scene result")
```

Scene-based test nodes use `await` for frames/timers; see `tests/integration/tt_13_neutral_sandbox_test.gd`. For pause-aware test waits and input coordinate conversion, use the established helpers in `tests/integration/int_01_playable_battle_sandbox_test.gd`.

**Error Testing:**

```gdscript
if not subject.perform_expected_transition():
	push_error("expected transition was rejected")
	return false
```

Failure paths generally report via `push_error()`/`printerr()` and exit nonzero. Each assertion must influence the test result; `known_traps.md` KT-26 records a prior false-positive risk where a script could exit 0 without printing a result.

## Execution Limitations

- Direct `--script` execution does not inject project Autoloads as global identifiers, and unrelated Autoload preloads can fail in that mode. Prefer real-scene startup for Autoload-dependent behavior; see `known_traps.md` KT-25.
- On a fresh worktree, run the project import/editor scan before scene startup so Godot builds `.godot/global_script_class_cache.cfg`; see `known_traps.md` KT-27.
- A headless command's zero exit status alone is insufficient evidence when the harness can fail to execute assertions. Check the explicit pass/result output as well, per `known_traps.md` KT-26.
- Runtime input tests must account for headless window-to-viewport scaling; use the transform conversion pattern in `tests/integration/int_01_playable_battle_sandbox_test.gd` and the known case in `known_traps.md` KT-30.

---

*Testing analysis: 2026-10-08*
