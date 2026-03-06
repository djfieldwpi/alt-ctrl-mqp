extends Node2D

# Stores the parts of the currently spawned shadow for easy access and deletion
@onready	 var playerShadows: Array[StaticBody2D] = []

# Setup for locally hosted data transfer
var socket: StreamPeerTCP = StreamPeerTCP.new()
var connected: bool = false

# Stores absolute path of reference image after its found
var file_path: String = ""

# Storage for vertices drawn with debig mode
var debug_drawn_vertices: Array[Vector2] = []
var debug_spawn_vertices: Array[Vector2] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_viewport().size = Vector2i(1920, 1080)
	# Load and play music
	# GlobalAudio.play_music("res://Audio/Music/BG_Music.mp3")
	
	# Opens connects server over local port for vertices collection from external python script
	var error = socket.connect_to_host("127.0.0.1", 65432)
	if error == OK:
		print("Connecting to Python")
	
	# Finds the absolute path for the operating system for the reference image, used for comparison during shadow detection
	if OS.has_feature("editor"):
		file_path = ProjectSettings.globalize_path("res://")
		file_path = file_path.path_join("..").path_join("External Software/Test Images/GodotFrame.png")
	else:
		file_path = OS.get_executable_path().get_base_dir()
		file_path = file_path.path_join("External Software/Test Images/GodotFrame.png")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Ensures local port connection doesn't drop
	socket.poll()
	
	# Checks connection status
	var status = socket.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		
		# Checks for shadow vertices written to buffer by external python script
		if socket.get_available_bytes() > 0:
			# Converts data to understandable format (json)
			var data = socket.get_utf8_string(socket.get_available_bytes())
			var json = JSON.new()
			
			# Ensures decryption was successful
			var error = json.parse(data)
			if error == OK:
				# Reads vertices from json into Vector2 array
				var vertices: Array[Vector2] = []
				var data_array = json.data
				for item in data_array:
					var point = item[0]
					
					# Adds proper x offset depending on camera state and location
					if GlobalVariables.is_camera_follow:
						point[0] += %Camera2D.global_position.x
					if GlobalVariables.is_level_two:
						point[1] += 2500
					vertices.append(Vector2(point[0], point[1]))
					
				# Spawns shadow with read vertices
				spawnShadow(vertices)
			else:
				print("JSON parse error.")
	
	###################################
	# Start of input map action logic #
	###################################
	
	# Swaps state to prime for shadow detection
	# 	- Locks all actors, preventing movement
	# 	- Deletes any active shadows
	# 	- Hides certain objects 
	# 	- Lowers the alpha of certain objects so they fall below the shadow threshold
	# 	- Saves the modified viewport to a png for the external python script to use as reference
	# Or
	# 	- Unlocks all actors, continuing prior movement
	# 	- Reverses changes to viewport and visible/semi-visisble objects
	if Input.is_action_just_pressed("Lock Actors") and not GlobalVariables.is_system_lock:
		GlobalVariables.is_actors_locked = !GlobalVariables.is_actors_locked
		if GlobalVariables.is_actors_locked:
			print("Actors Locked")
			get_tree().root.get_viewport().canvas_cull_mask = 8
			for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 0.2
			for node in get_tree().get_nodes_in_group("boulders"):
				node.freeze_body()
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
			for node in get_tree().get_nodes_in_group("boulders"):
				node.unfreeze_body()

	if Input.is_action_just_pressed("Process Shadows"):
		if GlobalVariables.is_actors_locked:
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
			if GlobalVariables.is_level_two:
				drawn_point.y += 2500
				spawn_point.y += 2500
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
		elif Input.is_physical_key_pressed(KEY_1):
			%CharacterBody2D.global_position = %Triggers.checkpoints[1]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_2):
			%CharacterBody2D.global_position = %Triggers.checkpoints[2]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_3):
			%CharacterBody2D.global_position = %Triggers.checkpoints[3]
			GlobalVariables.is_camera_follow = true
		elif Input.is_physical_key_pressed(KEY_4):
			%CharacterBody2D.global_position = %Triggers.checkpoints[4]
			GlobalVariables.is_camera_follow = true
			GlobalVariables.is_chain_breakable = true
		elif Input.is_physical_key_pressed(KEY_5):
			%CharacterBody2D.global_position = %Triggers.check_beach[0]
			GlobalVariables.is_camera_follow = true
			GlobalVariables.is_chain_breakable = true
			GlobalVariables.is_chain_broken = true
			GlobalVariables.is_level_two = true
		elif Input.is_physical_key_pressed(KEY_6):
			%CharacterBody2D.global_position = %Triggers.check_beach[1]
			GlobalVariables.is_camera_follow = true
			GlobalVariables.is_chain_breakable = true
			GlobalVariables.is_chain_broken = true
			GlobalVariables.is_level_two = true
		elif Input.is_physical_key_pressed(KEY_7):
			%CharacterBody2D.global_position = %Triggers.check_beach[2]
			GlobalVariables.is_camera_follow = true
			GlobalVariables.is_chain_breakable = true
			GlobalVariables.is_chain_broken = true
			GlobalVariables.is_level_two = true
		elif Input.is_physical_key_pressed(KEY_8):
			%CharacterBody2D.global_position = %Triggers.check_beach[3]
			GlobalVariables.is_camera_follow = true
			GlobalVariables.is_chain_breakable = true
			GlobalVariables.is_chain_broken = true
			GlobalVariables.is_level_two = true
		if %CharacterBody2D.global_position.y < 1000 and %Camera2D.global_position.y > 1000:
			%Camera2D.global_position.y -= 2500
		elif %CharacterBody2D.global_position.y > 1000 and %Camera2D.global_position.y < 1000:
			%Camera2D.global_position.y += 2500

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			get_tree().change_scene_to_file("res://UI/ui.tscn")

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
		
		var distance = Vector2.ZERO
		for point in part:
			distance += point
		distance = distance / part.size()
		
		for i in range(part.size()):
			part[i] -= distance
		
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
		shadow.add_to_group("shadows")
		shadow.position += distance
		
		# Adds shadow part to scene and array
		add_child(shadow)
		playerShadows.append(shadow)
	
	# Unlocks actors and resets culling mask
	GlobalVariables.is_actors_locked = false
	get_tree().root.get_viewport().canvas_cull_mask = -1
	for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 1
	for node in get_tree().get_nodes_in_group("boulders"):
				node.unfreeze_body()
	if not GlobalVariables.is_chain_broken and GlobalVariables.is_chain_breakable:
		%Chain.monitorable = false
		%Chain.monitorable = true
	%Pipe.monitorable = false
	%Pipe.monitorable = true
		
"""
	Enjoy my cardinal sin, this will remain as tribute to a darker time.
	
	Originally present at the top of _process(delta), this double file access is how I (Dennis)
		sent signals between the external python script and Godot:
	
	var content = trigger.get_as_text()
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
		trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.WRITE)
	
	Orginally present under the Input event "Detect Shadows":
	
	trigger.close()
	trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.WRITE)
	trigger.store_string("GO")
	trigger.close()
	trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.READ_WRITE)
	print(trigger.get_line())
"""
