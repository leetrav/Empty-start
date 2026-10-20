extends Node
var menu: Control
var rays: ColorRect
var rid: RID
var results: Array = []
var failures: int = 0
var optimized: Material
var original: ShaderMaterial
var OUT = "D:/src/playtest-20261020/rays"
func _ready() -> void:
	if "--default-renderer" in OS.get_cmdline_user_args():
		OUT += "-default-renderer"
	get_window().title = "God rays performance verification"
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()
# 正式菜单真实绘制，预热后读取GPU计时；帧墙钟单独记录。
func _run() -> void:
	menu = load("res://ui/main_menu/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	rays = menu.get_node("CoverCanvas/Pend00GodRays")
	optimized = rays.material
	original = ShaderMaterial.new()
	original.shader = load("res://tests/performance/god_rays_original.gdshader")
	original.set_shader_parameter("preview_time", 6.0)
	rays.mask_material.set_shader_parameter("preview_time", 6.0)
	menu.set_process(false)
	rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rays.mask_viewport.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for res: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size = res
		for mode: String in ["original", "standard", "low", "off", "original", "standard"]:
			if mode == "original":
				rays.set_quality(0)
				rays.show()
				rays.material = original
			else:
				rays.material = optimized
				rays.set_quality({"standard":2,"low":1,"off":0}[mode])
			await _measure(mode, res)
	FileAccess.open(OUT + "/comparison.json", FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	_compare_images()
	await _settings_smoke()
	print("RAYS_DONE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
func _measure(mode: String, res: Vector2i) -> void:
	for i: int in range(300):
		await RenderingServer.frame_post_draw
	var gpu: Array[float] = []
	var wall: Array[float] = []
	var before := Time.get_ticks_usec()
	for i: int in range(1200):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append(float(now-before)/1000.0)
		before = now
		var cost := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if mode in ["standard", "low"]:
			cost += RenderingServer.viewport_get_measured_render_time_gpu(rays.mask_viewport.get_viewport_rid())
		gpu.append(cost)
	rays.mask_viewport.get_texture().get_image().save_png(OUT+"/mask_"+mode+".png")
	gpu.sort()
	wall.sort()
	var row := {"mode":mode,"resolution":str(res),"gpu_p50_ms":gpu[600],"gpu_p95_ms":gpu[1140],"frame_p50_ms":wall[600],"frame_p95_ms":wall[1140]}
	results.append(row)
	print("RAYS_RESULT ", JSON.stringify(row))
	get_viewport().get_texture().get_image().save_png(OUT+"/"+mode+"_"+str(res.x)+".png")
# 覆盖正式设置面板、保存重载、默认恢复和关闭时停止离屏渲染。
func _settings_smoke() -> void:
	rays.material = optimized
	var panel: SettingsPanel = menu.get_node("%SettingsPanel")
	panel.open()
	var option: OptionButton = panel.get_node("%MenuRaysQuality")
	option.select(0)
	option.item_selected.emit(0)
	_check(not rays.visible and rays.mask_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	_check(SettingsManager.save_settings() == OK)
	SettingsManager.set_menu_rays_quality(2)
	SettingsManager.load_settings()
	SettingsManager.set_menu_rays_quality(SettingsManager.menu_rays_quality)
	_check(SettingsManager.menu_rays_quality == 0 and not rays.visible)
	option.select(1)
	option.item_selected.emit(1)
	_check(rays.visible and rays.mask_viewport.size == Vector2i(480,270))
	SettingsManager.reset_to_defaults()
	_check(SettingsManager.menu_rays_quality == 2 and rays.mask_viewport.size == Vector2i(960,540))
	panel.open()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/settings.png")
	print("RAYS_SETTINGS_PASS")# 相同光效时间和固定标题位置对照，限制平均色差，防止以削弱效果冒充优化。
func _compare_images() -> void:
	var before := Image.load_from_file(OUT+"/original_1920.png").get_data()
	var after := Image.load_from_file(OUT+"/standard_1920.png").get_data()
	var total: float = 0.0
	for index: int in range(before.size()):
		total += absf(float(before[index])-float(after[index]))
	var mean := total / float(before.size())
	print("RAYS_IMAGE_MEAN_BYTE_ERROR ", mean)
	_check(mean < 2.0, "相同构图平均色差过大")
# 失败必须传播到进程退出码，避免协程断言中止后主流程误报通过。
func _check(ok: bool, message: String = "quality settings") -> void:
	if not ok:
		failures += 1
		push_error(message)
