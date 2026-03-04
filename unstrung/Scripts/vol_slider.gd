extends HSlider

@export var bus_name: String

var bus_index: int
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	value_changed.connect(_on_value_changed)
	
	value = db_to_linear(
		AudioServer.get_bus_volume_db(bus_index)
	)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_value_changed(valueA: float) -> void:
	var volume_db = linear_to_db(valueA)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	
	if bus_name == "Master":
		UserSettings.set_value("audio", "master_volume", volume_db)
	elif bus_name == "Music":
		UserSettings.set_value("audio", "music_volume", volume_db)
	elif bus_name == "SFX":
		UserSettings.set_value("audio", "sfx_volume", volume_db)
	elif bus_name == "Ambience":
		UserSettings.set_value("audio", "ambience_volume", volume_db)

	
