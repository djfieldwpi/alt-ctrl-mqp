extends Node2D

var check = false;

@onready var playerShadow
var trigger

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.READ_WRITE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
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
	if Input.is_action_just_pressed("Detect Shadows"):
		if GlobalVariables.is_actors_locked:
			trigger.close()
			trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.WRITE)
			trigger.store_string("GO")
			trigger.close()
			trigger = FileAccess.open("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/signal.txt", FileAccess.READ_WRITE)
			print(trigger.get_line())
		else:
			print("Actors not locked")
	if Input.is_action_just_pressed("Lock Actors"):
		GlobalVariables.is_actors_locked = !GlobalVariables.is_actors_locked
		if GlobalVariables.is_actors_locked:
			print("Actors locked")
			if playerShadow:
				remove_child(playerShadow)
			get_viewport().get_texture().get_image().save_png("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/External Software/Test Images/GodotFrame.png")
		else:
			print("Actors unlocked")
	# Acts as the pause to change states to detecting shadows, "Detect Shadows" event would request the most recently detected shadow vertex array
	
func spawnShadow(vertices: Array[Vector2]):
	var timer := get_tree().create_timer(0.5)
	await timer.timeout
	
	var shadow := AnimatableBody2D.new()
	
	# Could Change to StaticBody2D.new()
	
	var convexVertices = Geometry2D.convex_hull(vertices)
	
	var collision_shape := CollisionShape2D.new()
	var collision := ConvexPolygonShape2D.new()
	collision.set_points(convexVertices)
	collision_shape.shape = collision
	
	var polygon := Polygon2D.new()
	polygon.polygon = convexVertices
	polygon.color = Color(0, 0, 0, 1) # Green for debugging
	
	shadow.add_child(polygon)
	shadow.add_child(collision_shape)
	
	shadow.position.x = get_node("%Camera2D").position.x - 960
	
	playerShadow = shadow
	add_child(playerShadow)
	GlobalVariables.is_actors_locked = false
	# Delay then unlock actors
	
