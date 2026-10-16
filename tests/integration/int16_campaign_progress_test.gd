extends SceneTree

const CATALOG: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")

func _initialize() -> void:
    var run_data := SaveData.new()
    var run_state := LevelRunState.new(CATALOG)
    assert(run_data.next_normal_level_order == 1)
    assert(not run_state.restore_progress(4, []))
    for completed_order in range(1, 4):
        var current: LevelProfile = run_state.get_current_level_profile()
        assert(current != null and current.level_order == completed_order)
        assert(run_state.complete_level(current.level_id) == LevelRunState.CompletionResult.ADVANCED)
        var pending: LevelProfile = run_state.get_current_level_profile()
        assert(pending != null and pending.level_order == completed_order + 1)
        run_data.next_normal_level_order = pending.level_order
        if not run_data.completed_normal_level_ids.has(current.level_id):
            run_data.completed_normal_level_ids.append(current.level_id)
        # Recreate the scene state after the room transition.
        run_state = LevelRunState.new(CATALOG)
        assert(run_state.restore_progress(run_data.next_normal_level_order, run_data.completed_normal_level_ids))
        assert(run_state.get_current_level_profile().level_order == completed_order + 1)
        assert(run_state.complete_level(current.level_id) == LevelRunState.CompletionResult.ALREADY_COMPLETED)
    var fourth: LevelProfile = run_state.get_current_level_profile()
    assert(fourth != null and fourth.level_order == 4)
    assert(run_state.complete_level(fourth.level_id) == LevelRunState.CompletionResult.ALL_NORMAL_LEVELS_COMPLETED)
    assert(run_state.is_all_normal_levels_completed())
    assert(run_data.completed_normal_level_ids.size() == 3)
    print("INT-16 PASS: broadcasts resume after room at levels 2/3/4, fourth completion triggers finale")
    quit(0)
