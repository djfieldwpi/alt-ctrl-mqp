extends Node2D

var reference_client := StreamPeerTCP.new()
var host := "127.0.0.1"
var port := 5000
var connected := false
@onready	 var playerShadows: Array[StaticBody2D] = []

var shape_client := StreamPeerTCP.new()

func _ready() -> void:
	reference_client.connect_to_host(host, port)
	
	var error = shape_client.connect_to_host("127.0.0.1", 65432)
	if error == OK:
		print("Connecting to Python")

func _process(_delta: float) -> void:
	reference_client.poll()
	var status = reference_client.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not connected:
			print("Connected to Python!")
			connected = true
		send_frame()
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		print("Disconnected. Retrying...")
		reference_client.connect_to_host(host, port)
		connected = false
		
	shape_client.poll()
	status = shape_client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		if shape_client.get_available_bytes() > 0:
			for i in range(playerShadows.size() - 1, -1, -1):
				var shadow: StaticBody2D = playerShadows[i]
				
				if not is_instance_valid(shadow):
					playerShadows.remove_at(i)
					continue
					
				if shadow.get_parent() == self:
					remove_child(shadow)
					
				shadow.queue_free()
				playerShadows.remove_at(i)
			var data = shape_client.get_utf8_string(shape_client.get_available_bytes())
			print("RAW DATA RECEIVED: ", data)
			var json = JSON.new()
			var error = json.parse(data)
			if error == OK:
				var vertices: Array[Vector2] = []
				var data_array = json.data
				for item in data_array:
					var point = item[0]
					vertices.append(Vector2(point[0], point[1]))
				print(vertices)
				spawnShadow(vertices)
			else:
				print("JSON parse error.")
				
	shape_client.put_data("GET_ARRAY".to_utf8_buffer())

func send_frame() -> void:
	# 1. Capture Viewport
	var img = $SubViewport.get_texture().get_image()
	
	# 2. Compress to JPG (Faster than PNG for streaming)
	# Quality 0.8 is a good balance
	var buffer = img.save_jpg_to_buffer(0.8) 
	
	# 3. Send Size (Little Endian)
	reference_client.put_32(buffer.size())
	
	# 4. Send Data
	reference_client.put_data(buffer)
	
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
		polygon.color = Color.WHITE
		
		
		# Adds Collision and Visuals to Node
		shadow.add_child(collision)
		shadow.add_child(polygon)
		
		# Position (camera coordinates to global coordinates)
		# shadow.position.x -= 960 # Half of window width
		# shadow.position.y -= 540 # Half of window width
		
		# Adds shadow part to scene and array
		
		shadow.visibility_layer = 2
		add_child(shadow)
		playerShadows.append(shadow)
	
	# Unlocks actors and resets culling mask
	GlobalVariables.is_actors_locked = false
	for node in get_tree().get_nodes_in_group("transparent"):
				node.modulate.a = 1
	
