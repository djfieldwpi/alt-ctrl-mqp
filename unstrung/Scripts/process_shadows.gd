extends Node


@onready	 var playerShadows: Array[StaticBody2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Lock Actors"):
		GlobalVariables.is_actors_locked = !GlobalVariables.is_actors_locked
		"""
		if GlobalVariables.is_actors_locked:
			get_tree().root.get_viewport().canvas_cull_mask = (Only desired layers)
			
			Could also include shadow removal:
			for i in range(playerShadows.size() - 1, -1, -1):
				var shadow = playerShadows[i]
				
				if not is_valid_instance(shadow):
					playerShadows.remove_at(i)
					continue
					
				if shadow.get_parent() == self:
					remove_child(shadow)
					
				shadow.queue_free()
				playerShdows.remove_at(i)
			
			Also can save reference frame here after a short delay
			var timer = get_tree().create_timer(0.5)
			await timer.timeout
			get_viewport().get_texture().get_image().save_png("File Path Here")
		else:
			get_tree().root.get_viewport().canvas_cull_mask = -1
		"""
	if Input.is_action_just_pressed("Process Shadows"):
		if GlobalVariables.is_actors_locked:
			# Send signal here
			pass
			
func spawnShadow(vertices: Array[Vector2]):
	# Also able to clear here
	# playerShadows.clear()
	
	# Creates necessary number of convex shape out of vertices
	var parts = Geometry2D.decompose_polygon_in_convex(vertices)
	
	for part in parts:
		var shadow := StaticBody2D.new()
		
		# Collisions
		var collision := CollisionShape2D.new()
		var shape := ConvexPolygonShape2D.new()
		shape.set_points(part)
		collision.shape = shape
		
		# Visuals
		var polygon := Polygon2D.new()
		polygon.polygon = part
		polygon.color = Color.BLACK
		
		# Adds Collision and Visuals to Node
		shadow.add_child(collision)
		shadow.add_child(polygon)
		
		# Position (camera coordinates to global coordinates)
		# shadow.position.x = %Camera2D.position.x - 960 # Half of window width
		
		# Adds shadow part to scene and array
		add_child(shadow)
		playerShadows.append(shadow)
	
	# Unlocks actors and resets culling mask
	GlobalVariables.is_actors_locked = false
	get_tree().root.get_viewport().canvas_cull_mask = -1
