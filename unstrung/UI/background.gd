extends Control

var panels : Array[Node]
var original = Vector2(-500.0, -230.0)
var shift_control = Vector2(16.0, 9.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panels = get_children()
	print(panels)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_location = get_global_mouse_position()
	var percent_displacement = Vector2((mouse_location.x - 960.0)/960.0, (mouse_location.y - 540.0)/540.0)
	var shift_mouse = shift_control * percent_displacement
	
	for i in range(panels.size()):
		var depth_factor = float(i) / float(panels.size() - 1)
		var panel_shift = shift_mouse * (1.0 - depth_factor)
		panels[panels.size() - 1 - i].position = original + panel_shift
