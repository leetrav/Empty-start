## TEST_ONLY 沙盒仅重定向关卡目录，不复制整套正式场景或新增玩法系统。
extends SceneTree

func _initialize() -> void:
    # 验证继承场景可以加载，并且测试 Catalog 的绑定已经生效。
    var packed: PackedScene = load("res://tests/fixtures/data_export/test_only_sandbox.tscn") as PackedScene
    if packed == null:
        push_error("FAIL test_only_sandbox: scene cannot load")
        quit(1)
        return
    var instance: Control = packed.instantiate() as Control
    if instance == null or instance.level_catalog == null:
        push_error("FAIL test_only_sandbox: catalog injection missing")
        quit(1)
        return
    var cat: LevelCatalog = instance.level_catalog
    if cat.profiles.size() != 2 or cat.profiles[0].level_id != "test_level_01":
        push_error("FAIL test_only_sandbox: wrong catalog")
        quit(1)
        return
    print("PASS TEST_ONLY sandbox inherited scene and exported LevelCatalog injection")
    instance.free()
    quit(0)
