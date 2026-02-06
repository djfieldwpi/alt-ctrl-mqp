extends Control

@onready var main_menu: VBoxContainer = $MarginContainer/MainMenu
@onready var options: Panel = $MarginContainer/Options


func _ready() -> void:
	main_menu.visible = true
	options.visible = false
	
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Levels/level_one.tscn")
	
func _on_settings_button_pressed() -> void:
	main_menu.visible = false
	options.visible = true
	
func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_button_pressed() -> void:
	main_menu.visible = true
	options.visible = false

func _on_quit_button_pressed() -> void:
	get_tree().quit()
