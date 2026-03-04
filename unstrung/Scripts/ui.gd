extends Control

@onready var main_menu: VBoxContainer = $MarginContainer/MarginContainerMainMenu/MainMenu
@onready var options: Panel = $MarginContainer/Options
@onready var credits: Panel = $MarginContainer/Credits
@onready var controls: Panel = $MarginContainer/Controls 
@onready var container: MarginContainer = $MarginContainer

func _ready() -> void:
	# Load and play music
	GlobalAudio.play_music("res://Audio/Music/BG_Music.mp3")
	main_menu.visible = true
	options.visible = false
	credits.visible = false
	controls.visible = false
	container.modulate.a = 1.0
	
func _fade_to_screen(target_screen: Control) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	
	# Fade out 
	tween.tween_property(container, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	
	# When fade out finishes swap screens & start fade in
	tween.tween_callback(func():
		main_menu.visible = false
		options.visible = false
		credits.visible = false
		controls.visible = false
		
		target_screen.visible = true
		
		container.modulate.a = 0.0
)

	# Fade back in
	tween.tween_property(container, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	
func _on_settings_button_pressed() -> void:
	_fade_to_screen(options)
	
func _on_credits_button_pressed() -> void:
	_fade_to_screen(credits)
	
func _on_controls_button_pressed() -> void:
	_fade_to_screen(controls)
	
func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_button_pressed() -> void:
	_fade_to_screen(main_menu)
	
func _on_back_button_2_pressed() -> void:
	_fade_to_screen(main_menu)
	
func _on_back_button_3_pressed() -> void:
	_fade_to_screen(main_menu)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_start_button_pressed() -> void:
	GlobalAudio.stop_music()
	get_tree().change_scene_to_file("res://Levels/level_one.tscn")
