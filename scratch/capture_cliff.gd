extends SceneTree

func _init() -> void:
	var world_scene: PackedScene = load("res://scenes/world/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	
	var cam: Camera2D = world.get_node("DebugCamera")
	cam.position = Vector2(1024, 220)
	cam.zoom = Vector2(1.0, 1.0)
	
	await process_frame
	await process_frame
	
	var img = root.get_texture().get_image()
	img.save_png("res://scratch/cliff_preview.png")
	print("Saved cliff preview!")
	quit()
