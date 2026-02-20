extends Node

const CONFIG_PATH = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	config.load(CONFIG_PATH)
	
func set_value(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)
	
func get_value(section: String, key: String, default: Variant) -> Variant:
	return config.get_value(section, key, default)
