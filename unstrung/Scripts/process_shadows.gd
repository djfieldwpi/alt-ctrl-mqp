extends Node2D


@onready	 var playerShadows: Array[StaticBody2D] = []
# var trigger
var socket: StreamPeerTCP = StreamPeerTCP.new()
var connected: bool = false
var file_path: String = ""

var debug_drawn_vertices: Array[Vector2] = []
var debug_spawn_vertices: Array[Vector2] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.READ_WRITE)
	var error = socket.connect_to_host("127.0.0.1", 65432)
	if error == OK:
		print("Connecting to Python")
	
	if OS.has_feature("editor"):
		file_path = ProjectSettings.globalize_path("res://")
	else:
		file_path = OS.get_executable_path().get_base_dir()
	file_path = file_path.path_join("..").path_join("External Software/Test Images/GodotFrame.png")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	"""var content = trigger.get_as_text()
	content = content.replace("\r", "").split("\n")
	if content[0] == "DONE":
		content.remove_at(0)
		var points: Array[Vector2] = []
		for line in content:
			line = line.strip_edges()
			if line.is_empty():
				continue
			var parts = line.split(" ", false)
			var x := int(parts[0])
			var y := int(parts[1])
			points.append(Vector2(x, y))
		
		spawnShadow(points)
		trigger.close()
		trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.WRITE)"""
	socket.poll()
	var status = socket.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		if socket.get_available_bytes() > 0:
			var data = socket.get_utf8_string(socket.get_available_bytes())
			# print("RAW DATA RECEIVED: ", data)
			var json = JSON.new()
			var error = json.parse(data)
			if error == OK:
				var vertices: Array[Vector2] = []
				var data_array = json.data
				for item in data_array:
					var point = item[0]
					if GlobalVariables.is_camera_follow:
						point[0] += %Camera2D.global_position.x
					vertices.append(Vector2(point[0], point[1]))
				# print(vertices)
				spawnShadow(vertices)
			else:
				print("JSON parse error.")
	
	if Input.is_action_just_pressed("Lock Actors") and not GlobalVariables.is_system_lock:
		GlobalVariables.is_actors_locked = !GlobalVariables.is_actors_locked
		if GlobalVariables.is_actors_locked:
			print("Actors Locked")
			get_tree().root.get_viewport().canvas_cull_mask = 8
			for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 0.2
			# Could also include shadow removal:
			for i in range(playerShadows.size() - 1, -1, -1):
				var shadow: StaticBody2D = playerShadows[i]
				
				if not is_instance_valid(shadow):
					playerShadows.remove_at(i)
					continue
					
				if shadow.get_parent() == self:
					remove_child(shadow)
					
				shadow.queue_free()
				playerShadows.remove_at(i)
			
		# 	Also can save reference frame here after a short delay
			var timer: SceneTreeTimer = get_tree().create_timer(0.5)
			await timer.timeout
			get_viewport().get_texture().get_image().save_png(file_path)
		else:
			print("Actors Unlocked")
			get_tree().root.get_viewport().canvas_cull_mask = -1
			for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 1

	if Input.is_action_just_pressed("Process Shadows"):
		if GlobalVariables.is_actors_locked:
			"""trigger.close()
			trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.WRITE)
			trigger.store_string("GO")
			trigger.close()
			trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.READ_WRITE)
			print(trigger.get_line())"""
			socket.put_data("GET_ARRAY".to_utf8_buffer())
		else:
			print("Actors not locked")
	if Input.is_action_just_pressed("Delete Shadow"):
		for i in range(playerShadows.size() - 1, -1, -1):
				var shadow: StaticBody2D = playerShadows[i]
				
				if not is_instance_valid(shadow):
					playerShadows.remove_at(i)
					continue
					
				if shadow.get_parent() == self:
					remove_child(shadow)
					
				shadow.queue_free()
				playerShadows.remove_at(i)
	
	# Debug Inputs
	if GlobalVariables.debug_drawn_shadows and Input.is_action_just_pressed("Draw Point"):
		if GlobalVariables.is_actors_locked:
			var drawn_point = get_viewport().get_mouse_position()
			var spawn_point = drawn_point + Vector2(%Camera2D.global_position.x, 0)
			if len(debug_drawn_vertices) > 2 and drawn_point.distance_to(debug_drawn_vertices[0]) < 10:
				spawnShadow(debug_spawn_vertices)
				debug_drawn_vertices.clear()
				debug_spawn_vertices.clear()
				queue_redraw()
			else:
				debug_drawn_vertices.append(drawn_point)
				debug_spawn_vertices.append(spawn_point)
				queue_redraw()
		else:
			debug_drawn_vertices.clear()
			debug_spawn_vertices.clear()
			queue_redraw()
			print("Actors not locked")
	if GlobalVariables.debug_checkpoints and Input.is_action_just_pressed("Skip Checkpoints"):
		if Input.is_physical_key_pressed(KEY_0):
			%CharacterBody2D.global_position = %Triggers.checkpoints[0]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_1):
			%CharacterBody2D.global_position = %Triggers.checkpoints[1]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_2):
			%CharacterBody2D.global_position = %Triggers.checkpoints[2]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_3):
			%CharacterBody2D.global_position = %Triggers.checkpoints[3]
			GlobalVariables.is_camera_follow = true

func _draw() -> void:
	if GlobalVariables.is_actors_locked and len(debug_drawn_vertices) > 0:
		var prev_point: Vector2
		for point in debug_drawn_vertices:
			var new_point = Vector2(point.x - 960 + %Camera2D.global_position.x, point.y - 540)
			draw_circle(new_point, 5, Color.GREEN)
			if prev_point:
				draw_line(prev_point, new_point, Color.GREEN, 5)
			prev_point = new_point
		
		
func spawnShadow(vertices: Array[Vector2]):
	# Also able to clear here
	# playerShadows.clear()
	
	# Creates necessary number of convex shape out of vertices
	var parts: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(vertices)
	
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
		shadow.position.x -= 960 # Half of window width
		shadow.position.y -= 540 # Half of window width
		
		# Adds shadow part to scene and array
		add_child(shadow)
		playerShadows.append(shadow)
	
	# Unlocks actors and resets culling mask
	GlobalVariables.is_actors_locked = false
	get_tree().root.get_viewport().canvas_cull_mask = -1
	for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 1
