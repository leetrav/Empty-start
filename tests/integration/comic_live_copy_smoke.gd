extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var opening: ComicSequence = load("res://data/comics/opening.tres") as ComicSequence
	var ending: ComicSequence = load("res://data/comics/ending.tres") as ComicSequence
	if opening == null or ending == null:
		push_error("COMIC_COPY_SMOKE: sequence load failed")
		quit(1)
		return
	if opening.frames.size() != 13 or ending.frames.size() != 6:
		push_error("COMIC_COPY_SMOKE: unexpected panels %d/%d" % [opening.frames.size(), ending.frames.size()])
		quit(2)
		return
	var label_count := 0
	var rich_count := 0
	for seq: ComicSequence in [opening, ending]:
		for frame: ComicFrame in seq.frames:
			for caption: ComicCaption in frame.captions:
				if caption.kind == "label":
					label_count += 1
				if caption.text.contains("[wave") or caption.text.contains("[shake"):
					rich_count += 1
				var view := ComicCaptionView.new()
				root.add_child(view)
				view.setup(caption)
				await process_frame
				if view.label == null or view.label.get_total_character_count() < 1:
					push_error("COMIC_COPY_SMOKE: RichTextLabel not initialized")
					quit(3)
					return
				view.queue_free()
	if label_count < 5 or rich_count < 2:
		push_error("COMIC_COPY_SMOKE: new label/rich text content missing labels=%d rich=%d" % [label_count,rich_count])
		quit(4)
		return
	var comic_scene: PackedScene = load("res://ui/comic/comic_player.tscn") as PackedScene
	if comic_scene == null:
		push_error("COMIC_COPY_SMOKE: runtime comic player scene missing")
		quit(5)
		return
	print("COMIC_COPY_SMOKE_PASS opening=13 ending=6 labels=%d rich=%d" % [label_count,rich_count])
	quit(0)
