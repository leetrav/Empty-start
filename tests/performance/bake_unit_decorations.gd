extends SceneTree
# 从现有Godot线条绘制离线烘焙，运行时复用图集，避免每帧重建96份弧线几何。
class Painter extends "res://ui/plan_b/plan_b_unit_field.gd":
	func _draw() -> void:
		for index: int in range(10):
			var center := Vector2(float(index % 5)*96.0+48.0,float(index / 5)*96.0+48.0)
			match index:
				0: draw_arc(center,33.25,0.0,TAU,20,Color.WHITE,1.5,true)
				1: draw_arc(center,36.25,0.0,TAU,32,Color.WHITE,2.0,true)
				2: draw_arc(center,39.0,0.0,TAU,32,Color.WHITE,1.6,true)
				3: draw_arc(center,38.0,0.0,TAU,32,Color.WHITE,1.5,true)
				4: draw_arc(center,34.0,0.0,TAU,24,Color.WHITE,1.0,true)
				5:
					draw_arc(center,35.5,-PI*0.8,-PI*0.2,16,Color.WHITE,1.5,true)
					draw_arc(center,35.5,PI*0.2,PI*0.8,16,Color.WHITE,1.5,true)
				6: draw_circle(center,41.0,Color.WHITE)
				7: _draw_battle_type_badge(center,32.0,"type_a")
				8: _draw_battle_type_badge(center,32.0,"type_b")
				9: _draw_battle_type_badge(center,32.0,"type_c")
func _initialize() -> void:
	_bake.call_deferred()
func _bake() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,384)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var painter := Painter.new()
	painter.size = Vector2(480,192)
	painter.scale = Vector2(2,2)
	viewport.add_child(painter)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := ResourceSaver.save(ImageTexture.create_from_image(image),"res://assets/ui/plan_b/units/decoration_atlas.res")
	image.save_png("D:/src/playtest-20261020/decoration_atlas.png")
	print("DECORATION_ATLAS_BAKED ",error)
	quit(error)
